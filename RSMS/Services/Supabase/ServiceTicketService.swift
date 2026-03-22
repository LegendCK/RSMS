//
//  ServiceTicketService.swift
//  RSMS
//
//  Service for managing repair and service tickets globally or by store.
//

import Foundation
import Supabase

protocol ServiceTicketServiceProtocol: Sendable {
    func fetchTickets(storeId: UUID) async throws -> [ServiceTicketDTO]
    func resolveProductId(forBarcode barcode: String) async throws -> UUID
    func createTicket(_ payload: ServiceTicketInsertDTO) async throws -> ServiceTicketDTO
    func fetchTicket(id: UUID) async throws -> ServiceTicketDTO
    func updateTicket(id: UUID, patch: ServiceTicketUpdatePatch) async throws -> ServiceTicketDTO
    func updateStatus(ticketId: UUID, status: String) async throws
}

@MainActor
final class ServiceTicketService: ServiceTicketServiceProtocol {
    static let shared = ServiceTicketService()
    private let client = SupabaseManager.shared.client
    private init() {}

    /// All tickets for a specific store, newest first.
    func fetchTickets(storeId: UUID) async throws -> [ServiceTicketDTO] {
        return try await client
            .from("service_tickets")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches a single ticket by its UUID.
    func fetchTicket(id: UUID) async throws -> ServiceTicketDTO {
        return try await client
            .from("service_tickets")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .single()
            .execute()
            .value
    }

    /// Updates existing ticket fields via PATCH.
    func updateTicket(id: UUID, patch: ServiceTicketUpdatePatch) async throws -> ServiceTicketDTO {
        return try await client
            .from("service_tickets")
            .update(patch)
            .eq("id", value: id.uuidString.lowercased())
            .select()
            .single()
            .execute()
            .value
    }

    /// Resolves a barcode string to its corresponding product_id UUID.
    func resolveProductId(forBarcode barcode: String) async throws -> UUID {
        let response = try await client
            .from("products")
            .select("id")
            .eq("barcode", value: barcode)
            .single()
            .execute()
        
        struct IdRow: Codable { let id: UUID }
        let row = try JSONDecoder().decode(IdRow.self, from: response.data)
        return row.id
    }

    /// Creates a new service ticket record in Supabase.
    func createTicket(_ payload: ServiceTicketInsertDTO) async throws -> ServiceTicketDTO {
        return try await client
            .from("service_tickets")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Patches the status of a specific ticket.
    func updateStatus(ticketId: UUID, status: String) async throws {
        try await client
            .from("service_tickets")
            .update(["status": status])
            .eq("id", value: ticketId.uuidString.lowercased())
            .execute()
    }
}
