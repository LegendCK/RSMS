//
//  TicketPickupService.swift
//  RSMS
//
//  All Supabase I/O for the ticket_pickups table.
//

import Foundation
import Supabase

protocol TicketPickupServiceProtocol: Sendable {
    func fetchPickup(ticketId: UUID) async throws -> TicketPickupDTO?
    func createPickup(_ payload: TicketPickupInsertDTO) async throws -> TicketPickupDTO
    func schedulePickup(pickupId: UUID, patch: TicketPickupSchedulePatch) async throws -> TicketPickupDTO
    func markReadyForPickup(pickupId: UUID) async throws -> TicketPickupDTO
    func confirmHandover(pickupId: UUID, patch: TicketPickupHandoverPatch) async throws -> TicketPickupDTO
}

final class TicketPickupService: TicketPickupServiceProtocol, @unchecked Sendable {

    static let shared = TicketPickupService()
    private let client = SupabaseManager.shared.client
    private init() {}

    /// Fetch the pickup record for a ticket (nil if none exists yet).
    func fetchPickup(ticketId: UUID) async throws -> TicketPickupDTO? {
        let rows: [TicketPickupDTO] = try await client
            .from("ticket_pickups")
            .select()
            .eq("ticket_id", value: ticketId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Create a new pickup record (called when ticket reaches 'completed').
    func createPickup(_ payload: TicketPickupInsertDTO) async throws -> TicketPickupDTO {
        return try await client
            .from("ticket_pickups")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update scheduled date/time and link to appointment.
    func schedulePickup(pickupId: UUID, patch: TicketPickupSchedulePatch) async throws -> TicketPickupDTO {
        return try await client
            .from("ticket_pickups")
            .update(patch)
            .eq("id", value: pickupId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    /// Mark the pickup as ready — product is packaged, awaiting client.
    func markReadyForPickup(pickupId: UUID) async throws -> TicketPickupDTO {
        struct Patch: Encodable { let status: String }
        return try await client
            .from("ticket_pickups")
            .update(Patch(status: PickupStatus.readyForPickup.rawValue))
            .eq("id", value: pickupId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    /// Record that the product was handed over to the client.
    func confirmHandover(pickupId: UUID, patch: TicketPickupHandoverPatch) async throws -> TicketPickupDTO {
        return try await client
            .from("ticket_pickups")
            .update(patch)
            .eq("id", value: pickupId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}
