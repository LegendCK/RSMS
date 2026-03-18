import Foundation
import Supabase

struct AdminInsightsSnapshot {
    let orders: [OrderDTO]
    let orderItems: [OrderItemDTO]
    let stores: [StoreDTO]
    let users: [UserDTO]
    let clients: [ClientDTO]
    let appointments: [AppointmentDTO]
    let serviceTickets: [ServiceTicketDTO]
    let inventory: [InventoryDTO]
    let products: [ProductDTO]
    let syncedAt: Date
}

@MainActor
final class AdminInsightsService {
    static let shared = AdminInsightsService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func fetchLatestSnapshot() async throws -> AdminInsightsSnapshot {
        async let orders: [OrderDTO] = client
            .from("orders")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        async let orderItems: [OrderItemDTO] = client
            .from("order_items")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        async let stores: [StoreDTO] = client
            .from("stores")
            .select()
            .execute()
            .value

        async let users: [UserDTO] = client
            .from("users")
            .select()
            .execute()
            .value

        async let clients: [ClientDTO] = client
            .from("clients")
            .select()
            .execute()
            .value

        async let appointments: [AppointmentDTO] = client
            .from("appointments")
            .select()
            .order("scheduled_at", ascending: false)
            .execute()
            .value

        async let serviceTickets: [ServiceTicketDTO] = client
            .from("service_tickets")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        async let inventory: [InventoryDTO] = client
            .from("inventory")
            .select()
            .execute()
            .value

        async let products: [ProductDTO] = CatalogService.shared.fetchProducts()

        return try await AdminInsightsSnapshot(
            orders: orders,
            orderItems: orderItems,
            stores: stores,
            users: users,
            clients: clients,
            appointments: appointments,
            serviceTickets: serviceTickets,
            inventory: inventory,
            products: products,
            syncedAt: Date()
        )
    }
}
