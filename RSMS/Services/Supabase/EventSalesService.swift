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
        try? await client
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
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }
}
