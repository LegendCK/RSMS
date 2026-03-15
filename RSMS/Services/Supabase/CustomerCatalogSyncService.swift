//
//  CustomerCatalogSyncService.swift
//  RSMS
//
//  Keeps local SwiftData catalog aligned to Supabase for customer-facing flows.
//  Only active categories/products are retained locally.
//

import Foundation
import SwiftData

@MainActor
final class CustomerCatalogSyncService {
    static let shared = CustomerCatalogSyncService()
    private init() {}

    func refreshLocalCatalog(modelContext: ModelContext) async throws {
        async let remoteCategoriesTask = CatalogService.shared.fetchCategories()
        async let remoteProductsTask = CatalogService.shared.fetchProducts()

        let remoteCategories = try await remoteCategoriesTask.filter { $0.isActive }
        let remoteProducts = try await remoteProductsTask.filter { $0.isActive }

        try syncCategories(remoteCategories, modelContext: modelContext)
        try syncProducts(remoteProducts, categories: remoteCategories, modelContext: modelContext)
        try cleanOrphanedCartItems(modelContext: modelContext)

        try modelContext.save()
    }

    private func syncCategories(_ remote: [CategoryDTO], modelContext: ModelContext) throws {
        let locals = try modelContext.fetch(FetchDescriptor<Category>())
        var localById: [UUID: Category] = [:]
        for local in locals {
            if localById[local.id] == nil {
                localById[local.id] = local
            } else {
                modelContext.delete(local)
            }
        }
        let remoteIDs = Set(remote.map(\.id))

        for local in locals where !remoteIDs.contains(local.id) {
            modelContext.delete(local)
            localById.removeValue(forKey: local.id)
        }

        let sortedRemote = remote.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for (index, dto) in sortedRemote.enumerated() {
            if let local = localById[dto.id] {
                local.name = dto.name
                local.categoryDescription = dto.description ?? "Discover our curated collection."
                local.icon = fallbackIcon(forCategory: dto.name)
                local.displayOrder = index
                local.productTypes = "[]"
            } else {
                let category = Category(
                    name: dto.name,
                    icon: fallbackIcon(forCategory: dto.name),
                    description: dto.description ?? "Discover our curated collection.",
                    displayOrder: index,
                    productTypes: "[]"
                )
                category.id = dto.id
                modelContext.insert(category)
            }
        }
    }

    private func syncProducts(
        _ remote: [ProductDTO],
        categories: [CategoryDTO],
        modelContext: ModelContext
    ) throws {
        let locals = try modelContext.fetch(FetchDescriptor<Product>())
        var localById: [UUID: Product] = [:]
        for local in locals {
            if localById[local.id] == nil {
                localById[local.id] = local
            } else {
                modelContext.delete(local)
            }
        }
        let remoteIDs = Set(remote.map(\.id))
        let categoryNamesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        for local in locals where !remoteIDs.contains(local.id) {
            modelContext.delete(local)
            localById.removeValue(forKey: local.id)
        }

        for dto in remote {
            let categoryName = dto.categoryId.flatMap { categoryNamesByID[$0] } ?? "Uncategorized"
            let fallbackIcon = fallbackIcon(forCategory: categoryName)
            let normalizedImages = dto.imageUrls?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            let resolvedImageSource = normalizedImages.first ?? fallbackIcon
            let serializedImageNames = (try? JSONEncoder().encode(normalizedImages))
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""

            if let local = localById[dto.id] {
                local.name = dto.name
                local.brand = dto.brand ?? "Maison Luxe"
                local.productDescription = dto.description ?? "Details coming soon."
                local.price = dto.price
                local.categoryName = categoryName
                local.imageName = resolvedImageSource
                local.imageNames = serializedImageNames
                local.sku = dto.sku
                local.barcode = dto.barcode ?? ""
                local.stockCount = max(local.stockCount, 1)
                local.createdAt = dto.createdAt
            } else {
                let product = Product(
                    name: dto.name,
                    brand: dto.brand ?? "Maison Luxe",
                    description: dto.description ?? "Details coming soon.",
                    price: dto.price,
                    categoryName: categoryName,
                    imageName: resolvedImageSource,
                    isLimitedEdition: false,
                    isFeatured: false,
                    rating: 4.8,
                    stockCount: 10,
                    sku: dto.sku,
                    serialNumber: "",
                    barcode: dto.barcode ?? "",
                    rfidTagID: "",
                    certificateRef: "",
                    productTypeName: "",
                    attributes: "{}",
                    imageNames: serializedImageNames,
                    material: "",
                    countryOfOrigin: "",
                    weight: 0,
                    dimensions: ""
                )
                product.id = dto.id
                product.createdAt = dto.createdAt
                modelContext.insert(product)
            }
        }

        // Ensure Featured section has content while keeping data DB-backed.
        let refreshed = try modelContext.fetch(FetchDescriptor<Product>())
            .sorted { $0.createdAt > $1.createdAt }
        if !refreshed.contains(where: \.isFeatured) {
            for (index, product) in refreshed.enumerated() {
                product.isFeatured = index < 8
            }
        }
    }

    private func cleanOrphanedCartItems(modelContext: ModelContext) throws {
        let products = try modelContext.fetch(FetchDescriptor<Product>())
        let productIDs = Set(products.map(\.id))
        let cartItems = try modelContext.fetch(FetchDescriptor<CartItem>())

        for item in cartItems where !productIDs.contains(item.productId) {
            modelContext.delete(item)
        }
    }

    private func fallbackIcon(forCategory name: String) -> String {
        let value = name.lowercased()
        if value.contains("watch") { return "clock.fill" }
        if value.contains("jewel") { return "sparkles" }
        if value.contains("couture") || value.contains("apparel") || value.contains("wear") {
            return "tshirt.fill"
        }
        return "bag.fill"
    }
}
