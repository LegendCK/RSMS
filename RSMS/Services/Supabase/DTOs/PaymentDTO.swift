//
//  PaymentDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `payments` table exactly.
//  Columns: id, order_id, method, amount, currency, status,
//           payment_reference, processed_by, created_at, updated_at
//

import Foundation

struct PaymentDTO: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let method: String              // "card" | "cash" | "bank_transfer" | "tax_free_voucher"
    let amount: Double
    let currency: String            // ISO 4217, e.g. "USD"
    let status: String              // "pending" | "completed" | "failed" | "refunded"
    let paymentReference: String?
    let processedBy: UUID?          // FK to users.id (the associate who processed)
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId          = "order_id"
        case method
        case amount
        case currency
        case status
        case paymentReference = "payment_reference"
        case processedBy      = "processed_by"
        case createdAt        = "created_at"
        case updatedAt        = "updated_at"
    }

    // MARK: - Convenience

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    var isSuccessful: Bool { status == "completed" }
}

// MARK: - Insert Payload

struct PaymentInsertDTO: Codable {
    let orderId: UUID
    let method: String
    let amount: Double
    let currency: String
    let status: String
    let paymentReference: String?
    let processedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case orderId          = "order_id"
        case method, amount, currency, status
        case paymentReference = "payment_reference"
        case processedBy      = "processed_by"
    }
}
