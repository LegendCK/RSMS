//
//  ServiceTicketPartsService.swift
//  RSMS
//
//  All Supabase I/O for service_ticket_parts and inventory availability checks.
//

import Foundation
import Supabase

// MARK: - Inventory availability row

struct InventoryAvailabilityDTO: Decodable {
    let productId: UUID
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case quantity
    }
}

// MARK: - Protocol

protocol ServiceTicketPartsServiceProtocol: Sendable {
    func fetchParts(ticketId: UUID) async throws -> [ServiceTicketPartDTO]
    func checkAvailability(productId: UUID, storeId: UUID) async throws -> Int
    func allocatePart(_ payload: ServiceTicketPartInsertDTO) async throws -> ServiceTicketPartDTO
    func updatePartStatus(partId: UUID, patch: ServiceTicketPartStatusPatch) async throws -> ServiceTicketPartDTO
    func releasePart(partId: UUID) async throws -> ServiceTicketPartDTO
}

// MARK: - Implementation

final class ServiceTicketPartsService: ServiceTicketPartsServiceProtocol, @unchecked Sendable {

    static let shared = ServiceTicketPartsService()
    private let client = SupabaseManager.shared.client
    private init() {}

    /// Fetch all parts allocated to a ticket, joining product name/sku.
    func fetchParts(ticketId: UUID) async throws -> [ServiceTicketPartDTO] {
        let parts: [ServiceTicketPartDTO] = try await client
            .from("service_ticket_parts")
            .select("*, products(id, name, sku, brand, price)")
            .eq("ticket_id", value: ticketId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        return parts
    }

    /// Returns current inventory quantity for a product at a store.
    /// Returns 0 if no inventory row exists.
    func checkAvailability(productId: UUID, storeId: UUID) async throws -> Int {
        let rows: [InventoryAvailabilityDTO] = try await client
            .from("inventory")
            .select("product_id, quantity")
            .eq("product_id", value: productId.uuidString)
            .eq("store_id", value: storeId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.quantity ?? 0
    }

    /// Allocates a part to a ticket. The DB trigger automatically
    /// decrements the inventory row (and throws if stock is insufficient).
    func allocatePart(_ payload: ServiceTicketPartInsertDTO) async throws -> ServiceTicketPartDTO {
        // Insert the row — the trigger will decrement inventory or raise an error
        let inserted: ServiceTicketPartDTO = try await client
            .from("service_ticket_parts")
            .insert(payload)
            .select("*, products(id, name, sku, brand, price)")
            .single()
            .execute()
            .value
        return inserted
    }

    /// Updates status (reserved → used / released). The DB trigger restores
    /// inventory automatically when status becomes 'released'.
    func updatePartStatus(partId: UUID, patch: ServiceTicketPartStatusPatch) async throws -> ServiceTicketPartDTO {
        let updated: ServiceTicketPartDTO = try await client
            .from("service_ticket_parts")
            .update(patch)
            .eq("id", value: partId.uuidString)
            .select("*, products(id, name, sku, brand, price)")
            .single()
            .execute()
            .value
        return updated
    }

    func releasePart(partId: UUID) async throws -> ServiceTicketPartDTO {
        let patch = ServiceTicketPartStatusPatch(status: TicketPartStatus.released.rawValue, quantityUsed: nil)
        return try await updatePartStatus(partId: partId, patch: patch)
    }
}
