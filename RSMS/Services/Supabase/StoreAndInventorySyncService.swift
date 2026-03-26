//
//  StoreAndInventorySyncService.swift
//  RSMS
//
//  Service to fetch stores, inventory, and transfers from Supabase
//  and sync with local SwiftData models.
//

import Foundation
import SwiftData
import Supabase

final class StoreAndInventorySyncService {
    static let shared = StoreAndInventorySyncService()

    private init() {}

    // MARK: - Fetch Stores from Supabase

    func fetchStores() async throws -> [StoreLocation] {
        let response = try await SupabaseManager.shared.client
            .from("stores")
            .select()
            .execute()

        let stores = try JSONDecoder().decode([SupabaseStore].self, from: response.data)
        return stores.map { supabaseStore in
            let location = StoreLocation(
                code: supabaseStore.code ?? String(supabaseStore.id.prefix(4)).uppercased(),
                name: supabaseStore.name,
                type: .boutique,
                addressLine1: supabaseStore.address ?? "",
                city: supabaseStore.city ?? "",
                stateProvince: "",
                postalCode: "",
                country: supabaseStore.country ?? "AE",
                region: supabaseStore.city ?? "",
                managerName: "",
                capacityUnits: 0,
                isOperational: supabaseStore.is_active ?? true
            )
            // Preserve the Supabase UUID so ID-based lookups (e.g. currentStoreId match) work correctly
            if let uuid = UUID(uuidString: supabaseStore.id) {
                location.id = uuid
            }
            return location
        }
    }

    // MARK: - Fetch Inventory from Supabase

    func fetchInventory(for storeId: UUID) async throws -> [InventoryByLocation] {
        let storeUuid = storeId.uuidString

        let response = try await SupabaseManager.shared.client
            .from("inventory")
            .select("id, location_id, product_id, quantity, reorder_point, updated_at, products(sku, name, image_urls, categories(name))")
            .eq("location_id", value: storeUuid)
            .execute()

        let records = try JSONDecoder().decode([SupabaseInventoryWithProduct].self, from: response.data)
        let fallbackProducts = try await fetchProductsById(productIds: records.map(\.product_id))

        return records.map { record in
            let product = record.products ?? fallbackProducts[record.product_id]
            let updatedAt = parseISODate(record.updated_at) ?? Date()
            let fallbackSku = "SKU-\(record.product_id.prefix(8).uppercased())"
            let categoryName = product?.categoryName ?? "Uncategorized"

            return InventoryByLocation(
                locationId: storeId,
                productId: UUID(uuidString: record.product_id) ?? UUID(),
                sku: product?.sku ?? fallbackSku,
                productName: product?.name ?? "Unknown Product",
                categoryName: categoryName,
                quantity: record.quantity,
                reorderPoint: record.reorder_point ?? 0,
                updatedAt: updatedAt,
                imageUrl: product?.image_urls?.first
            )
        }
    }

    // MARK: - Fetch Transfers from Supabase

    func fetchTransfers() async throws -> [SupabaseTransfer] {
        do {
            let response = try await SupabaseManager.shared.client
                .from("transfers")
                .select()
                .order("requested_at", ascending: false)
                .execute()
            return try JSONDecoder().decode([SupabaseTransfer].self, from: response.data)
        } catch {
            do {
                let response = try await SupabaseManager.shared.client
                    .from("transfers")
                    .select()
                    .order("updated_at", ascending: false)
                    .execute()
                return try JSONDecoder().decode([SupabaseTransfer].self, from: response.data)
            } catch {
                // Final fallback for legacy schemas with no sortable timestamps.
                let response = try await SupabaseManager.shared.client
                    .from("transfers")
                    .select()
                    .execute()
                return try JSONDecoder().decode([SupabaseTransfer].self, from: response.data)
            }
        }
    }

    // MARK: - Sync Inventory with Local SwiftData

    func syncInventoryToLocal(storeId: UUID, modelContext: ModelContext) async throws {
        let remoteInventory = try await fetchInventory(for: storeId)

        // Fetch existing local inventory
        let descriptor = FetchDescriptor<InventoryByLocation>(
            predicate: #Predicate { $0.locationId == storeId }
        )
        let localInventory = try modelContext.fetch(descriptor)
        let localByProductId = Dictionary(uniqueKeysWithValues: localInventory.map { ($0.productId, $0) })
        let remoteProductIds = Set(remoteInventory.map(\.productId))

        // Update or insert
        for remote in remoteInventory {
            if let existing = localByProductId[remote.productId] {
                existing.quantity = remote.quantity
                existing.reorderPoint = remote.reorderPoint
                existing.updatedAt = remote.updatedAt
                existing.sku = remote.sku
                existing.productName = remote.productName
                existing.categoryName = remote.categoryName
                if let url = remote.imageUrl { existing.imageUrl = url }
            } else {
                modelContext.insert(remote)
            }
        }

        // Remove stale rows that no longer exist remotely for this store.
        for local in localInventory where !remoteProductIds.contains(local.productId) {
            modelContext.delete(local)
        }

        try modelContext.save()
    }

