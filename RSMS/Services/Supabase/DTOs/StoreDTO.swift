//
//  StoreDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `stores` table.
//  Core columns: id, name, country, city, address, currency, timezone,
//                is_active, created_at, updated_at
//  Extended columns (optional): code, type, region, manager_name, capacity_units
//

import Foundation

struct StoreDTO: Codable, Identifiable {
    let id: UUID
    let code: String?
    let name: String
    let type: String?
    let country: String
    let city: String?
    let address: String?
    let currency: String
    let timezone: String
    let region: String?
    let managerName: String?
    let capacityUnits: Int?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, code, name, type, country, city, address, currency, timezone, region
        case managerName  = "manager_name"
        case capacityUnits = "capacity_units"
        case isActive     = "is_active"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }
}

// MARK: - Insert Payload

struct StoreInsertDTO: Codable {
    let id: UUID
    let code: String
    let name: String
    let type: String
    let country: String
    let city: String
    let address: String
    let currency: String
    let timezone: String
    let region: String
    let managerName: String
    let capacityUnits: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, code, name, type, country, city, address, currency, timezone, region
        case managerName   = "manager_name"
        case capacityUnits = "capacity_units"
        case isActive      = "is_active"
    }
}
