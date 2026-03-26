//
//  AllocationService.swift
//  RSMS
//
//  Supabase service layer for the centralized inventory allocation system.
//  All stock mutations go through transaction-safe RPCs — never direct updates.
//

import Foundation
import Supabase

// MARK: - Protocol

protocol AllocationServiceProtocol: Sendable {
    /// Fetches inventory rows for a specific location, joined with product data.
    func fetchInventory(locationId: UUID) async throws -> [InventoryDTO]

    /// Fetches all inventory rows across all locations, joined with product + store data.
    func fetchAllInventory() async throws -> [InventoryDTO]

    /// Fetches allocations, optionally filtered by status.
    func fetchAllocations(status: AllocationStatus?) async throws -> [AllocationDTO]

    /// Creates an allocation via the server-side RPC (atomic reservation).
    func createAllocation(
        productId: UUID,
        fromLocationId: UUID,
        toLocationId: UUID,
        quantity: Int,
        createdBy: UUID?
    ) async throws -> AllocationRPCResponse

    /// Dispatches a PENDING allocation → IN_TRANSIT via the server-side RPC.
    func dispatchAllocation(allocationId: UUID, performedBy: UUID?) async throws -> AllocationRPCResponse

    /// Completes an allocation via the server-side RPC (atomic stock transfer).
    func completeAllocation(allocationId: UUID, performedBy: UUID?) async throws -> AllocationRPCResponse

    /// Fetches all stores (both boutiques and DCs) for location pickers.
    func fetchLocations() async throws -> [StoreDTO]
}

// MARK: - Implementation



final class AllocationService: AllocationServiceProtocol, @unchecked Sendable {
    static let shared = AllocationService()

    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Inventory

    func fetchInventory(locationId: UUID) async throws -> [InventoryDTO] {
        try await client
            .from("inventory")
            .select("*, products(*)")
            .eq("location_id", value: locationId.uuidString.lowercased())
            .order("quantity", ascending: false)
            .execute()
            .value
    }

    func fetchAllInventory() async throws -> [InventoryDTO] {
        try await client
            .from("inventory")
            .select("*, products(*), stores(*)")
            .order("quantity", ascending: false)
            .execute()
            .value
    }

    // MARK: - Allocations

    func fetchAllocations(status: AllocationStatus? = nil) async throws -> [AllocationDTO] {
        var query = client
            .from("allocations")
            .select("*, products(*)")

        if let status {
            query = query.eq("status", value: status.rawValue)
        }

        return try await query
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
    }

    // MARK: - Create Allocation (RPC)

    func createAllocation(
        productId: UUID,
        fromLocationId: UUID,
        toLocationId: UUID,
        quantity: Int,
        createdBy: UUID?
    ) async throws -> AllocationRPCResponse {
        let params: [String: AnyJSON] = [
            "p_product_id": .string(productId.uuidString.lowercased()),
            "p_from_location_id": .string(fromLocationId.uuidString.lowercased()),
            "p_to_location_id": .string(toLocationId.uuidString.lowercased()),
            "p_quantity": .integer(quantity),
            "p_created_by": createdBy.map { .string($0.uuidString.lowercased()) } ?? .null
        ]

        return try await client
            .rpc("create_allocation", params: params)
            .execute()
            .value
    }

    // MARK: - Dispatch Allocation (RPC)

    func dispatchAllocation(allocationId: UUID, performedBy: UUID?) async throws -> AllocationRPCResponse {
        let params: [String: AnyJSON] = [
            "p_allocation_id": .string(allocationId.uuidString.lowercased()),
            "p_performed_by": performedBy.map { .string($0.uuidString.lowercased()) } ?? .null
        ]

        return try await client
            .rpc("dispatch_allocation", params: params)
            .execute()
            .value
    }

    // MARK: - Complete Allocation (RPC)

    func completeAllocation(allocationId: UUID, performedBy: UUID?) async throws -> AllocationRPCResponse {
        let params: [String: AnyJSON] = [
            "p_allocation_id": .string(allocationId.uuidString.lowercased()),
            "p_performed_by": performedBy.map { .string($0.uuidString.lowercased()) } ?? .null
        ]

        return try await client
            .rpc("complete_allocation", params: params)
            .execute()
            .value
    }

    // MARK: - Locations

    func fetchLocations() async throws -> [StoreDTO] {
        try await client
            .from("stores")
            .select("id, name")
            .order("name")
            .execute()
            .value
    }
}
