//
//  SACatalogViewModel.swift
//  RSMS
//
//  Sales Associate guided catalog — search, filter, sort, inventory awareness.
//

import SwiftUI
import Supabase

@Observable
final class SACatalogViewModel {

    // MARK: - Data
    var products: [ProductDTO] = []
    var categories: [CategoryDTO] = []
    var inventoryMap: [UUID: Int] = [:]     // productId → total qty across all stores

    // MARK: - Search & Filter State
    var searchText = ""
    var selectedCategoryId: UUID? = nil
    var availabilityFilter: AvailabilityFilter = .all
    var minPriceText = ""
    var maxPriceText = ""
    var sortOption: SortOption = .nameAZ
    var showFilters = false

    // MARK: - Async State
    var isLoading = false
    var errorMessage: String? = nil

    // MARK: - Filter Enums

    enum AvailabilityFilter: String, CaseIterable, Identifiable {
        case all        = "All"
        case inStock    = "In Stock"
        case lowStock   = "Low Stock"
        case outOfStock = "Out of Stock"
        var id: Self { self }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case nameAZ    = "Name A–Z"
        case nameZA    = "Name Z–A"
        case priceLow  = "Price ↑"
        case priceHigh = "Price ↓"
        case newest    = "Newest"
        var id: Self { self }
    }

    // MARK: - Computed: Filtered & Sorted List

    var filtered: [ProductDTO] {
        var list = products

        // 1. Keyword search — name, SKU, barcode, brand
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q)
                || $0.sku.lowercased().contains(q)
                || ($0.barcode?.lowercased().contains(q) == true)
                || ($0.brand?.lowercased().contains(q) == true)
                || ($0.description?.lowercased().contains(q) == true)
            }
        }

        // 2. Category filter
        if let catId = selectedCategoryId {
            list = list.filter { $0.categoryId == catId }
        }

        // 3. Availability filter
        list = list.filter { product in
            let qty = inventoryMap[product.id] ?? 0
            switch availabilityFilter {
            case .all:        return true
            case .inStock:    return qty > 5
            case .lowStock:   return qty > 0 && qty <= 5
            case .outOfStock: return qty == 0
            }
        }

        // 4. Price range
        let minP = Double(minPriceText) ?? 0
        if minP > 0 { list = list.filter { $0.price >= minP } }
        if let maxP = Double(maxPriceText), maxP > 0 {
            list = list.filter { $0.price <= maxP }
        }

        // 5. Sort
        switch sortOption {
        case .nameAZ:    list.sort { $0.name < $1.name }
        case .nameZA:    list.sort { $0.name > $1.name }
        case .priceLow:  list.sort { $0.price < $1.price }
        case .priceHigh: list.sort { $0.price > $1.price }
        case .newest:    list.sort { $0.createdAt > $1.createdAt }
        }

        return list
    }

    /// Number of active non-default filters (shown as badge on Filters button)
    var activeFilterCount: Int {
        var count = 0
        if selectedCategoryId != nil { count += 1 }
        if availabilityFilter != .all { count += 1 }
        if !minPriceText.isEmpty || !maxPriceText.isEmpty { count += 1 }
        if sortOption != .nameAZ { count += 1 }
        return count
    }

    // MARK: - Stock Helpers

    func stockQty(for productId: UUID) -> Int {
        inventoryMap[productId] ?? 0
    }

    /// Returns a display label + colour for the stock badge
    func stockInfo(for productId: UUID) -> (label: String, color: Color) {
        let qty = inventoryMap[productId] ?? 0
        if qty == 0       { return ("OUT",        AppColors.error)   }
        if qty <= 5       { return ("\(qty) left", AppColors.warning) }
        return ("In Stock", AppColors.success)
    }

    func categoryName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return categories.first { $0.id == id }?.name
    }

    // MARK: - Filters Reset

    func clearFilters() {
        selectedCategoryId  = nil
        availabilityFilter  = .all
        minPriceText        = ""
        maxPriceText        = ""
        sortOption          = .nameAZ
    }

    // MARK: - Data Loading

    @MainActor
    func load() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let cats = CatalogService.shared.fetchCategories()
            async let prods = CatalogService.shared.fetchProducts()
            async let inv = fetchInventory()
            let (c, p, i) = try await (cats, prods, inv)
            categories   = c.filter { $0.isActive }
            products     = p.filter { $0.isActive }
            inventoryMap = i
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Fetches all inventory rows and sums quantity per product across stores
    private func fetchInventory() async throws -> [UUID: Int] {
        let client = SupabaseManager.shared.client
        let rows: [InventoryDTO] = try await client
            .from("inventory")
            .select()
            .execute()
            .value
        var map: [UUID: Int] = [:]
        for row in rows {
            map[row.productId, default: 0] += row.quantity
        }
        return map
    }
}
