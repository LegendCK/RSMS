//
//  InventorySyncService.swift
//  infosys2
//
//  Syncs InventoryByLocation between local SwiftData and Supabase ⁠ inventory ⁠.
//

import Foundation
import SwiftData
import Supabase

@MainActor
final class InventorySyncService {
    static let shared = InventorySyncService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func syncInventory(modelContext: ModelContext) async throws {
        try await pushLocalInventory(modelContext: modelContext)
        try await pullRemoteInventory(modelContext: modelContext)
    }

    func upsertInventory(_ row: InventoryByLocation) async throws -> InventoryDTO {
        let payload = InventoryUpsertDTO(
            locationId: row.locationId,
            productId: row.productId,
            quantity: row.quantity,
            reorderPoint: row.reorderPoint
        )

        let dto: InventoryDTO = try await client
            .from("inventory")
            .upsert(payload, onConflict: "location_id,product_id")
            .select()
            .single()
            .execute()
            .value

        return dto
    }

    private func pushLocalInventory(modelContext: ModelContext) async throws {
        let locals = (try? modelContext.fetch(FetchDescriptor<InventoryByLocation>())) ?? []
        for row in locals {
            _ = try await upsertInventory(row)
        }
    }

    private func pullRemoteInventory(modelContext: ModelContext) async throws {
        let remote: [InventoryDTO] = try await client
            .from("inventory")
            .select()
            .execute()
            .value

        let products = (try? modelContext.fetch(FetchDescriptor<Product>())) ?? []
        let productById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        let existing = (try? modelContext.fetch(FetchDescriptor<InventoryByLocation>())) ?? []
        var byComposite = Dictionary(
            uniqueKeysWithValues: existing.map { (compositeKey(locationId: $0.locationId, productId: $0.productId), $0) }
        )

        for row in remote {
            let key = compositeKey(locationId: row.locationId, productId: row.productId)
            if let local = byComposite[key] {
                local.quantity = row.quantity
                local.reorderPoint = row.reorderPoint ?? 5
                local.updatedAt = row.updatedAt ?? Date()
            } else {
                let product = productById[row.productId]
                let created = InventoryByLocation(
                    locationId: row.locationId,
                    productId: row.productId,
                    sku: product?.sku ?? row.productId.uuidString,
                    productName: product?.name ?? "Unknown Product",
                    categoryName: product?.categoryName ?? "Unknown",
                    quantity: row.quantity,
                    reorderPoint: row.reorderPoint ?? 5
                )
                created.updatedAt = row.updatedAt ?? Date()
                modelContext.insert(created)
                byComposite[key] = created
            }
        }

        try? modelContext.save()
    }

    private func compositeKey(locationId: UUID, productId: UUID) -> String {
        "\(locationId.uuidString.lowercased())::\(productId.uuidString.lowercased())"
    }
}
