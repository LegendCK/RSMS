//
//  OrderService.swift
//  RSMS
//
//  Persists customer orders to Supabase via the `create-order` Edge Function.
//  The Edge Function runs with the service role key, bypassing RLS on orders/order_items.
//  The caller's JWT is still validated server-side — only authenticated users can place orders.
//
//  Called from CheckoutView.placeOrder() immediately after the local SwiftData save.
//  If Supabase sync fails the local order still exists (graceful degradation).
//

import Foundation
import Supabase

enum OrderServiceError: LocalizedError {
    case noStoreAvailable
    case noClientId
    case edgeFunctionError(String)

    var errorDescription: String? {
        switch self {
        case .noStoreAvailable:          return "No active store found. Order saved locally only."
        case .noClientId:                return "Client ID unavailable. Order saved locally only."
        case .edgeFunctionError(let msg): return "Order sync failed: \(msg)"
        }
    }
}

@MainActor
final class OrderService {
    static let shared = OrderService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Sync order to Supabase via Edge Function

    /// Sends the order to the `create-order` Edge Function which uses the service role
    /// key to insert into `orders` and `order_items`, bypassing RLS safely.
    func syncOrder(
        clientId: UUID,
        cartItems: [(productId: UUID, productName: String, quantity: Int, unitPrice: Double)],
        orderNumber: String,
        subtotal: Double,
        taxTotal: Double,
        grandTotal: Double,
        channel: String      // "online" | "bopis" | "in_store" | "ship_from_store"
    ) async throws {

        struct CartItemPayload: Encodable {
            let productId: String
            let productName: String
            let quantity: Int
            let unitPrice: Double
        }

        struct CreateOrderPayload: Encodable {
            let orderNumber: String
            let cartItems: [CartItemPayload]
            let subtotal: Double
            let taxTotal: Double
            let grandTotal: Double
            let channel: String
            let currency: String
        }

        struct EdgeResponse: Decodable {
            let success: Bool?
            let orderId: String?
            let orderNumber: String?
            let itemsInserted: Int?
            let error: String?
        }

        let items = cartItems.map {
            CartItemPayload(
                productId: $0.productId.uuidString,
                productName: $0.productName,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }

        let payload = CreateOrderPayload(
            orderNumber: orderNumber,
            cartItems: items,
            subtotal: subtotal,
            taxTotal: taxTotal,
            grandTotal: grandTotal,
            channel: channel,
            currency: "USD"
        )

        print("[OrderService] Calling create-order edge function for order: \(orderNumber)")

        // Explicitly fetch the current session token and attach it as the Authorization header.
        // The Supabase Swift SDK does not always forward the bearer token automatically
        // when invoking Edge Functions, causing a 401 at the gateway.
        let accessToken: String
        do {
            let session = try await client.auth.session
            accessToken = session.accessToken
        } catch {
            throw OrderServiceError.edgeFunctionError("No active session — cannot authenticate with edge function: \(error.localizedDescription)")
        }

        let response: EdgeResponse = try await client.functions.invoke(
            "create-order",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: payload
            )
        )

        if let errorMsg = response.error {
            print("[OrderService] Edge function returned error: \(errorMsg)")
            throw OrderServiceError.edgeFunctionError(errorMsg)
        }

        let orderId = response.orderId ?? "unknown"
        let itemCount = response.itemsInserted ?? 0
        print("[OrderService] ✅ Order \(orderNumber) saved to Supabase (id: \(orderId), items: \(itemCount))")
    }
}
