import Foundation
import Supabase

@MainActor
final class EventSalesService {
    static let shared = EventSalesService()
    private let client = SupabaseManager.shared.client
    private init() {}

    // MARK: - Events CRUD

    /// Fetch all events for a store, newest first.
    /// Auto-transitions statuses (Planned→In Progress→Completed) before returning.
    func fetchEvents(storeId: UUID) async throws -> [EventDTO] {
        _ = try? await client
            .rpc("auto_transition_event_statuses",
                 params: ["p_store_id": storeId.uuidString.lowercased()])
            .execute()
        return try await client
            .from("boutique_events")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    /// Cancel an event. Only allowed for non-Completed, non-Cancelled events.
    func cancelEvent(eventId: UUID) async throws {
        struct CancelPatch: Encodable { let status: String }
        try await client
            .from("boutique_events")
            .update(CancelPatch(status: "Cancelled"))
            .eq("id", value: eventId.uuidString.lowercased())
            .execute()
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

    /// Update an existing event and return the updated row.
    func updateEvent(eventId: UUID, dto: EventUpdateDTO) async throws -> EventDTO {
        try await client
            .from("boutique_events")
            .update(dto)
            .eq("id", value: eventId.uuidString.lowercased())
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
            currency:        "INR",
            invitedSegment:  nil
        )
        return try await client
            .from("boutique_events")
            .upsert(dto)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update an existing event's fields.
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

    /// Fetch the aggregated sales summary for an event (one row per currency).
    func fetchEventSummary(eventId: UUID) async throws -> [EventSalesSummaryDTO] {
        try await client
            .from("event_sales_summary")
            .select()
            .eq("event_id", value: eventId.uuidString.lowercased())
            .execute()
            .value
    }

    /// Fetch summary rows for ALL events in a store (manager overview).
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
