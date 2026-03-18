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
        // Step 1 — Lookup (throws if barcode not in product_items)
        let result = try await lookupBarcode(barcode)

        // Step 2 — Log the scan event (non-optional; this is the audit trail)
        do {
            try await logScan(barcode: barcode, sessionId: sessionId, type: type)
        } catch {
            // Log failure is critical — surface it so the user knows this scan wasn't recorded
            throw ScanError.operationFailed("Scan could not be recorded: \(error.localizedDescription)")
        }

        // Step 3 — Status mutation (best-effort, retried, non-fatal on final failure)
        let targetStatus: ProductItemStatus?
        switch type {
        case .out:   targetStatus = .sold
        case .in:    targetStatus = .inStock
        case .audit: targetStatus = nil
        }

        if let newStatus = targetStatus {
            await updateItemStatusWithRetry(barcode: barcode, status: newStatus, retries: 2)
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
            // Supabase returns a PostgrestError with code PGRST116 for no rows
            throw ScanError.barcodeNotFound(barcode)
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
        let payload = ScanSessionInsertDTO(type: type.rawValue)

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
