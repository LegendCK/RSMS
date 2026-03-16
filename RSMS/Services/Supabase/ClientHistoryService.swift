//
//  ClientHistoryService.swift
//  RSMS
//
//  Fetches purchase, appointment, and after-sales history for a specific client.
//

import Foundation
import Supabase

@MainActor
final class ClientHistoryService {
    static let shared = ClientHistoryService()
    private let client = SupabaseManager.shared.client
    private init() {}

    /// All orders linked to this client, newest first.
    func fetchOrders(for clientId: UUID) async throws -> [OrderDTO] {
        return try await client
            .from("orders")
            .select()
            .eq("client_id", value: clientId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// All appointments linked to this client, newest first.
    func fetchAppointments(for clientId: UUID) async throws -> [AppointmentDTO] {
        return try await client
            .from("appointments")
            .select()
            .eq("client_id", value: clientId.uuidString.lowercased())
            .order("scheduled_at", ascending: false)
            .execute()
            .value
    }

    /// All service tickets (repairs, returns, warranty, etc.) linked to this client, newest first.
    func fetchServiceTickets(for clientId: UUID) async throws -> [ServiceTicketDTO] {
        return try await client
            .from("service_tickets")
            .select()
            .eq("client_id", value: clientId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
