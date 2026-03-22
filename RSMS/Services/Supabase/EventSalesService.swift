import Foundation
import Supabase

@MainActor
final class EventSalesService {
    static let shared = EventSalesService()
    private let client = SupabaseManager.shared.client
    private init() {}

    func fetchEvents(storeId: UUID) async throws -> [EventDTO] {
        return try await client
            .from("boutique_events")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }
}
