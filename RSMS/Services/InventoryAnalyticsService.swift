//
//  InventoryAnalyticsService.swift
//  RSMS
//
//  Analyzes inventory arrays to provide grouped metrics without 
//  relying on SQL GROUP BY backend RPCs.
//

import Foundation
import Supabase

enum StockAlertLevel: String, Codable {
    case critical = "CRITICAL" // 0 - 2
    case low = "LOW"           // 3 - 5
}

struct LowStockAlert: Identifiable {
    let id: UUID
    let productId: UUID
    let productName: String
    let brand: String
    let stockCount: Int
    
    var alertLevel: StockAlertLevel {
        return stockCount <= 2 ? .critical : .low
    }
}

final class InventoryAnalyticsService: Sendable {
    static let shared = InventoryAnalyticsService()
    
    private init() {}
    
    /// Fetches all IN_STOCK items, groups them in memory, and returns 
    /// products meeting the low stock thresholds (<= 5).
    func fetchLowStockAlerts() async throws -> [LowStockAlert] {
        // Fetch raw product items joined with product metadata
        // Limiting to 1000 to protect client bandwidth as constraints dictate
        let items: [ProductItemDTO] = try await SupabaseManager.shared.client
            .from("product_items")
            .select("id, product_id, barcode, serial_number, status, store_id, created_at, products(id, name, brand)")
            .eq("status", value: "IN_STOCK")
            .limit(1000)
            .execute()
            .value
        
        // Group items by product_id
        let grouped = Dictionary(grouping: items, by: { $0.productId })
        
        var alerts: [LowStockAlert] = []
        
        for (productId, productItems) in grouped {
            let stockCount = productItems.count
            
            // Apply Thresholds: Only care about 5 or fewer
            if stockCount <= 5 {
                // Safely extract the joined product metadata from the first valid item
                if let firstExtracted = productItems.first(where: { $0.products != nil }),
                   let product = firstExtracted.products {
                    
                    let alert = LowStockAlert(
                        id: UUID(),
                        productId: productId,
                        productName: product.name,
                        brand: product.brand ?? "UNKNOWN",
                        stockCount: stockCount
                    )
                    alerts.append(alert)
                }
            }
        }
        
        // Sort ascending by stock count (critical 0/1/2 units at the very top)
        alerts.sort { $0.stockCount < $1.stockCount }
        
        return alerts
    }
}
