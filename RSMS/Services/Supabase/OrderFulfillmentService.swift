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
    /// Tries the SECURITY DEFINER RPC first (bypasses RLS), falls back to direct query.
    func fetchOrderItems(orderId: UUID) async throws -> [OrderItemWithProduct] {
        struct RPCRow: Decodable {
            let id: UUID
            let order_id: UUID
            let product_id: UUID
            let quantity: Int
            let unit_price: Double
            let line_total: Double
            let product_name: String?
            let product_sku: String?
            let image_urls: [String]?
        }
        do {
            let params: [String: String] = ["p_order_id": orderId.uuidString.lowercased()]
            let rows: [RPCRow] = try await client
                .rpc("get_order_items_for_fulfillment", params: params)
                .execute()
                .value
            if !rows.isEmpty {
                return rows.map { row in
                    OrderItemWithProduct(
                        id: row.id,
                        order_id: row.order_id.uuidString.lowercased(),
                        product_id: row.product_id.uuidString.lowercased(),
                        quantity: row.quantity,
                        unit_price: row.unit_price,
                        line_total: row.line_total,
                        products: row.product_name != nil
                            ? .init(name: row.product_name, sku: row.product_sku, imageUrls: row.image_urls)
                            : nil
                    )
                }
            }
        } catch {
            print("[OrderFulfillmentService] RPC fetchOrderItems failed, trying direct: \(error.localizedDescription)")
        }
        // Fallback: direct query (blocked by RLS if policy not yet applied)
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

    // MARK: - Check Inventory Availability

    /// Returns availability info for each order item against the store's current stock.
    /// Used by the IC before confirming dispatch, to detect insufficient stock early.
    func checkInventoryAvailability(items: [OrderItemWithProduct], storeId: UUID) async throws -> [InventoryAvailability] {
        guard !items.isEmpty else { return [] }

        let productIds = items.compactMap { UUID(uuidString: $0.product_id) }

        struct InvRow: Decodable {
            let product_id: String
            let quantity: Int
        }

        let rows: [InvRow] = try await client
            .from("inventory")
            .select("product_id, quantity")
            .eq("store_id", value: storeId.uuidString.lowercased())
            .in("product_id", values: productIds.map { $0.uuidString.lowercased() })
            .execute()
            .value

        let availableByProductId = Dictionary(
            uniqueKeysWithValues: rows.compactMap { row -> (UUID, Int)? in
                guard let id = UUID(uuidString: row.product_id) else { return nil }
                return (id, row.quantity)
            }
        )

        return items.compactMap { item -> InventoryAvailability? in
            guard let productId = UUID(uuidString: item.product_id) else { return nil }
            return InventoryAvailability(
                productId: productId,
                productName: item.productName,
                required: item.quantity,
                available: availableByProductId[productId] ?? 0
            )
        }
    }

    // MARK: - Request Stock Replenishment

    /// Creates a pending stock-replenishment transfer record so managers can
    /// arrange incoming stock for this store. Non-fatal — always succeeds silently.
    func requestReplenishment(productId: UUID, storeId: UUID, quantity: Int, orderNumber: String) async {
        struct ReplenishInsert: Encodable {
            let id: String
            let transfer_number: String
            let product_id: String
            let quantity: Int
            let to_boutique_id: String
            let status: String
            let requested_at: String
            let updated_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        // Include order number in transfer ref so admin can trace it back
        let transferNum = "REP-\(orderNumber)-\(productId.uuidString.prefix(4).uppercased())"
        let insert = ReplenishInsert(
            id: UUID().uuidString.lowercased(),
            transfer_number: transferNum,
            product_id: productId.uuidString.lowercased(),
            quantity: quantity,
            to_boutique_id: storeId.uuidString.lowercased(),
            status: "pending_admin_approval",  // visible to corporate admin for approval
            requested_at: now,
            updated_at: now
        )
        do {
            try await client.from("transfers").insert(insert).execute()
            print("[OrderFulfillmentService] ✅ Replenishment request created: \(transferNum)")
        } catch {
            print("[OrderFulfillmentService] Replenishment insert failed (non-fatal): \(error.localizedDescription)")
        }
    }

    // MARK: - Auto-deliver stale shipped orders

    /// Finds "shipped" orders whose updated_at is > 24 hours ago and marks them
    /// as "delivered" in Supabase. This simulates last-mile delivery automatically.
    /// Called at the start of `fetchFulfillmentOrders` so the IC's list stays clean.
    func autoDeliverStaleOrders(storeId: UUID) async {
        let cutoff = Date().addingTimeInterval(-24 * 3_600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cutoffStr = formatter.string(from: cutoff)

        do {
            struct ShippedRow: Decodable { let id: UUID }
            let stale: [ShippedRow] = try await client
                .from("orders")
                .select("id")
                .eq("store_id", value: storeId.uuidString.lowercased())
                .eq("status", value: "shipped")
                .lte("updated_at", value: cutoffStr)
                .execute()
                .value

            for row in stale {
                try? await updateOrderStatus(orderId: row.id, newStatus: "delivered")
                print("[OrderFulfillmentService] ✅ Auto-delivered order \(row.id)")
            }
        } catch {
            print("[OrderFulfillmentService] Auto-delivery check failed (non-fatal): \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Pending Orders for Store

    /// Fetches all non-terminal orders for a store that need fulfillment.
    func fetchFulfillmentOrders(storeId: UUID) async throws -> [OrderDTO] {
        // Auto-deliver any shipped orders that are more than 24 h old
        await autoDeliverStaleOrders(storeId: storeId)

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

// MARK: - Inventory Availability

struct InventoryAvailability {
    let productId: UUID
    let productName: String
    let required: Int
    let available: Int
    var isSufficient: Bool { available >= required }
    var shortfall: Int { max(0, required - available) }
}
