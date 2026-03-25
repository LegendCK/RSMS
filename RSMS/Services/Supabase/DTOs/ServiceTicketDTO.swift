//
//  ServiceTicketDTO.swift
//  RSMS
//
//  Codable DTO matching the Supabase `service_tickets` table exactly.
//  Extended with:
//    - displayTicketNumber  convenience (falls back to short UUID)
//    - RepairStatus enum    typed status values matching DB CHECK constraint
//    - RepairType enum      typed type values matching DB CHECK constraint
//
//  REPLACE the existing ServiceTicketDTO.swift with this file.
//

import Foundation

// MARK: - Read DTO

struct ServiceTicketDTO: Codable, Identifiable {
    let id: UUID
    let ticketNumber: String?
    let clientId: UUID?
    let storeId: UUID
    let assignedTo: UUID?
    let productId: UUID?
    let orderId: UUID?
    let type: String
    let status: String
    let conditionNotes: String?
    let intakePhotos: [String]?
    let estimatedCost: Double?
    let finalCost: Double?
    let estimateBreakdown: [RepairEstimateLineItem]?
    let estimateSubtotal: Double?
    let estimateTax: Double?
    let estimateTotal: Double?
    let estimateSentAt: Date?
    let clientApprovalStatusRaw: String?
    let clientApprovedAt: Date?
    let clientRejectedAt: Date?
    let approvedEstimateSnapshot: RepairEstimateSnapshot?
    let currency: String
    let slaDueDate: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ticketNumber   = "ticket_number"
        case clientId       = "client_id"
        case storeId        = "store_id"
        case assignedTo     = "assigned_to"
        case productId      = "product_id"
        case orderId        = "order_id"
        case type, status, currency, notes
        case conditionNotes = "condition_notes"
        case intakePhotos   = "intake_photos"
        case estimatedCost  = "estimated_cost"
        case finalCost      = "final_cost"
        case estimateBreakdown = "estimate_breakdown"
        case estimateSubtotal = "estimate_subtotal"
        case estimateTax = "estimate_tax"
        case estimateTotal = "estimate_total"
        case estimateSentAt = "estimate_sent_at"
        case clientApprovalStatusRaw = "client_approval_status"
        case clientApprovedAt = "client_approved_at"
        case clientRejectedAt = "client_rejected_at"
        case approvedEstimateSnapshot = "approved_estimate_snapshot"
        case slaDueDate     = "sla_due_date"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }

    // MARK: - Convenience

    /// Human-readable ID — uses DB trigger value when present,
    /// falls back to short UUID so the UI always has something to show.
    var displayTicketNumber: String {
        if let tn = ticketNumber, !tn.isEmpty { return tn }
        return "TKT-\(id.uuidString.prefix(8).uppercased())"
    }

    var ticketStatus: RepairStatus {
        RepairStatus(rawValue: status) ?? .intake
    }

    var ticketType: RepairType {
        RepairType(rawValue: type) ?? .repair
    }

    var clientApprovalStatus: ClientApprovalStatus {
        ClientApprovalStatus(rawValue: clientApprovalStatusRaw ?? "") ?? .pending
    }

    var hasRepairEstimate: Bool {
        if let estimateTotal, estimateTotal > 0 { return true }
        if let estimatedCost, estimatedCost > 0 { return true }
        return !(estimateBreakdown ?? []).isEmpty
    }

    var isOverdue: Bool {
        guard let due = slaDueDate,
              let dueDate = ISO8601DateFormatter().date(from: due + "T00:00:00Z")
        else { return false }
        return Date() > dueDate
            && status != RepairStatus.completed.rawValue
            && status != RepairStatus.cancelled.rawValue
    }
}

// MARK: - Insert Payload

struct ServiceTicketInsertDTO: Codable {
    let clientId: UUID?
    let storeId: UUID
    let assignedTo: UUID?
    let productId: UUID?
    let orderId: UUID?
    let type: String
    let status: String
    let conditionNotes: String?
    let intakePhotos: [String]?
    let estimatedCost: Double?
    let currency: String
    let slaDueDate: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case clientId       = "client_id"
        case storeId        = "store_id"
        case assignedTo     = "assigned_to"
        case productId      = "product_id"
        case orderId        = "order_id"
        case type, status, currency, notes
        case conditionNotes = "condition_notes"
        case intakePhotos   = "intake_photos"
        case estimatedCost  = "estimated_cost"
        case slaDueDate     = "sla_due_date"
    }
}

// MARK: - Status Update Payload

struct ServiceTicketStatusPatch: Encodable {
    let status: String
}

