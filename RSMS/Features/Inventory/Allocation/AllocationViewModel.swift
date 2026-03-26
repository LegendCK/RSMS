//
//  AllocationViewModel.swift
//  RSMS
//
//  ViewModel for the Distribution (Central Allocation) screen.
//  Loads inventory across all locations, supports SKU search,
//  and creates allocations via AllocationService RPC.
//

import SwiftUI

@Observable
@MainActor
final class AllocationViewModel {

    // MARK: - State

    var inventory: [InventoryDTO] = []
    var locations: [StoreDTO] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    // Allocation creation
    var isCreating = false
    var creationSuccess = false
    var creationError: String?

    // MARK: - Dependencies

    private let service: AllocationServiceProtocol

    init(service: AllocationServiceProtocol = AllocationService.shared) {
        self.service = service
    }

    // MARK: - Computed

    /// Groups inventory by product, showing all locations for each product.
    var groupedByProduct: [UUID: [InventoryDTO]] {
        Dictionary(grouping: filteredInventory, by: \.productId)
    }

    /// Unique products from inventory, filtered by search text.
    var filteredInventory: [InventoryDTO] {
        guard !searchText.isEmpty else { return inventory }
        let query = searchText.lowercased()
        return inventory.filter { inv in
            inv.products?.name.lowercased().contains(query) == true ||
            inv.products?.sku.lowercased().contains(query) == true ||
            inv.products?.brand?.lowercased().contains(query) == true
        }
    }

    /// Unique products from filtered inventory.
    var uniqueProducts: [ProductDTO] {
        var seen = Set<UUID>()
        return filteredInventory.compactMap { inv -> ProductDTO? in
            guard let product = inv.products, seen.insert(product.id).inserted else { return nil }
            return product
        }
    }

    /// Get inventory rows for a specific product across all locations.
    func inventoryForProduct(_ productId: UUID) -> [InventoryDTO] {
        filteredInventory.filter { $0.productId == productId }
    }

    /// Locations that have available stock for a product.
    func sourceLocations(for productId: UUID) -> [InventoryDTO] {
        inventory.filter { $0.productId == productId && ($0.quantity - $0.reservedQuantity) > 0 }
    }

    /// Location name lookup
    func locationName(for id: UUID) -> String {
        locations.first(where: { $0.id == id })?.name ?? "Unknown"
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let inv = service.fetchAllInventory()
            async let locs = service.fetchLocations()
            inventory = try await inv
            locations = try await locs
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create Allocation

    func createAllocation(
        productId: UUID,
        fromLocationId: UUID,
        toLocationId: UUID,
        quantity: Int,
        createdBy: UUID?
    ) async {
        isCreating = true
        creationSuccess = false
        creationError = nil
        defer { isCreating = false }

        do {
            let response = try await service.createAllocation(
                productId: productId,
                fromLocationId: fromLocationId,
                toLocationId: toLocationId,
                quantity: quantity,
                createdBy: createdBy
            )

            if response.success {
                creationSuccess = true
                // Refresh inventory to reflect new reservations
                await loadData()
            } else {
                creationError = response.error ?? "Allocation failed"
            }
        } catch {
            creationError = error.localizedDescription
        }
    }
}
