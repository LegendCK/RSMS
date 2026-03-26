//
//  OrderFulfillmentService.swift
//  RSMS
//
//  Handles the backend operations for order fulfillment by Inventory Controllers:
//  - Updating order status via server-side state machine (transition_order_status RPC)
//  - Atomically decrementing inventory (decrement_order_inventory RPC)
//  - Fetching order items for picking/packing
//
//  All status transitions go through the transition_order_status() SECURITY DEFINER
//  function on the server, which validates allowed transitions, enforces store
//  ownership, and writes an order_events audit row — all in one transaction.
//

import Foundation
import Supabase

// MARK: - RPC Param structs (file-level so they are not @MainActor-isolated)

nonisolated private struct TransitionParamsWithActor: Encodable, Sendable {
    let p_order_id:   String
    let p_new_status: String
    let p_actor_id:   String?
    let p_notes:      String?
}

nonisolated private struct DecrementParams: Encodable, Sendable {
    let p_product_id: String
    let p_store_id:   String
    let p_quantity:   Int
}

nonisolated private struct AutoDeliverParams: Encodable, Sendable {
    let p_store_id:    String
    let p_hours_stale: Int
}

enum OrderFulfillmentError: LocalizedError {
    case invalidTransition(from: String, to: String)
    case statusUpdateFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let to):
            return "Cannot move order from '\(from)' to '\(to)'. Invalid transition."
        case .statusUpdateFailed(let msg):
            return "Order status update failed: \(msg)"
        }
    }
}

@MainActor
final class OrderFulfillmentService {
    static let shared = OrderFulfillmentService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Update Order Status (server-side state machine)

    /// Transitions an order to a new status via the transition_order_status()
    /// SECURITY DEFINER RPC. The server validates the transition, enforces store
    /// ownership, and writes an audit event atomically.
    func updateOrderStatus(orderId: UUID, newStatus: String, notes: String? = nil) async throws {
        let canonical = OrderStatusMapper.canonical(newStatus)

        // Get actor ID for the audit trail (best-effort — transition still proceeds if unavailable)
        var actorIdParam: String? = nil
        if let session = try? await client.auth.session {
            actorIdParam = session.user.id.uuidString.lowercased()
        }

        let params = TransitionParamsWithActor(
            p_order_id:   orderId.uuidString.lowercased(),
            p_new_status: canonical,
            p_actor_id:   actorIdParam,
            p_notes:      notes
        )

        do {
            try await client
                .rpc("transition_order_status", params: params)
                .execute()
            print("[OrderFulfillmentService] ✅ Order \(orderId) → \(canonical)")
        } catch {
            // Surface clear message: the server will throw on invalid transitions
            print("[OrderFulfillmentService] transition_order_status failed: \(error.localizedDescription)")
            throw OrderFulfillmentError.statusUpdateFailed(error.localizedDescription)
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

    // MARK: - Decrement Supabase Inventory (atomic)

    /// Atomically reduces inventory for a product at a store using a SECURITY DEFINER RPC.
    /// The server performs UPDATE quantity = GREATEST(0, quantity - n) in a single statement,
    /// eliminating the read-then-write race condition of the old implementation.
    func decrementInventory(productId: UUID, storeId: UUID, quantity: Int) async throws {
        let params = DecrementParams(
            p_product_id: productId.uuidString.lowercased(),
            p_store_id:   storeId.uuidString.lowercased(),
            p_quantity:   quantity
        )

        do {
            try await client
                .rpc("decrement_order_inventory", params: params)
                .execute()
            print("[OrderFulfillmentService] ✅ Inventory decremented: product \(productId) −\(quantity) at store \(storeId)")
        } catch {
            // Non-fatal: missing inventory row is handled server-side with a WARNING.
            // We log and continue so fulfillment is never blocked by a missing row.
            print("[OrderFulfillmentService] decrement_order_inventory warning (non-fatal): \(error.localizedDescription)")
        }
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
            .eq("location_id", value: storeId.uuidString.lowercased())
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

    // MARK: - Auto-deliver stale shipped orders (server-side)

    /// Delegates to the auto_deliver_stale_orders() SECURITY DEFINER RPC which
    /// handles its own locking, state machine transitions, and audit events.
    /// Called at the start of fetchFulfillmentOrders so the IC's list stays clean.
    func autoDeliverStaleOrders(storeId: UUID) async {
        let params = AutoDeliverParams(
            p_store_id:    storeId.uuidString.lowercased(),
            p_hours_stale: 24
        )

        struct CountResult: Decodable { let count: Int? }
        let result: CountResult? = try? await client
            .rpc("auto_deliver_stale_orders", params: params)
            .execute()
            .value
        let delivered = result?.count ?? 0
        if delivered > 0 {
            print("[OrderFulfillmentService] ✅ Auto-delivered \(delivered) stale order(s) for store \(storeId)")
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

    // MARK: - Fetch Audit Trail

    /// Fetches all order_events for a given order, sorted oldest first.
    /// Used by the IC detail view to show the full status history.
    func fetchOrderEvents(orderId: UUID) async throws -> [OrderEventDTO] {
        let events: [OrderEventDTO] = try await client
            .from("order_events")
            .select()
            .eq("order_id", value: orderId.uuidString.lowercased())
            .order("created_at", ascending: true)
            .execute()
            .value
        return events
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
