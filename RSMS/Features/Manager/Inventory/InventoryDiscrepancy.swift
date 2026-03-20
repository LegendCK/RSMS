//
//  InventoryDiscrepancy.swift
//  RSMS
//
//  SwiftData model representing an inventory count discrepancy submitted by staff.
//  Managers approve or reject these records; approved records update inventory.quantity.
//

import Foundation
import SwiftData

// MARK: - Discrepancy Status

enum DiscrepancyStatus: String, CaseIterable {
    case pending  = "pending"
    case approved = "approved"
    case rejected = "rejected"

    var displayName: String {
        switch self {
        case .pending:  return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
}

// MARK: - SwiftData Model

@Model
final class InventoryDiscrepancy {
    var id:               UUID
    var storeId:          UUID
    var productId:        UUID
    var productName:      String
    var reportedQuantity: Int
    var systemQuantity:   Int
    var reason:           String
    var status:           String          // DiscrepancyStatus.rawValue
    var reportedBy:       UUID
    var reportedByName:   String
    var reviewedBy:       UUID?
    var managerNotes:     String?
    var createdAt:        Date
    var updatedAt:        Date

    init(
        id:               UUID   = UUID(),
        storeId:          UUID,
        productId:        UUID,
        productName:      String,
        reportedQuantity: Int,
        systemQuantity:   Int,
        reason:           String,
        status:           DiscrepancyStatus = .pending,
        reportedBy:       UUID,
        reportedByName:   String,
        reviewedBy:       UUID?   = nil,
        managerNotes:     String? = nil,
        createdAt:        Date    = Date(),
        updatedAt:        Date    = Date()
    ) {
        self.id               = id
        self.storeId          = storeId
        self.productId        = productId
        self.productName      = productName
        self.reportedQuantity = reportedQuantity
        self.systemQuantity   = systemQuantity
        self.reason           = reason
        self.status           = status.rawValue
        self.reportedBy       = reportedBy
        self.reportedByName   = reportedByName
        self.reviewedBy       = reviewedBy
        self.managerNotes     = managerNotes
        self.createdAt        = createdAt
        self.updatedAt        = updatedAt
    }

    // MARK: - Convenience

    var discrepancyStatus: DiscrepancyStatus {
        DiscrepancyStatus(rawValue: status) ?? .pending
    }

    /// Absolute difference between reported and system quantities
    var quantityDelta: Int {
        abs(reportedQuantity - systemQuantity)
    }

    /// "Short" if reported < system, "Over" if reported > system
    var deltaDirection: String {
        if reportedQuantity < systemQuantity { return "Short" }
        if reportedQuantity > systemQuantity { return "Over" }
        return "Match"
    }
}
