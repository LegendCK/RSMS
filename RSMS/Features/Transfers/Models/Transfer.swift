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
    case delivered = "Delivered"
    case cancelled = "Cancelled"
}

@Model
final class Transfer {
    var id: UUID
    var transferNumber: String
    var productId: UUID
    var productName: String
    var serialNumber: String
    var quantity: Int
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

    init(
        transferNumber: String,
        productId: UUID = UUID(),
        productName: String = "",
        serialNumber: String = "",
        quantity: Int = 1,
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
        self.productId = productId
        self.productName = productName
        self.serialNumber = serialNumber
        self.quantity = quantity
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
