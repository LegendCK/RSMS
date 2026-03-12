//
//  UserDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `users` table exactly.
//  Column names: id, role, store_id, first_name, last_name,
//                email, phone, avatar_url, is_active, created_at, updated_at
//

import Foundation

struct UserDTO: Codable, Identifiable {
    let id: UUID
    let role: String                // "corporate_admin" | "boutique_manager" | "sales_associate" | "inventory_controller" | "service_technician" | "client"
    let storeId: UUID?
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let avatarUrl: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case storeId       = "store_id"
        case firstName     = "first_name"
        case lastName      = "last_name"
        case email
        case phone
        case avatarUrl     = "avatar_url"
        case isActive      = "is_active"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    // MARK: - Convenience

    var fullName: String { "\(firstName) \(lastName)" }

    /// Maps Supabase snake_case role to the app's UserRole enum.
    var userRole: UserRole {
        switch role {
        case "corporate_admin":      return .corporateAdmin
        case "boutique_manager":     return .boutiqueManager
        case "sales_associate":      return .salesAssociate
        case "inventory_controller": return .inventoryController
        case "service_technician":   return .serviceTechnician
        default:                     return .customer
        }
    }
}

// MARK: - Insert Payload

/// Used when creating a new staff user profile row after Supabase Auth signup.
struct UserInsertDTO: Codable {
    let id: UUID
    let role: String
    let storeId: UUID?
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case storeId   = "store_id"
        case firstName = "first_name"
        case lastName  = "last_name"
        case email
        case phone
        case isActive  = "is_active"
    }
}
