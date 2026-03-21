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

enum OrderFulfillmentError: LocalizedError {
    case statusUpdateRejected(attempted: [String], underlying: Error)

    var errorDescription: String? {
        switch self {
        case .statusUpdateRejected(let attempted, let underlying):
            let attempts = attempted.joined(separator: ", ")
            return "Status update rejected. Tried: \(attempts). Backend error: \(underlying.localizedDescription)"
        }
    }
}

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
        let candidates = Array(NSOrderedSet(array: OrderStatusMapper.writeCandidates(for: newStatus)).compactMap { $0 as? String })
        var lastError: Error?
        var attempted: [String] = []

        for candidate in candidates {
            attempted.append(candidate)
            do {
                try await client
                    .from("orders")
                    .update(StatusUpdate(status: candidate, updated_at: now))
                    .eq("id", value: orderId.uuidString.lowercased())
                    .execute()

                print("[OrderFulfillmentService] ✅ Order \(orderId) → \(candidate)")
                return
            } catch {
                lastError = error
                print("[OrderFulfillmentService] Status candidate rejected for \(orderId): \(candidate) — \(error.localizedDescription)")
            }
        }

        if let lastError {
            throw OrderFulfillmentError.statusUpdateRejected(attempted: attempted, underlying: lastError)
        }
    }

    // MARK: - Fetch Order Items

    /// Fetches line items for a specific order so the IC can see what to pick/pack.
    func fetchOrderItems(orderId: UUID) async throws -> [OrderItemWithProduct] {
        let response = try await client
            .from("order_items")
            .select("id, order_id, product_id, quantity, unit_price, line_total, products(name, sku, image_urls)")
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
        var orders: [OrderDTO] = try await client
            .from("orders")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .not("status", operator: .in, value: "(completed,cancelled,delivered)")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value

        let orderIds = orders.map(\.id)
        let clientIds = Set(orders.compactMap(\.clientId))

        let itemSummaryByOrderId = try await fetchItemSummaries(orderIds: orderIds)
        let clientById = try await fetchClientsById(ids: Array(clientIds))

        for index in orders.indices {
            let orderId = orders[index].id
            let summary = itemSummaryByOrderId[orderId]
            orders[index].itemCount = summary?.itemCount ?? 0
            orders[index].totalQuantity = summary?.totalQuantity ?? 0

            guard let clientId = orders[index].clientId,
                  let client = clientById[clientId] else {
                continue
            }

            let fullName = [client.firstName, client.lastName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            orders[index].customerName = fullName.isEmpty ? "Guest Customer" : fullName
            orders[index].customerEmail = client.email
        }

        return orders
    }
}

private extension OrderFulfillmentService {
    func fetchClientsById(ids: [UUID]) async throws -> [UUID: ClientLiteRow] {
        guard !ids.isEmpty else { return [:] }

        let response = try await client
            .from("clients")
            .select("id, first_name, last_name, email")
            .in("id", values: ids.map { $0.uuidString.lowercased() })
            .execute()

        let rows = try JSONDecoder().decode([ClientLiteRow].self, from: response.data)
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    }

    func fetchItemSummaries(orderIds: [UUID]) async throws -> [UUID: OrderItemSummary] {
        guard !orderIds.isEmpty else { return [:] }

        let response = try await client
            .from("order_items")
            .select("order_id, quantity")
            .in("order_id", values: orderIds.map { $0.uuidString.lowercased() })
            .execute()

        let rows = try JSONDecoder().decode([OrderItemQtyRow].self, from: response.data)
        var summaryByOrderId: [UUID: OrderItemSummary] = [:]

        for row in rows {
            let existing = summaryByOrderId[row.orderId] ?? OrderItemSummary(itemCount: 0, totalQuantity: 0)
            summaryByOrderId[row.orderId] = OrderItemSummary(
                itemCount: existing.itemCount + 1,
                totalQuantity: existing.totalQuantity + row.quantity
            )
        }

        return summaryByOrderId
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
        let imageUrls: [String]?

        enum CodingKeys: String, CodingKey {
            case name
            case sku
            case imageUrls = "image_urls"
        }
    }

    var productName: String { products?.name ?? "Unknown Product" }
    var productSku: String { products?.sku ?? "—" }
    var productPrimaryImage: String? { products?.imageUrls?.first }
}

private struct ClientLiteRow: Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }
}

private struct OrderItemQtyRow: Codable {
    let orderId: UUID
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case quantity
    }
}

private struct OrderItemSummary {
    let itemCount: Int
    let totalQuantity: Int
}
