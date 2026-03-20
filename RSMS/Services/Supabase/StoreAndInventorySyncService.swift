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
            .select("id, store_id, product_id, quantity, reorder_point, updated_at, products(sku, name, categories(name))")
            .eq("store_id", value: storeUuid)
            .execute()

        let records = try JSONDecoder().decode([SupabaseInventoryWithProduct].self, from: response.data)
        
        return records.compactMap { record -> InventoryByLocation? in
            guard let product = record.products else { return nil }
            guard let category = product.categories else { return nil }
            
            return InventoryByLocation(
                locationId: storeId,
                productId: UUID(uuidString: record.product_id) ?? UUID(),
                sku: product.sku ?? "UNKNOWN",
                productName: product.name ?? "Unknown",
                categoryName: category.name ?? "Uncategorized",
                quantity: record.quantity,
                reorderPoint: record.reorder_point ?? 0,
                updatedAt: ISO8601DateFormatter().date(from: record.updated_at ?? "") ?? Date()
            )
        }
    }

    // MARK: - Fetch Transfers from Supabase

    func fetchTransfers() async throws -> [SupabaseTransfer] {
        let response = try await SupabaseManager.shared.client
            .from("transfers")
            .select()
            .order("created_at", ascending: false)
            .execute()

        return try JSONDecoder().decode([SupabaseTransfer].self, from: response.data)
    }

    // MARK: - Sync Inventory with Local SwiftData

    func syncInventoryToLocal(storeId: UUID, modelContext: ModelContext) async throws {
        let remoteInventory = try await fetchInventory(for: storeId)

        // Fetch existing local inventory
        let descriptor = FetchDescriptor<InventoryByLocation>(
            predicate: #Predicate { $0.locationId == storeId }
        )
        let localInventory = try modelContext.fetch(descriptor)

        // Update or insert
        for remote in remoteInventory {
            if let existing = localInventory.first(where: { $0.productId == remote.productId }) {
                existing.quantity = remote.quantity
                existing.reorderPoint = remote.reorderPoint
            } else {
                modelContext.insert(remote)
            }
        }

        try modelContext.save()
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
    let store_id: String
    let product_id: String
    let quantity: Int
    let reorder_point: Int?
    let updated_at: String?
}

struct SupabaseInventoryWithProduct: Codable {
    let id: String
    let store_id: String
    let product_id: String
    let quantity: Int
    let reorder_point: Int?
    let updated_at: String?
    let products: SupabaseProduct?

    enum CodingKeys: String, CodingKey {
        case id, store_id, product_id, quantity, reorder_point, updated_at, products
    }
}

struct SupabaseProduct: Codable {
    let sku: String?
    let name: String?
    let categories: SupabaseCategory?
}

struct SupabaseCategory: Codable {
    let name: String?
}

struct SupabaseTransfer: Codable {
    let id: String
    let transfer_number: String?
    let asn_number: String?
    let product_id: String?
    let quantity: Int
    let received_quantity: Int?
    let from_boutique_id: String?
    let to_boutique_id: String?
    let status: String?
    let requested_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case transfer_number
        case asn_number
        case product_id
        case quantity
        case received_quantity
        case from_boutique_id
        case to_boutique_id
        case status
        case requested_at
        case updated_at
    }
}
