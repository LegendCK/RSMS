//
//  AdminAuditService.swift
//  RSMS
//
//  Handles reading and writing Corporate Admin audit logs from the database.
//

import Foundation
import Supabase

// MARK: - Payloads

@Observable
@MainActor
final class AdminAuditService {
    static let shared = AdminAuditService()
    
    // Using the authenticated client
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Fetch Logs
    
    /// Fetches the most recent 100 immutable admin audit logs.
    func fetchLogs() async throws -> [AdminAuditLogDTO] {
        return try await client
            .from("admin_audit_logs")
            .select()
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
    }
    
    // MARK: - Log Activity
    
    /// Logs an admin activity via the secure database RPC.
    /// The DB function automatically records the authenticated user's ID.
    func logActivity(action: String, details: [String: String] = [:]) async {
        let payload = AdminAuditLogRequest(p_action: action, p_details: details)
        
        do {
            try await client.rpc("log_admin_activity", params: payload).execute()
        } catch {
            print("[AdminAuditService] Error logging activity '\(action)': \(error)")
        }
    }
}