    private func fetchProductsById(productIds: [String]) async throws -> [String: SupabaseProduct] {
        let uniqueIds = Set(productIds.map { $0.lowercased() })
        guard !uniqueIds.isEmpty else { return [:] }

        let response = try await SupabaseManager.shared.client
            .from("products")
            .select("id, sku, name, image_urls, categories(name)")
            .execute()

        let rows = try JSONDecoder().decode([SupabaseProductLookupRow].self, from: response.data)
        return rows.reduce(into: [String: SupabaseProduct]()) { dict, row in
            let key = row.id.lowercased()
            guard uniqueIds.contains(key) else { return }
            dict[key] = SupabaseProduct(
                sku: row.sku,
                name: row.name,
                image_urls: row.image_urls,
                categoryName: row.categoryName
            )
        }
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: value) { return date }

        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: value)
    }
}

// MARK: - Codable models for Supabase responses

struct SupabaseStore: Codable {
    let id: String
    let name: String
    let country: String?
    let city: String?
    let address: String?
    let code: String?
    let timezone: String?
    let is_active: Bool?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, name, country, city, address, code, timezone
        case is_active
        case created_at
        case updated_at
    }
}

struct SupabaseInventory: Codable {
    let id: String
    let location_id: String?
    let product_id: String
    let quantity: Int
    let reorder_point: Int?
    let updated_at: String?
}

struct SupabaseInventoryWithProduct: Decodable {
    let id: String
    let location_id: String?
    let product_id: String
    let quantity: Int
    let reorder_point: Int?
    let updated_at: String?
    let products: SupabaseProduct?

    enum CodingKeys: String, CodingKey {
        case id, location_id, product_id, quantity, reorder_point, updated_at, products
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        location_id = try c.decodeIfPresent(String.self, forKey: .location_id)
        product_id = try c.decode(String.self, forKey: .product_id)
        quantity = try c.decode(Int.self, forKey: .quantity)
        reorder_point = try c.decodeIfPresent(Int.self, forKey: .reorder_point)
        updated_at = try c.decodeIfPresent(String.self, forKey: .updated_at)

        if let single = try? c.decode(SupabaseProduct.self, forKey: .products) {
            products = single
        } else if let many = try? c.decode([SupabaseProduct].self, forKey: .products) {
            products = many.first
        } else {
            products = nil
        }
    }
}

struct SupabaseProduct: Decodable {
    let sku: String?
    let name: String?
    let image_urls: [String]?
    let categoryName: String?

    enum CodingKeys: String, CodingKey {
        case sku, name, image_urls, categories
    }

    init(sku: String?, name: String?, image_urls: [String]?, categoryName: String?) {
        self.sku = sku
        self.name = name
        self.image_urls = image_urls
        self.categoryName = categoryName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sku = try c.decodeIfPresent(String.self, forKey: .sku)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        image_urls = try c.decodeIfPresent([String].self, forKey: .image_urls)

        if let one = try? c.decode(SupabaseCategory.self, forKey: .categories) {
            categoryName = one.name
        } else if let many = try? c.decode([SupabaseCategory].self, forKey: .categories) {
            categoryName = many.first?.name
        } else {
            categoryName = nil
        }
    }
}

struct SupabaseCategory: Codable {
    let name: String?
}

private struct SupabaseProductLookupRow: Decodable {
    let id: String
    let sku: String?
    let name: String?
    let image_urls: [String]?
    let categoryName: String?

    enum CodingKeys: String, CodingKey {
        case id, sku, name, image_urls, categories
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sku = try c.decodeIfPresent(String.self, forKey: .sku)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        image_urls = try c.decodeIfPresent([String].self, forKey: .image_urls)

        if let one = try? c.decode(SupabaseCategory.self, forKey: .categories) {
            categoryName = one.name
        } else if let many = try? c.decode([SupabaseCategory].self, forKey: .categories) {
            categoryName = many.first?.name
        } else {
            categoryName = nil
        }
    }
}

struct SupabaseTransfer: Codable {
    let id: String
    let transfer_number: String?
    let asn_number: String?
    let product_id: String?
    let product_name: String?
    let serial_number: String?
    let quantity: Int
    let received_quantity: Int?
    let from_boutique_id: String?
    let to_boutique_id: String?
    let requested_by_email: String?
    let approved_by_email: String?
    let notes: String?
    let status: String?
    let requested_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case transfer_number
        case asn_number
        case product_id
        case product_name
        case serial_number
        case quantity
        case received_quantity
        case from_boutique_id
        case to_boutique_id
        case requested_by_email
        case approved_by_email
        case notes
        case status
        case requested_at
        case updated_at
    }
}
