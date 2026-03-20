//
//  TransferDTO.swift
//  RSMS
//
//  Payload DTOs for syncing transfer receipts to Supabase `transfers`.
//

import Foundation

struct TransferUpsertDTO: Codable {
    let id: UUID
    let transferNumber: String
    let asnNumber: String
    let asnIssuedAt: Date
    let productId: UUID
    let productName: String
    let serialNumber: String
    let quantity: Int
    let receivedQuantity: Int
    let receivedByEmail: String
    let lastReceivedAt: Date?
    let fromBoutiqueId: String
    let toBoutiqueId: String
    let status: String
    let requestedByEmail: String
    let approvedByEmail: String
    let shippingTrackingNumber: String
    let notes: String
    let requestedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case transferNumber = "transfer_number"
        case asnNumber = "asn_number"
        case asnIssuedAt = "asn_issued_at"
        case productId = "product_id"
        case productName = "product_name"
        case serialNumber = "serial_number"
        case quantity
        case receivedQuantity = "received_quantity"
        case receivedByEmail = "received_by_email"
        case lastReceivedAt = "last_received_at"
        case fromBoutiqueId = "from_boutique_id"
        case toBoutiqueId = "to_boutique_id"
        case status
        case requestedByEmail = "requested_by_email"
        case approvedByEmail = "approved_by_email"
        case shippingTrackingNumber = "shipping_tracking_number"
        case notes
        case requestedAt = "requested_at"
        case updatedAt = "updated_at"
    }

    init(transfer: Transfer) {
        id = transfer.id
        transferNumber = transfer.transferNumber
        asnNumber = transfer.asnNumber
        asnIssuedAt = transfer.asnIssuedAt
        productId = transfer.productId
        productName = transfer.productName
        serialNumber = transfer.serialNumber
        quantity = transfer.quantity
        receivedQuantity = transfer.receivedQuantity
        receivedByEmail = transfer.receivedByEmail
        lastReceivedAt = transfer.lastReceivedAt
        fromBoutiqueId = transfer.fromBoutiqueId
        toBoutiqueId = transfer.toBoutiqueId
        status = transfer.status.rawValue
        requestedByEmail = transfer.requestedByEmail
        approvedByEmail = transfer.approvedByEmail
        shippingTrackingNumber = transfer.shippingTrackingNumber
        notes = transfer.notes
        requestedAt = transfer.requestedAt
        updatedAt = transfer.updatedAt
    }
}

struct TransferMinimalUpsertDTO: Codable {
    let id: UUID
    let transferNumber: String
    let fromBoutiqueId: String
    let toBoutiqueId: String
    let quantity: Int
    let receivedQuantity: Int
    let status: String
    let notes: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case transferNumber = "transfer_number"
        case fromBoutiqueId = "from_boutique_id"
        case toBoutiqueId = "to_boutique_id"
        case quantity
        case receivedQuantity = "received_quantity"
        case status
        case notes
        case updatedAt = "updated_at"
    }

    init(transfer: Transfer) {
        id = transfer.id
        transferNumber = transfer.transferNumber
        fromBoutiqueId = transfer.fromBoutiqueId
        toBoutiqueId = transfer.toBoutiqueId
        quantity = transfer.quantity
        receivedQuantity = transfer.receivedQuantity
        status = transfer.status.rawValue
        notes = transfer.notes
        updatedAt = transfer.updatedAt
    }
}

struct TransferReceiptPatchDTO: Codable {
    let status: String
    let receivedQuantity: Int
    let receivedByEmail: String
    let lastReceivedAt: Date?
    let notes: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case receivedQuantity = "received_quantity"
        case receivedByEmail = "received_by_email"
        case lastReceivedAt = "last_received_at"
        case notes
        case updatedAt = "updated_at"
    }

    init(transfer: Transfer) {
        status = transfer.status.rawValue
        receivedQuantity = transfer.receivedQuantity
        receivedByEmail = transfer.receivedByEmail
        lastReceivedAt = transfer.lastReceivedAt
        notes = transfer.notes
        updatedAt = transfer.updatedAt
    }
}