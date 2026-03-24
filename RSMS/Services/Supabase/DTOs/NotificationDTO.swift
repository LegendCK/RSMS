//
//  NotificationDTO.swift
//  RSMS
//
//  Codable DTOs matching the Supabase `notifications` table.
//

import Foundation

// MARK: - Read DTO

struct NotificationDTO: Codable, Identifiable {
    let id:                UUID
    let recipientClientId: UUID
    let storeId:           UUID?
    let title:             String
    let message:           String
    let category:          String
    let isRead:            Bool
    let deepLink:          String
    let createdAt:         Date

    enum CodingKeys: String, CodingKey {
        case id
        case recipientClientId = "recipient_client_id"
        case storeId           = "store_id"
        case title, message, category
        case isRead            = "is_read"
        case deepLink          = "deep_link"
        case createdAt         = "created_at"
    }

    var notificationCategory: NotificationCategory {
        NotificationCategory(rawValue: category.capitalized) ?? .system
    }
}

// MARK: - Insert DTO

struct NotificationInsertDTO: Codable {
    let recipientClientId: UUID
    let storeId:           UUID?
    let title:             String
    let message:           String
    let category:          String
    let deepLink:          String

    enum CodingKeys: String, CodingKey {
        case recipientClientId = "recipient_client_id"
        case storeId           = "store_id"
        case title, message, category
        case deepLink          = "deep_link"
    }
}

// MARK: - Event Invitation DTO

struct EventInvitationDTO: Codable, Identifiable {
    let id:        UUID
    let eventId:   UUID
    let clientId:  UUID
    let status:    String   // "pending" | "sent" | "rsvp_yes" | "rsvp_no"
    let invitedAt: Date
    let rsvpAt:    Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId   = "event_id"
        case clientId  = "client_id"
        case status
        case invitedAt = "invited_at"
        case rsvpAt    = "rsvp_at"
    }
}

struct EventInvitationInsertDTO: Codable {
    let eventId:  UUID
    let clientId: UUID
    let status:   String

    enum CodingKeys: String, CodingKey {
        case eventId  = "event_id"
        case clientId = "client_id"
        case status
    }
}

// MARK: - RSVP Update DTO

struct RSVPUpdateDTO: Codable {
    let status:  String
    let rsvpAt:  Date

    enum CodingKeys: String, CodingKey {
        case status
        case rsvpAt = "rsvp_at"
    }
}

// MARK: - RSVP Counts

struct RSVPCounts {
    var yes:     Int = 0
    var no:      Int = 0
    var pending: Int = 0
    var total:   Int { yes + no + pending }
}
