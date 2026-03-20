//
//  OrderFulfillmentService.swift
//  RSMS
//
//  Handles the backend operations for order fulfillment by Inventory Controllers:
//  - Updating order status in Supabase
//  - Decrementing inventory quantities in Supabase
//  - Fetching order items for picking/packing
//

import Foundation
import Supabase

@MainActor
final class OrderFulfillmentService {
    static let shared = OrderFulfillmentService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Update Order Status

    /// Moves an order to a new status in Supabase.
    /// Valid transitions: confirmed → processing → shipped/ready_for_pickup → delivered/completed
    func updateOrderStatus(orderId: UUID, newStatus: String) async throws {
        struct StatusUpdate: Encodable {
            let status: String
            let updated_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try await client
            .from("orders")
            .update(StatusUpdate(status: newStatus, updated_at: now))
            .eq("id", value: orderId.uuidString.lowercased())
            .execute()

        print("[OrderFulfillmentService] ✅ Order \(orderId) → \(newStatus)")
    }

    // MARK: - Fetch Order Items

    /// Fetches line items for a specific order so the IC can see what to pick/pack.
    func fetchOrderItems(orderId: UUID) async throws -> [OrderItemWithProduct] {
        let response = try await client
            .from("order_items")
            .select("id, order_id, product_id, quantity, unit_price, line_total, products(name, sku)")
            .eq("order_id", value: orderId.uuidString.lowercased())
            .execute()

        return try JSONDecoder().decode([OrderItemWithProduct].self, from: response.data)
    }

    // MARK: - Decrement Supabase Inventory

    /// Reduces the inventory quantity for a product at a specific store in Supabase.
    /// Called when IC marks an order as "processing" (items picked from shelves).
    func decrementInventory(productId: UUID, storeId: UUID, quantity: Int) async throws {
        // First fetch current inventory
        let response = try await client
            .from("inventory")
            .select("id, quantity")
            .eq("product_id", value: productId.uuidString.lowercased())
            .eq("store_id", value: storeId.uuidString.lowercased())
            .limit(1)
            .execute()

        struct InventoryRow: Codable {
            let id: String
            let quantity: Int
        }

        let rows = try JSONDecoder().decode([InventoryRow].self, from: response.data)
        guard let row = rows.first else {
            print("[OrderFulfillmentService] No inventory row for product \(productId) at store \(storeId)")
            return
        }

        let newQty = max(0, row.quantity - quantity)

        struct QtyUpdate: Encodable {
            let quantity: Int
            let updated_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("inventory")
            .update(QtyUpdate(quantity: newQty, updated_at: now))
            .eq("id", value: row.id)
            .execute()

        print("[OrderFulfillmentService] ✅ Inventory for product \(productId): \(row.quantity) → \(newQty)")
    }

    // MARK: - Fetch Pending Orders for Store

    /// Fetches all non-terminal orders for a store that need fulfillment.
    func fetchFulfillmentOrders(storeId: UUID) async throws -> [OrderDTO] {
        let orders: [OrderDTO] = try await client
            .from("orders")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .not("status", operator: .in, value: "(completed,cancelled,delivered)")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value

        return orders
    }
}

// MARK: - Supporting Model

struct OrderItemWithProduct: Codable, Identifiable {
    let id: UUID
    let order_id: String
    let product_id: String
    let quantity: Int
    let unit_price: Double
    let line_total: Double
    let products: EmbeddedProduct?

    struct EmbeddedProduct: Codable {
        let name: String?
        let sku: String?
    }

    var productName: String { products?.name ?? "Unknown Product" }
    var productSku: String { products?.sku ?? "—" }
}
