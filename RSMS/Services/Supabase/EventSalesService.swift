//
//  EventSalesService.swift
//  RSMS
//
//  Supabase operations for boutique event management and event-linked sales reporting.
//  Managers can create/sync events, tag orders to events, and read event ROI summaries.
//

import Foundation
import Supabase

// MARK: - Service

@MainActor
final class EventSalesService {
    static let shared = EventSalesService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Events CRUD

    /// Fetch all events for a store, newest first.
    func fetchEvents(storeId: UUID) async throws -> [EventDTO] {
        try await client
            .from("boutique_events")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    /// Create a new event in Supabase and return the created row.
    func createEvent(_ dto: EventInsertDTO) async throws -> EventDTO {
        try await client
            .from("boutique_events")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
    }

    /// Sync a local SwiftData Event to Supabase (upsert by id).
    func syncEvent(localEvent: Event, storeId: UUID) async throws -> EventDTO {
        let dto = EventInsertDTO(
            storeId:         storeId,
            eventName:       localEvent.eventName,
            eventType:       localEvent.eventTypeRaw,
            status:          localEvent.statusRaw,
            scheduledDate:   localEvent.scheduledDate,
            durationMinutes: localEvent.durationMinutes,
            capacity:        localEvent.capacity,
            hostAssociateId: nil,
            description:     localEvent.eventDescription,
            relatedCategory: localEvent.relatedCategory,
            estimatedCost:   nil,
            currency:        "INR"
        )
        return try await client
            .from("boutique_events")
            .upsert(dto)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update an event's status or estimated cost.
    func updateEvent(eventId: UUID, dto: EventUpdateDTO) async throws {
        try await client
            .from("boutique_events")
            .update(dto)
            .eq("id", value: eventId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Order Tagging

    /// Tag an existing order with an event ID.
    func tagOrder(orderId: UUID, eventId: UUID) async throws {
        struct EventTag: Codable { let event_id: String }
        try await client
            .from("orders")
            .update(EventTag(event_id: eventId.uuidString.lowercased()))
            .eq("id", value: orderId.uuidString.lowercased())
            .execute()
    }

    /// Remove the event tag from an order.
    func untagOrder(orderId: UUID) async throws {
        struct ClearTag: Codable { let event_id: String? }
        try await client
            .from("orders")
            .update(ClearTag(event_id: nil))
            .eq("id", value: orderId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Reports

    /// Fetch all orders tagged to a specific event.
    func fetchEventOrders(eventId: UUID) async throws -> [OrderDTO] {
        try await client
            .from("orders")
            .select()
            .eq("event_id", value: eventId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetch the aggregated sales summary for an event (one row per currency)
    /// from the `event_sales_summary` view.
    func fetchEventSummary(eventId: UUID) async throws -> [EventSalesSummaryDTO] {
        try await client
            .from("event_sales_summary")
            .select()
            .eq("event_id", value: eventId.uuidString.lowercased())
            .execute()
            .value
    }

    /// Fetch summary rows for ALL events in a store (for the manager overview).
    func fetchAllEventSummaries(storeId: UUID) async throws -> [EventSalesSummaryDTO] {
        try await client
            .from("event_sales_summary")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }
}

// MARK: - Currency Helpers

extension EventSalesSummaryDTO {
    /// Returns a locale-aware formatted string for any amount in this summary's currency.
    func formatted(_ amount: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currency
        return fmt.string(from: NSNumber(value: amount)) ?? "\(currency) \(String(format: "%.2f", amount))"
    }
}
