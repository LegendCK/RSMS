//
//  CategoryDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `categories` table exactly.
//  Columns: id, parent_id, name, description, is_active, created_at, updated_at
//

import Foundation

struct CategoryDTO: Codable, Identifiable {
    let id: UUID
    let parentId: UUID?             // Self-referencing FK for nested categories
    let name: String
    let description: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentId   = "parent_id"
        case name
        case description
        case isActive   = "is_active"
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }
}

// MARK: - Insert Payload

struct CategoryInsertDTO: Codable {
    let parentId: UUID?
    let name: String
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case parentId   = "parent_id"
        case name
        case description
        case isActive   = "is_active"
    }
}
