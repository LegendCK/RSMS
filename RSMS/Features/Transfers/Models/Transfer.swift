//
//  Transfer.swift
//  infosys2
//
//  SwiftData model for inter-store and DC-to-store inventory transfers.
//

import Foundation
import SwiftData

enum TransferStatus: String, Codable, CaseIterable {
    case requested = "Requested"
    case approved = "Approved"
    case picking = "Picking"
    case packed = "Packed"
    case inTransit = "In Transit"
    case partiallyReceived = "Partially Received"
    case delivered = "Delivered"
    case cancelled = "Cancelled"
}

@Model
final class Transfer {
    var id: UUID
    var transferNumber: String
    var asnNumber: String
    var asnIssuedAt: Date
    var productId: UUID
    var productName: String
    var serialNumber: String
    var quantity: Int
    var receivedQuantity: Int
    var receivedByEmail: String
    var lastReceivedAt: Date?
    var fromBoutiqueId: String
    var toBoutiqueId: String
    var statusRaw: String
    var requestedByEmail: String
    var approvedByEmail: String
    var shippingTrackingNumber: String
    var notes: String
    var requestedAt: Date
    var updatedAt: Date

    var status: TransferStatus {
        get { TransferStatus(rawValue: statusRaw) ?? .requested }
        set { statusRaw = newValue.rawValue }
    }

    var expectedQuantity: Int {
        max(quantity, 0)
    }

    var missingQuantity: Int {
        max(expectedQuantity - receivedQuantity, 0)
    }

    var extraQuantity: Int {
        max(receivedQuantity - expectedQuantity, 0)
    }

    var hasPartialReceipt: Bool {
        receivedQuantity > 0 && missingQuantity > 0
    }

    var isFullyMatchedToASN: Bool {
        receivedQuantity >= expectedQuantity
    }

    init(
        transferNumber: String,
        asnNumber: String? = nil,
        asnIssuedAt: Date = Date(),
        productId: UUID = UUID(),
        productName: String = "",
        serialNumber: String = "",
        quantity: Int = 1,
        receivedQuantity: Int = 0,
        receivedByEmail: String = "",
        lastReceivedAt: Date? = nil,
        fromBoutiqueId: String = "",
        toBoutiqueId: String = "",
        status: TransferStatus = .requested,
        requestedByEmail: String = "",
        approvedByEmail: String = "",
        shippingTrackingNumber: String = "",
        notes: String = ""
    ) {
        self.id = UUID()
        self.transferNumber = transferNumber
        self.asnNumber = asnNumber ?? "ASN-\(transferNumber)"
        self.asnIssuedAt = asnIssuedAt
        self.productId = productId
        self.productName = productName
        self.serialNumber = serialNumber
        self.quantity = quantity
        self.receivedQuantity = max(receivedQuantity, 0)
        self.receivedByEmail = receivedByEmail
        self.lastReceivedAt = lastReceivedAt
        self.fromBoutiqueId = fromBoutiqueId
        self.toBoutiqueId = toBoutiqueId
        self.statusRaw = status.rawValue
        self.requestedByEmail = requestedByEmail
        self.approvedByEmail = approvedByEmail
        self.shippingTrackingNumber = shippingTrackingNumber
        self.notes = notes
        self.requestedAt = Date()
        self.updatedAt = Date()
    }
}
