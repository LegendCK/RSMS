//
//  TicketPickupDTO.swift
//  RSMS
//
//  Codable DTOs for the ticket_pickups table.
//

import Foundation

// MARK: - Read DTO

struct TicketPickupDTO: Codable, Identifiable {
    let id: UUID
    let ticketId: UUID
    let appointmentId: UUID?
    let storeId: UUID
    let clientId: UUID?
    let scheduledAt: Date?
    let status: String
    let handoverNotes: String?
    let handedOverBy: UUID?
    let handedOverAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ticketId       = "ticket_id"
        case appointmentId  = "appointment_id"
        case storeId        = "store_id"
        case clientId       = "client_id"
        case scheduledAt    = "scheduled_at"
        case status
        case handoverNotes  = "handover_notes"
        case handedOverBy   = "handed_over_by"
        case handedOverAt   = "handed_over_at"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }

    var pickupStatus: PickupStatus {
        PickupStatus(rawValue: status) ?? .pending
    }
}

// MARK: - Insert DTO

struct TicketPickupInsertDTO: Encodable {
    let ticketId: UUID
    let storeId: UUID
    let clientId: UUID?
    let scheduledAt: Date?
    let status: String
    let handoverNotes: String?

    enum CodingKeys: String, CodingKey {
        case ticketId      = "ticket_id"
        case storeId       = "store_id"
        case clientId      = "client_id"
        case scheduledAt   = "scheduled_at"
        case status
        case handoverNotes = "handover_notes"
    }
}

// MARK: - Patch DTOs

struct TicketPickupSchedulePatch: Encodable {
    let scheduledAt: Date
    let status: String
    let appointmentId: UUID?

    enum CodingKeys: String, CodingKey {
        case scheduledAt   = "scheduled_at"
        case status
        case appointmentId = "appointment_id"
    }
}

struct TicketPickupHandoverPatch: Encodable {
    let status: String
    let handoverNotes: String?
    let handedOverBy: UUID
    let handedOverAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case handoverNotes = "handover_notes"
        case handedOverBy  = "handed_over_by"
        case handedOverAt  = "handed_over_at"
    }
}

// MARK: - Status enum

enum PickupStatus: String, CaseIterable, Identifiable {
    case pending         = "pending"
    case scheduled       = "scheduled"
    case readyForPickup  = "ready_for_pickup"
    case handedOver      = "handed_over"
    case cancelled       = "cancelled"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:        return "Pending"
        case .scheduled:      return "Scheduled"
        case .readyForPickup: return "Ready for Pickup"
        case .handedOver:     return "Handed Over"
        case .cancelled:      return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .pending:        return "clock"
        case .scheduled:      return "calendar.badge.checkmark"
        case .readyForPickup: return "shippingbox.fill"
        case .handedOver:     return "checkmark.seal.fill"
        case .cancelled:      return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending:        return .secondary
        case .scheduled:      return .blue
        case .readyForPickup: return .orange
        case .handedOver:     return AppColors.success
        case .cancelled:      return AppColors.error
        }
    }
}

import SwiftUI
