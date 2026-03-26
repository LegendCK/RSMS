//
//  AdminAuditLogDTO.swift
//  RSMS
//
//  Codable DTO matching the Supabase `admin_audit_logs` table.
//

import Foundation

struct AdminAuditLogDTO: Codable, Identifiable {
    let id: UUID
    let adminId: UUID
    let action: String
    let details: [String: String]?
    let ipAddress: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case adminId   = "admin_id"
        case action
        case details
        case ipAddress = "ip_address"
        case createdAt = "created_at"
    }
}

// MARK: - Log Request Payload

struct AdminAuditLogRequest: Encodable, Sendable {
    let p_action: String
    let p_details: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case p_action
        case p_details
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_action, forKey: .p_action)
        try container.encode(p_details, forKey: .p_details)
    }
}
