//
//  OrderService.swift
//  RSMS
//
//  Persists customer orders and order_items to Supabase so sales associates
//  can view purchase history in the client dashboard.
//
//  Called from CheckoutView.placeOrder() immediately after the local SwiftData
//  save — if Supabase sync fails the local order still exists (graceful degradation).
//

import Foundation
import Supabase

enum OrderServiceError: LocalizedError {
    case noStoreAvailable
    case noClientId

    var errorDescription: String? {
        switch self {
        case .noStoreAvailable: return "No active store found. Order saved locally only."
        case .noClientId:       return "Client ID unavailable. Order saved locally only."
        }
    }
}

@MainActor
final class OrderService {
    static let shared = OrderService()
    private let client = SupabaseManager.shared.client

    /// Cached store ID — fetched once per session to avoid repeated queries.
    private var cachedDefaultStoreId: UUID? = nil

    private init() {}

    // MARK: - Sync order to Supabase

    /// Writes the order header + all line items to Supabase.
    /// Safe to call fire-and-forget; errors are logged but not thrown to caller.
    func syncOrder(
        clientId: UUID,
        cartItems: [(productId: UUID, productName: String, quantity: Int, unitPrice: Double)],
        orderNumber: String,
        subtotal: Double,
        taxTotal: Double,
        grandTotal: Double,
        channel: String      // "online" | "bopis" | "in_store" | "ship_from_store"
    ) async throws {
        // 1. Resolve a store UUID (required FK in orders table)
        let storeId = try await defaultStoreId()

        // 2. Insert order header
        let orderPayload = OrderInsertDTO(
            orderNumber: orderNumber,
            clientId: clientId,
            storeId: storeId,
            associateId: nil,
            channel: channel,
            status: "confirmed",
            subtotal: subtotal,
            taxTotal: taxTotal,
            grandTotal: grandTotal,
            currency: "USD",
            isTaxFree: false,
            notes: nil
        )

        let createdOrder: OrderDTO = try await client
            .from("orders")
            .insert(orderPayload)
            .select()
            .single()
            .execute()
            .value

        print("[OrderService] Order \(createdOrder.orderNumber ?? orderNumber) saved to Supabase (id: \(createdOrder.id))")

        // 3. Insert line items
        guard !cartItems.isEmpty else { return }

        let taxRate = grandTotal > 0 ? taxTotal / subtotal : 0.08
        let itemPayloads: [OrderItemInsertDTO] = cartItems.map { item in
            let lineTotal = item.unitPrice * Double(item.quantity)
            let itemTax   = lineTotal * taxRate
            return OrderItemInsertDTO(
                orderId: createdOrder.id,
                productId: item.productId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                taxAmount: itemTax,
                lineTotal: lineTotal
            )
        }

        try await client
            .from("order_items")
            .insert(itemPayloads)
            .execute()

        print("[OrderService] \(itemPayloads.count) order item(s) saved for order \(createdOrder.id)")
    }

    // MARK: - Store resolution

    /// Returns a valid store UUID. Caches the result for the session.
    private func defaultStoreId() async throws -> UUID {
        if let cached = cachedDefaultStoreId { return cached }

        let stores: [StoreDTO] = try await client
            .from("stores")
            .select()
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value

        guard let store = stores.first else {
            throw OrderServiceError.noStoreAvailable
        }

        cachedDefaultStoreId = store.id
        print("[OrderService] Using store: \(store.name) (\(store.id))")
        return store.id
    }
}
