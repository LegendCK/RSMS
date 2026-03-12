//
//  StoreDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `stores` table exactly.
//  Columns: id, name, country, city, address, currency, timezone,
//           is_active, created_at, updated_at
//

import Foundation

struct StoreDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let country: String             // ISO 3166-1 alpha-2, e.g. "US", "FR", "JP"
    let city: String?
    let address: String?
    let currency: String            // ISO 4217, e.g. "USD", "EUR", "JPY"
    let timezone: String            // e.g. "America/New_York"
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case country
        case city
        case address
        case currency
        case timezone
        case isActive  = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Insert Payload

struct StoreInsertDTO: Codable {
    let name: String
    let country: String
    let city: String?
    let address: String?
    let currency: String
    let timezone: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case name, country, city, address, currency, timezone
        case isActive = "is_active"
    }
}
