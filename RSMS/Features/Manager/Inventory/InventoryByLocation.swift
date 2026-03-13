//
//  InventoryByLocation.swift
//  RSMS
//
//  SwiftData model representing inventory levels for a product at a specific store location.
//  Synced from/to Supabase `inventory` table by InventorySyncService.
//

import Foundation
import SwiftData

@Model
final class InventoryByLocation {
    var locationId: UUID
    var productId: UUID
    var sku: String
    var productName: String
    var categoryName: String
    var quantity: Int
    var reorderPoint: Int
    var updatedAt: Date

    init(
        locationId: UUID,
        productId: UUID,
        sku: String,
        productName: String,
        categoryName: String,
        quantity: Int,
        reorderPoint: Int,
        updatedAt: Date = Date()
    ) {
        self.locationId = locationId
        self.productId = productId
        self.sku = sku
        self.productName = productName
        self.categoryName = categoryName
        self.quantity = quantity
        self.reorderPoint = reorderPoint
        self.updatedAt = updatedAt
    }
}