struct ServiceTicketUpdatePatch: Encodable {
    let status: String?
    let notes: String?
    let estimatedCost: Double?
    let finalCost: Double?
    let assignedTo: UUID?
    let estimateBreakdown: [RepairEstimateLineItem]?
    let estimateSubtotal: Double?
    let estimateTax: Double?
    let estimateTotal: Double?
    let estimateSentAt: Date?
    let clientApprovalStatus: String?
    let clientApprovedAt: Date?
    let clientRejectedAt: Date?
    let approvedEstimateSnapshot: RepairEstimateSnapshot?

    init(
        status: String? = nil,
        notes: String? = nil,
        estimatedCost: Double? = nil,
        finalCost: Double? = nil,
        assignedTo: UUID? = nil,
        estimateBreakdown: [RepairEstimateLineItem]? = nil,
        estimateSubtotal: Double? = nil,
        estimateTax: Double? = nil,
        estimateTotal: Double? = nil,
        estimateSentAt: Date? = nil,
        clientApprovalStatus: String? = nil,
        clientApprovedAt: Date? = nil,
        clientRejectedAt: Date? = nil,
        approvedEstimateSnapshot: RepairEstimateSnapshot? = nil
    ) {
        self.status = status
        self.notes = notes
        self.estimatedCost = estimatedCost
        self.finalCost = finalCost
        self.assignedTo = assignedTo
        self.estimateBreakdown = estimateBreakdown
        self.estimateSubtotal = estimateSubtotal
        self.estimateTax = estimateTax
        self.estimateTotal = estimateTotal
        self.estimateSentAt = estimateSentAt
        self.clientApprovalStatus = clientApprovalStatus
        self.clientApprovedAt = clientApprovedAt
        self.clientRejectedAt = clientRejectedAt
        self.approvedEstimateSnapshot = approvedEstimateSnapshot
    }

    enum CodingKeys: String, CodingKey {
        case status
        case notes
        case estimatedCost = "estimated_cost"
        case finalCost = "final_cost"
        case assignedTo = "assigned_to"
        case estimateBreakdown = "estimate_breakdown"
        case estimateSubtotal = "estimate_subtotal"
        case estimateTax = "estimate_tax"
        case estimateTotal = "estimate_total"
        case estimateSentAt = "estimate_sent_at"
        case clientApprovalStatus = "client_approval_status"
        case clientApprovedAt = "client_approved_at"
        case clientRejectedAt = "client_rejected_at"
        case approvedEstimateSnapshot = "approved_estimate_snapshot"
    }
}

struct RepairEstimateLineItem: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var amount: Double

    init(id: UUID = UUID(), title: String, amount: Double) {
        self.id = id
        self.title = title
        self.amount = amount
    }
}

struct RepairEstimateSnapshot: Codable, Hashable {
    var lines: [RepairEstimateLineItem]
    var subtotal: Double
    var tax: Double
    var total: Double
    var currency: String
    var approvedAt: Date
}

enum ClientApprovalStatus: String, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }

    var color: Color {
        switch self {
        case .pending: return AppColors.warning
        case .approved: return AppColors.success
        case .rejected: return AppColors.error
        }
    }
}

// MARK: - RepairStatus
// Values match the DB CHECK constraint on service_tickets.status

enum RepairStatus: String, CaseIterable, Identifiable {
    case intake           = "intake"
    case inProgress       = "in_progress"
    case estimatePending  = "estimate_pending"
    case estimateApproved = "estimate_approved"
    case completed        = "completed"
    case cancelled        = "cancelled"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .intake:           return "Intake"
        case .inProgress:       return "In Progress"
        case .estimatePending:  return "Estimate Pending"
        case .estimateApproved: return "Estimate Approved"
        case .completed:        return "Completed"
        case .cancelled:        return "Cancelled"
        }
    }

    var statusColor: Color {
        switch self {
        case .intake:           return AppColors.warning
        case .inProgress:       return .blue
        case .estimatePending:  return .orange
        case .estimateApproved: return .teal
        case .completed:        return AppColors.success
        case .cancelled:        return AppColors.error
        }
    }
}

// MARK: - RepairType
// Values match the DB CHECK constraint on service_tickets.type

enum RepairType: String, CaseIterable, Identifiable {
    case repair         = "repair"
    case authentication = "authentication"
    case valuation      = "valuation"
    case warrantyClaim  = "warranty_claim"
    case cleaning       = "cleaning"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .repair:         return "Repair"
        case .authentication: return "Authentication"
        case .valuation:      return "Valuation"
        case .warrantyClaim:  return "Warranty Claim"
        case .cleaning:       return "Cleaning"
        }
    }

    var icon: String {
        switch self {
        case .repair:         return "wrench.and.screwdriver"
        case .authentication: return "checkmark.seal"
        case .valuation:      return "banknote"
        case .warrantyClaim:  return "shield.checkered"
        case .cleaning:       return "sparkles"
        }
    }
}

// MARK: - SwiftUI import for Color used in RepairStatus.statusColor
import SwiftUI
