//
//  EventDTO.swift
//  RSMS
//
//  Codable DTOs matching the Supabase `boutique_events` table and
//  the `event_sales_summary` view.
//

import Foundation

// MARK: - Event Read DTO

struct EventDTO: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    let eventName: String
    let eventType: String       // "Trunk Show" | "VIP Preview" | etc.
    let status: String          // "Planned" | "Confirmed" | "In Progress" | "Completed" | "Cancelled"
    let scheduledDate: Date
    let durationMinutes: Int
    let capacity: Int
    let hostAssociateId: UUID?
    let description: String
    let relatedCategory: String
    let estimatedCost: Double?
    let currency: String
    let invitedSegment: String? // "gold" | "vip" | nil
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeId            = "store_id"
        case eventName          = "event_name"
        case eventType          = "event_type"
        case status
        case scheduledDate      = "scheduled_date"
        case durationMinutes    = "duration_minutes"
        case capacity
        case hostAssociateId    = "host_associate_id"
        case description
        case relatedCategory    = "related_category"
        case estimatedCost      = "estimated_cost"
        case currency
        case invitedSegment     = "invited_segment"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }

    // Convenience
    var isActive:      Bool { status == "Confirmed" || status == "In Progress" }
    var isPast:        Bool { scheduledDate < Date() }
    var isEditable:    Bool { status == "Planned" || status == "Confirmed" }
    var isCancellable: Bool { status != "Completed" && status != "Cancelled" }
}

// MARK: - Event Insert DTO

struct EventInsertDTO: Codable {
    let storeId:         UUID
    let eventName:       String
    let eventType:       String
    let status:          String
    let scheduledDate:   Date
    let durationMinutes: Int
    let capacity:        Int
    let hostAssociateId: UUID?
    let description:     String
    let relatedCategory: String
    let estimatedCost:   Double?
    let currency:        String
    let invitedSegment:  String?

    enum CodingKeys: String, CodingKey {
        case storeId          = "store_id"
        case eventName        = "event_name"
        case eventType        = "event_type"
        case status
        case scheduledDate    = "scheduled_date"
        case durationMinutes  = "duration_minutes"
        case capacity
        case hostAssociateId  = "host_associate_id"
        case description
        case relatedCategory  = "related_category"
        case estimatedCost    = "estimated_cost"
        case currency
        case invitedSegment   = "invited_segment"
    }
}

// MARK: - Event Update DTO

struct EventUpdateDTO: Codable {
    let eventName:       String?
    let eventType:       String?
    let status:          String?
    let scheduledDate:   Date?
    let durationMinutes: Int?
    let capacity:        Int?
    let description:     String?
    let relatedCategory: String?
    let estimatedCost:   Double?
    let currency:        String?
    let invitedSegment:  String?

    enum CodingKeys: String, CodingKey {
        case eventName        = "event_name"
        case eventType        = "event_type"
        case status
        case scheduledDate    = "scheduled_date"
        case durationMinutes  = "duration_minutes"
        case capacity
        case description
        case relatedCategory  = "related_category"
        case estimatedCost    = "estimated_cost"
        case currency
        case invitedSegment   = "invited_segment"
    }
}

// MARK: - Event Sales Summary DTO (from event_sales_summary view)

struct EventSalesSummaryDTO: Codable, Identifiable {
    var id: String { "\(eventId)-\(currency)" }

    let eventId:       UUID
    let eventName:     String
    let eventType:     String
    let eventStatus:   String
    let scheduledDate: Date
    let storeId:       UUID
    let estimatedCost: Double?
    let currency:      String
    let orderCount:    Int
    let totalRevenue:  Double
    let totalSubtotal: Double
    let totalTax:      Double
    let avgOrderValue: Double
    let firstSaleAt:   Date?
    let lastSaleAt:    Date?
    let roiPercent:    Double?

    enum CodingKeys: String, CodingKey {
        case eventId       = "event_id"
        case eventName     = "event_name"
        case eventType     = "event_type"
        case eventStatus   = "event_status"
        case scheduledDate = "scheduled_date"
        case storeId       = "store_id"
        case estimatedCost = "estimated_cost"
        case currency
        case orderCount    = "order_count"
        case totalRevenue  = "total_revenue"
        case totalSubtotal = "total_subtotal"
        case totalTax      = "total_tax"
        case avgOrderValue = "avg_order_value"
        case firstSaleAt   = "first_sale_at"
        case lastSaleAt    = "last_sale_at"
        case roiPercent    = "roi_percent"
    }

    /// Formatted revenue string respecting the event's own currency
    var formattedRevenue: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currency
        return fmt.string(from: NSNumber(value: totalRevenue)) ?? "\(currency) \(totalRevenue)"
    }

    var formattedAvg: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currency
        return fmt.string(from: NSNumber(value: avgOrderValue)) ?? "\(currency) \(avgOrderValue)"
    }
}
