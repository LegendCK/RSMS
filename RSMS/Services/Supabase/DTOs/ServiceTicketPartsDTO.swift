//
//  ServiceTicketPartsDTO.swift
//  RSMS
//
//  Codable DTOs for the service_ticket_parts table.
//

import Foundation

// MARK: - Read DTO

struct ServiceTicketPartDTO: Codable, Identifiable {
    let id: UUID
    let ticketId: UUID
    let productId: UUID
    let storeId: UUID
    let quantityRequired: Int
    let quantityUsed: Int
    let status: String
    let notes: String?
    let allocatedBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    // Joined fields (populated via select)
    let product: TicketPartProductDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case ticketId        = "ticket_id"
        case productId       = "product_id"
        case storeId         = "store_id"
        case quantityRequired = "quantity_required"
        case quantityUsed    = "quantity_used"
        case status, notes
        case allocatedBy     = "allocated_by"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case product         = "products"
    }

    var partStatus: TicketPartStatus {
        TicketPartStatus(rawValue: status) ?? .reserved
    }
}

// MARK: - Minimal product projection joined from products table

struct TicketPartProductDTO: Codable {
    let id: UUID
    let name: String
    let sku: String
    let brand: String?
    let price: Double
}

// MARK: - Insert DTO

struct ServiceTicketPartInsertDTO: Codable {
    let ticketId: UUID
    let productId: UUID
    let storeId: UUID
    let quantityRequired: Int
    let notes: String?
    let allocatedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case ticketId        = "ticket_id"
        case productId       = "product_id"
        case storeId         = "store_id"
        case quantityRequired = "quantity_required"
        case notes
        case allocatedBy     = "allocated_by"
    }
}

// MARK: - Status patch

struct ServiceTicketPartStatusPatch: Encodable {
    let status: String
    let quantityUsed: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case quantityUsed = "quantity_used"
    }
}

// MARK: - Status enum

enum TicketPartStatus: String, CaseIterable, Identifiable {
    case reserved = "reserved"
    case used     = "used"
    case released = "released"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reserved: return "Reserved"
        case .used:     return "Used"
        case .released: return "Released"
        }
    }

    var icon: String {
        switch self {
        case .reserved: return "clock.badge.checkmark"
        case .used:     return "checkmark.circle.fill"
        case .released: return "arrow.uturn.backward.circle"
        }
    }
}
