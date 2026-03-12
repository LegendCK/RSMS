//
//  OrderDTO.swift
//  infosys2
//
//  Codable DTOs matching the Supabase `orders` and `order_items` tables exactly.
//
//  orders columns:
//    id, order_number, client_id, store_id, associate_id, channel,
//    status, subtotal, tax_total, grand_total, currency, is_tax_free,
//    notes, created_at, updated_at
//
//  order_items columns:
//    id, order_id, product_id, quantity, unit_price, tax_amount,
//    line_total, created_at
//

import Foundation

// MARK: - OrderDTO

struct OrderDTO: Codable, Identifiable {
    let id: UUID
    let orderNumber: String?
    let clientId: UUID?
    let storeId: UUID
    let associateId: UUID?
    let channel: String             // "in_store" | "online" | "bopis" | "ship_from_store"
    let status: String              // "pending" | "confirmed" | "processing" | "shipped" | "delivered" | "completed" | "cancelled"
    let subtotal: Double
    let taxTotal: Double
    let grandTotal: Double
    let currency: String            // ISO 4217, e.g. "USD"
    let isTaxFree: Bool
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber  = "order_number"
        case clientId     = "client_id"
        case storeId      = "store_id"
        case associateId  = "associate_id"
        case channel
        case status
        case subtotal
        case taxTotal     = "tax_total"
        case grandTotal   = "grand_total"
        case currency
        case isTaxFree    = "is_tax_free"
        case notes
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    // MARK: - Convenience

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: grandTotal)) ?? "\(currency) \(grandTotal)"
    }
}

// MARK: - OrderItemDTO

struct OrderItemDTO: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let productId: UUID
    let quantity: Int
    let unitPrice: Double
    let taxAmount: Double
    let lineTotal: Double
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId   = "order_id"
        case productId = "product_id"
        case quantity
        case unitPrice = "unit_price"
        case taxAmount = "tax_amount"
        case lineTotal = "line_total"
        case createdAt = "created_at"
    }
}

// MARK: - Insert Payloads

struct OrderInsertDTO: Codable {
    let clientId: UUID?
    let storeId: UUID
    let associateId: UUID?
    let channel: String
    let status: String
    let subtotal: Double
    let taxTotal: Double
    let grandTotal: Double
    let currency: String
    let isTaxFree: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case clientId    = "client_id"
        case storeId     = "store_id"
        case associateId = "associate_id"
        case channel, status, subtotal, currency, notes
        case taxTotal    = "tax_total"
        case grandTotal  = "grand_total"
        case isTaxFree   = "is_tax_free"
    }
}

struct OrderItemInsertDTO: Codable {
    let orderId: UUID
    let productId: UUID
    let quantity: Int
    let unitPrice: Double
    let taxAmount: Double
    let lineTotal: Double

    enum CodingKeys: String, CodingKey {
        case orderId   = "order_id"
        case productId = "product_id"
        case quantity
        case unitPrice = "unit_price"
        case taxAmount = "tax_amount"
        case lineTotal = "line_total"
    }
}
