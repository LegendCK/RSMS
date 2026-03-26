//
//  ProductItemDTO.swift
//  RSMS
//
//  Codable DTOs for the `product_items` table and related scan enums.
//  All barcode lookups join product_items with products using PostgREST
//  embedded resource syntax: select("*, products(*)").
//

import Foundation

// MARK: - Enums

enum ProductItemStatus: String, Codable, CaseIterable {
    case inStock  = "IN_STOCK"
    case sold     = "SOLD"
    case reserved = "RESERVED"
    case damaged  = "DAMAGED"
    case returned = "RETURNED"

    var displayName: String {
        switch self {
        case .inStock:  return "In Stock"
        case .sold:     return "Sold"
        case .reserved: return "Reserved"
        case .damaged:  return "Damaged"
        case .returned: return "Returned"
        }
    }
}

enum ScanType: String, Codable, CaseIterable {
    case `in`  = "IN"
    case out   = "OUT"
    case audit = "AUDIT"
    case `return` = "RETURN"

    var displayName: String {
        switch self {
        case .in:    return "Stock In"
        case .out:   return "Stock Out"
        case .audit: return "Audit"
        case .return: return "Return"
        }
    }
}

// MARK: - ProductItemDTO

/// Full DTO returned when querying `product_items` with a joined `products` row.
/// Supabase query: `.from("product_items").select("*, products(*)")`
struct ProductItemDTO: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let barcode: String
    let serialNumber: String?
    let status: String          // Raw value; use `itemStatus` for the typed enum
    let storeId: UUID?
    let createdAt: Date
    let products: ProductDTO?   // Embedded join — nil if product was deleted

    enum CodingKeys: String, CodingKey {
        case id
        case productId    = "product_id"
        case barcode
        case serialNumber = "serial_number"
        case status
        case storeId      = "store_id"
        case createdAt    = "created_at"
        case products
    }

    // MARK: Computed

    var itemStatus: ProductItemStatus {
        ProductItemStatus(rawValue: status) ?? .inStock
    }
}

// MARK: - Insert Payload

struct ProductItemInsertDTO: Codable {
    let productId: UUID
    let barcode: String
    let serialNumber: String?
    let storeId: UUID?

    enum CodingKeys: String, CodingKey {
        case productId    = "product_id"
        case barcode
        case serialNumber = "serial_number"
        case storeId      = "store_id"
    }
}

// MARK: - Scan Log Insert Payload

struct ScanLogInsertDTO: Codable {
    let barcode: String
    let sessionId: UUID
    let type: String    // ScanType.rawValue — persisted to scan_logs.type

    enum CodingKeys: String, CodingKey {
        case barcode
        case sessionId = "session_id"
        case type
    }
}

extension ScanLogInsertDTO {
    init(barcode: String, sessionId: UUID, type: ScanType) {
        self.barcode    = barcode
        self.sessionId  = sessionId
        self.type       = type.rawValue
    }
}

// MARK: - Scan Session Insert / Update Payloads

struct ScanSessionInsertDTO: Codable {
    let type:      String   // ScanType.rawValue
    let storeId:   UUID?    // IC's assigned store — enables per-store session history
    let createdBy: UUID?    // IC's user ID — audit trail

    enum CodingKeys: String, CodingKey {
        case type
        case storeId   = "store_id"
        case createdBy = "created_by"
    }
}

struct ScanSessionEndDTO: Codable {
    let endedAt: Date
    let status: String

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
        case status
    }
}
