//
//  ScanService.swift
//  RSMS — Hardened v3 (Production Audit)
//
//  AUDIT FIXES:
//  1. rpcScanType: was hardcoding 'IN' for RETURN scans — now correctly passes 'RETURN'.
//     The DB RPC process_scan_event() now accepts text params and handles RETURN internally.
//  2. createSession: now accepts storeId + createdBy for audit trail and store filtering.
//  3. ScanSessionInsertDTO uses the expanded DTO with store_id + created_by.
//  4. Error mapping improved: maps 'already sold' and trigger-thrown messages.
//

import Foundation
import Supabase

// MARK: - Session Context

/// Passed to createSession so the session row can record who created it and at which store.
struct ScanSessionContext: Sendable {
    let storeId: UUID?
    let userId: UUID?
}

// MARK: - Protocol

protocol ScanServiceProtocol: Sendable {
    func processScan(barcode: String, sessionId: UUID, type: ScanType) async throws -> ScanResultDTO

    func createSession(type: ScanType, context: ScanSessionContext) async throws -> UUID
    func endSession(_ sessionId: UUID) async throws
    func closeStaleSessions() async throws

    func lookupBarcode(_ barcode: String) async throws -> ScanResultDTO
    func updateItemStatus(barcode: String, status: ProductItemStatus) async throws
}

// MARK: - Implementation

final class ScanService: ScanServiceProtocol, @unchecked Sendable {
    static let shared = ScanService()

    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Safe Scan Pipeline

    func processScan(barcode: String, sessionId: UUID, type: ScanType) async throws -> ScanResultDTO {
        // Step 1: Pre-fetch — throws barcodeNotFound if missing
        let result = try await lookupBarcode(barcode)

        // Step 2: Determine target status
        // AUDIT passes current status as target → the RPC skips the UPDATE for AUDIT scans,
        // making this truly idempotent (no unintended status changes).
        let targetStatus: ProductItemStatus
        switch type {
        case .out:    targetStatus = .sold
        case .in:     targetStatus = .inStock
        case .audit:  targetStatus = result.itemStatusEnum   // no-op: RPC skips UPDATE for AUDIT
        case .return: targetStatus = .returned
        }

        // Step 3: Client-side validation for Returns (fast-fail before network round-trip)
        if type == .return {
            guard result.itemStatusEnum == .sold || result.itemStatusEnum == .damaged else {
                if result.itemStatusEnum == .returned {
                    throw ScanError.operationFailed("Item already returned")
                } else if result.itemStatusEnum == .inStock {
                    throw ScanError.operationFailed("Cannot return item currently in stock")
                } else {
                    throw ScanError.operationFailed("Only sold or damaged items can be returned")
                }
            }
        }

        // AUDIT FIXED: Pass 'RETURN' correctly now — the RPC accepts text params.
        // Previous code was mapping RETURN → 'IN' which was wrong for logging.
        let rpcScanType: String = type.rawValue.uppercased()  // IN | OUT | AUDIT | RETURN

        // Step 4: Invoke the DB RPC (atomic: log + status update in one transaction)
        let params: [String: String] = [
            "p_barcode":        barcode,
            "p_session_id":     sessionId.uuidString,
            "p_target_status":  targetStatus.rawValue,
            "p_scan_type":      rpcScanType
        ]

        do {
            try await client.rpc("process_scan_event", params: params).execute()
        } catch {
            let errorDesc = (error as? PostgrestError)?.message ?? error.localizedDescription
            // Map DB trigger + RPC exceptions to user-friendly messages
            if errorDesc.localizedCaseInsensitiveContains("already sold") {
                throw ScanError.operationFailed("Item is already sold")
            } else if errorDesc.localizedCaseInsensitiveContains("not ACTIVE") || errorDesc.localizedCaseInsensitiveContains("Session is not") {
                throw ScanError.operationFailed("Session expired — please start a new session")
            } else if errorDesc.localizedCaseInsensitiveContains("Unauthorized") {
                throw ScanError.operationFailed("Permission denied — Inventory Controllers only")
            } else if errorDesc.localizedCaseInsensitiveContains("not found") {
                throw ScanError.operationFailed("Invalid barcode — item not in inventory")
            } else if errorDesc.localizedCaseInsensitiveContains("Cannot return") {
                throw ScanError.operationFailed("Cannot return an in-stock item")
            } else if errorDesc.localizedCaseInsensitiveContains("RETURNED state") {
                throw ScanError.operationFailed("Item is RETURNED — stock it IN before selling")
            }
            throw ScanError.operationFailed("Scan failed: \(errorDesc)")
        }

        return result
    }

    // MARK: - Barcode Lookup

    func lookupBarcode(_ barcode: String) async throws -> ScanResultDTO {
        do {
            let item: ProductItemDTO = try await client
                .from("product_items")
                .select("*, products(*)")
                .eq("barcode", value: barcode)
                .single()
                .execute()
                .value

            return ScanResultDTO(from: item)
        } catch {
            // Fallback: check if barcode is a catalog product with no physical stock
            do {
                struct ProductID: Decodable { let id: UUID }
                let _: ProductID = try await client
                    .from("products")
                    .select("id")
                    .eq("barcode", value: barcode)
                    .single()
                    .execute()
                    .value
                throw ScanError.operationFailed("No physical stock registered for this product")
            } catch let fallbackError as ScanError {
                throw fallbackError
            } catch {
                throw ScanError.barcodeNotFound(barcode)
            }
        }
    }

    // MARK: - Status Update (direct, with retry)

    func updateItemStatus(barcode: String, status: ProductItemStatus) async throws {
        try await client
            .from("product_items")
            .update(["status": status.rawValue])
            .eq("barcode", value: barcode)
            .execute()
    }

    // MARK: - Session Management

    /// Creates a scan session and returns its UUID.
    /// - Parameter context: carries storeId and userId for the session audit trail.
    func createSession(type: ScanType, context: ScanSessionContext) async throws -> UUID {
        let payload = ScanSessionInsertDTO(
            type:      type.rawValue,
            storeId:   context.storeId,
            createdBy: context.userId
        )

        struct SessionID: Decodable { let id: UUID }
        let row: SessionID = try await client
            .from("scan_sessions")
            .insert(payload)
            .select("id")
            .single()
            .execute()
            .value

        return row.id
    }

    func endSession(_ sessionId: UUID) async throws {
        let payload = ScanSessionEndDTO(endedAt: Date(), status: "COMPLETED")
        try await client
            .from("scan_sessions")
            .update(payload)
            .eq("id", value: sessionId.uuidString)
            .execute()
    }

    // MARK: - Stale Session Recovery

    func closeStaleSessions() async throws {
        try await client
            .rpc("close_stale_scan_sessions")
            .execute()
    }
}
