//
//  ServiceTicketService.swift
//  RSMS
//
//  All Supabase I/O for the service_tickets table and barcode→product_id
//  resolution. Every other layer (ViewModels, Views) must go through this
//  service — they must NOT import Supabase or PostgREST directly.
//
//  Follows the same pattern as ScanService / ClientService in this project:
//    - @unchecked Sendable singleton
//    - client captured once at init from SupabaseManager.shared.client
//    - protocol for testability
//
//  NEW FILE — place in RSMS/Services/Supabase/
//

import Foundation
import Supabase

// MARK: - Protocol

protocol ServiceTicketServiceProtocol: Sendable {
    func createTicket(_ payload: ServiceTicketInsertDTO) async throws -> ServiceTicketDTO
    func fetchTickets(storeId: UUID) async throws -> [ServiceTicketDTO]
    func fetchTicket(id: UUID) async throws -> ServiceTicketDTO
    func updateStatus(ticketId: UUID, status: String) async throws
    func updateTicket(ticketId: UUID, patch: ServiceTicketUpdatePatch) async throws -> ServiceTicketDTO
    func resolveProductId(forBarcode barcode: String) async throws -> UUID
}

// MARK: - Implementation

final class ServiceTicketService: ServiceTicketServiceProtocol, @unchecked Sendable {

    static let shared = ServiceTicketService()

    // Captured once at init — same pattern as ScanService / ClientService
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Create

    /// Inserts a new service_tickets row and returns the full created record.
    /// ticket_number is populated by a DB trigger if one exists; otherwise
    /// displayTicketNumber falls back to a short UUID.
    func createTicket(_ payload: ServiceTicketInsertDTO) async throws -> ServiceTicketDTO {
        let ticket: ServiceTicketDTO = try await client
            .from("service_tickets")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return ticket
    }

    // MARK: - Fetch List

    /// All tickets for a store, newest first.
    func fetchTickets(storeId: UUID) async throws -> [ServiceTicketDTO] {
        let tickets: [ServiceTicketDTO] = try await client
            .from("service_tickets")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return tickets
    }

    // MARK: - Fetch Single

    func fetchTicket(id: UUID) async throws -> ServiceTicketDTO {
        let ticket: ServiceTicketDTO = try await client
            .from("service_tickets")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return ticket
    }

    // MARK: - Status Update

    /// Patches only the status column — all other columns are untouched.
    func updateStatus(ticketId: UUID, status: String) async throws {
        try await client
            .from("service_tickets")
            .update(ServiceTicketStatusPatch(status: status))
            .eq("id", value: ticketId.uuidString)
            .execute()
    }

    func updateTicket(ticketId: UUID, patch: ServiceTicketUpdatePatch) async throws -> ServiceTicketDTO {
        let ticket: ServiceTicketDTO = try await client
            .from("service_tickets")
            .update(patch)
            .eq("id", value: ticketId.uuidString)
            .select()
            .single()
            .execute()
            .value
        return ticket
    }

    // MARK: - Barcode → Product ID Resolution

    /// Looks up product_items by barcode and returns product_id.
    /// The scanner pipeline already confirmed the barcode is valid, so this
    /// is a cheap secondary read purely to get the UUID FK for the insert.
    /// Isolated here so RepairIntakeViewModel never needs to import Supabase.
    func resolveProductId(forBarcode barcode: String) async throws -> UUID {
        struct Row: Decodable {
            let productId: UUID
            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
            }
        }
        let row: Row = try await client
            .from("product_items")
            .select("product_id")
            .eq("barcode", value: barcode)
            .single()
            .execute()
            .value
        return row.productId
    }
}
