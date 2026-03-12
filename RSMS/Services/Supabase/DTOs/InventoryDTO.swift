//
//  InventoryDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `inventory` table exactly.
//  Columns: id, store_id, product_id, quantity, reorder_point, updated_at
//

import Foundation

struct InventoryDTO: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    let productId: UUID
    let quantity: Int
    let reorderPoint: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeId       = "store_id"
        case productId     = "product_id"
        case quantity
        case reorderPoint  = "reorder_point"
        case updatedAt     = "updated_at"
    }

    // MARK: - Convenience

    var isLowStock: Bool { quantity <= reorderPoint && quantity > 0 }
    var isOutOfStock: Bool { quantity == 0 }

    var stockStatus: StockStatus {
        if isOutOfStock { return .outOfStock }
        if isLowStock   { return .low }
        return .inStock
    }

    enum StockStatus {
        case inStock, low, outOfStock
    }
}

// MARK: - Insert / Update Payload

struct InventoryUpsertDTO: Codable {
    let storeId: UUID
    let productId: UUID
    let quantity: Int
    let reorderPoint: Int

    enum CodingKeys: String, CodingKey {
        case storeId      = "store_id"
        case productId    = "product_id"
        case quantity
        case reorderPoint = "reorder_point"
    }
}
