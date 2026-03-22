import Foundation
import Supabase

@MainActor
final class AdminInsightsService {
    static let shared = AdminInsightsService()
    private let client = SupabaseManager.shared.client
    private init() {}

    func fetchLatestSnapshot() async throws -> AdminInsightsSnapshot {
        // In a real app, this would be a single RPC or parallel fetches.
        // For simplicity, we'll simulate the data structure expected by the view.
        
        async let stores: [StoreDTO] = client.from("stores").select().execute().value
        async let orders: [OrderDTO] = client.from("orders").select().execute().value
        async let items: [OrderItemDTO] = client.from("order_items").select().execute().value
        async let inventory: [InventoryDTO] = client.from("inventory").select().execute().value
        async let users: [UserDTO] = client.from("users").select().execute().value
        async let appointments: [AppointmentDTO] = client.from("appointments").select().execute().value
        async let clients: [ClientDTO] = client.from("clients").select().execute().value
        async let tickets: [ServiceTicketDTO] = client.from("service_tickets").select().execute().value

        return AdminInsightsSnapshot(
            stores:          try await stores,
            orders:          try await orders,
            orderItems:      try await items,
            inventory:       try await inventory,
            users:           try await users,
            appointments:    try await appointments,
            clients:         try await clients,
            serviceTickets:  try await tickets,
            syncedAt:        Date()
        )
    }
}
