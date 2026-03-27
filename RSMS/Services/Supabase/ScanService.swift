//
//  ScanService.swift
//  RSMS — Hardened v2
//
//  All database operations via Supabase Swift SDK (no Edge Functions).
//
//  Key improvements:
//  - `processScan()`: safe sequential pipeline — lookup → log → mutate.
//    Each step is independently error-handled so no inconsistent state is left.
//  - IN scan behavior: barcode found → set IN_STOCK; not found → throw .barcodeNotFound
//  - Retry logic on status update (up to 2 retries)
//  - `closeStaleSessions()`: calls close_stale_scan_sessions() RPC on app launch
//

import Foundation
import Supabase

// MARK: - Protocol

protocol ScanServiceProtocol: Sendable {
    // Primary — called by RealTimeScanProcessor
    func processScan(barcode: String, sessionId: UUID, type: ScanType) async throws -> ScanResultDTO

    // Session lifecycle
    func createSession(type: ScanType) async throws -> UUID
    func endSession(_ sessionId: UUID) async throws
    func closeStaleSessions() async throws

    // Low-level (kept for future batch processor use)
    func lookupBarcode(_ barcode: String) async throws -> ScanResultDTO
    func updateItemStatus(barcode: String, status: ProductItemStatus) async throws
}

// MARK: - Implementation

final class ScanService: ScanServiceProtocol, @unchecked Sendable {
    static let shared = ScanService()

    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Safe Scan Pipeline

    /// One atomic (in Swift) scan operation:
    ///   1. Lookup barcode + joined product  ← throws barcodeNotFound if missing
    ///   2. Insert scan_log row              ← always attempted if lookup succeeds
    ///   3. Mutate item status               ← retried up to 2×; failure is non-fatal
    ///      (data can be reconciled later; log row is the source of truth)
    ///
    /// - IN  scan: set status = IN_STOCK  (or error if barcode unknown)
    /// - OUT scan: set status = SOLD
    /// - AUDIT:    no status change
    func processScan(barcode: String, sessionId: UUID, type: ScanType) async throws -> ScanResultDTO {
        // Step 1: Pre-fetch for the UI (throws barcodeNotFound if missing)
        let result = try await lookupBarcode(barcode)
        
        // Step 2 removed: the RPC deduces target status based natively on p_scan_type
        
        // Strict Client-Side validation
        switch type {
        case .stockIn:
            if result.itemStatusEnum == .inStock { 
                throw ScanError.stateWarning("Already in stock — no action needed", result) 
            }
        case .stockOut:
            if result.itemStatusEnum == .sold { 
                throw ScanError.stateWarning("Item already sold", result) 
            }
        case .return:
            if result.itemStatusEnum == .returned { 
                throw ScanError.stateWarning("Item already returned", result) 
            }
            if result.itemStatusEnum == .inStock {
                throw ScanError.stateWarning("Item is already in stock — no return needed", result)
            }
            if result.itemStatusEnum == .damaged {
                throw ScanError.operationFailed("Item cannot be returned — marked damaged")
            }
            if result.itemStatusEnum != .sold {
                throw ScanError.operationFailed("Only sold items can be returned")
            }
        case .audit: break
        }
        
        // Step 3: Invoke the transaction-safe backend RPC
        let params: [String: String] = [
            "p_barcode": barcode,
            "p_session_id": sessionId.uuidString,
            "p_scan_type": type.dbValue
        ]
        
        do {
            try await client.rpc("process_scan_event", params: params).execute()
        } catch {
            print("[ScanService] RPC ERROR: \(error)")
            
            // Step 4: Map core Postgres Exceptions to Human UX
            let errorDesc = (error as? PostgrestError)?.message ?? error.localizedDescription
            
            if errorDesc.contains("already sold") {
                throw ScanError.operationFailed("Item already sold")
            } else if errorDesc.contains("not ACTIVE") {
                throw ScanError.operationFailed("Session expired")
            } else if errorDesc.contains("Unauthorized") {
                throw ScanError.operationFailed("Permission denied")
            } else if errorDesc.contains("not found") {
                throw ScanError.operationFailed("Invalid barcode")
            }
            throw ScanError.operationFailed("Scan failed: \(errorDesc)")
        }

        return result
    }

    // MARK: - Barcode Lookup

    func lookupBarcode(_ barcode: String) async throws -> ScanResultDTO {
        struct NotFound: Error {}

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
            // Fallback: Check if the barcode belongs to a legacy product definition with no physical stock
            do {
                struct ProductID: Decodable { let id: UUID }
                let _: ProductID = try await client
                    .from("products")
                    .select("id")
                    .eq("barcode", value: barcode)
                    .single()
                    .execute()
                    .value
                
                // Found in products, but not in product_items
                throw ScanError.operationFailed("No stock available for this product")
            } catch let fallbackError as ScanError {
                throw fallbackError
            } catch {
                // Not found in products either, or network error
                throw ScanError.barcodeNotFound(barcode)
            }
        }
    }

    // MARK: - Scan Log

    private func logScan(barcode: String, sessionId: UUID, type: ScanType) async throws {
        let payload = ScanLogInsertDTO(barcode: barcode, sessionId: sessionId, type: type)
        try await client
            .from("scan_logs")
            .insert(payload)
            .execute()
    }

    // MARK: - Status Update (with retry)

    func updateItemStatus(barcode: String, status: ProductItemStatus) async throws {
        try await client
            .from("product_items")
            .update(["status": status.rawValue])
            .eq("barcode", value: barcode)
            .execute()
    }

    /// Retries `updateItemStatus` up to `retries` times with a 500 ms back-off.
    /// Final failure is printed but NOT thrown — the scan_log is the source of truth
    /// and a reconciliation job can fix stale statuses.
    private func updateItemStatusWithRetry(
        barcode: String,
        status: ProductItemStatus,
        retries: Int
    ) async {
        for attempt in 0...retries {
            do {
                try await updateItemStatus(barcode: barcode, status: status)
                return  // success
            } catch {
                if attempt < retries {
                    // Back-off: 500 ms per attempt
                    try? await Task.sleep(for: .milliseconds(500))
                } else {
                    print("[ScanService] Status update failed after \(retries + 1) attempts for \(barcode): \(error)")
                }
            }
        }
    }

    // MARK: - Session Management

    func createSession(type: ScanType) async throws -> UUID {
        print("SESSION TYPE SENT:", type.dbValue)
        let payload = ScanSessionInsertDTO(type: type.dbValue)

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

    /// Calls the `close_stale_scan_sessions()` PostgreSQL function via RPC.
    /// This marks any ACTIVE sessions older than 24 h as EXPIRED.
    /// Called once on app launch (from ScanManager.cleanUpStaleSessions).
    func closeStaleSessions() async throws {
        try await client
            .rpc("close_stale_scan_sessions")
            .execute()
    }
}
