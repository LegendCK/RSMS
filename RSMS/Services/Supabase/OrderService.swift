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

    struct PaymentSplitInput {
        let method: String
        let amount: Double
        let paymentReference: String?
        let status: String

        init(
            method: String,
            amount: Double,
            paymentReference: String? = nil,
            status: String = "completed"
        ) {
            self.method = method
            self.amount = amount
            self.paymentReference = paymentReference
            self.status = status
        }
    }

    struct SyncOrderResult {
        let orderId: UUID?
        let orderNumber: String?
        let itemsInserted: Int
        let storeId: UUID?
        let replenishmentsRequested: Int
    }

    // MARK: - Sync order to Supabase via Edge Function

    /// Sends the order to the `create-order` Edge Function which uses the service role
    /// key to insert into `orders` and `order_items`, bypassing RLS safely.
    @discardableResult
    func syncOrder(
        clientId: UUID?,
        cartItems: [(productId: UUID, productName: String, quantity: Int, unitPrice: Double)],
        orderNumber: String,
        subtotal: Double,
        discountTotal: Double,
        taxTotal: Double,
        grandTotal: Double,
        channel: String,           // "online" | "bopis" | "in_store" | "ship_from_store"
        storeId: UUID? = nil,      // Nearest store for online orders; nil = edge function default
        isTaxFree: Bool = false,
        taxFreeReason: String = "",
        notes: String? = nil,
        deliveryCity: String? = nil,
        deliveryState: String? = nil,
        paymentSplits: [PaymentSplitInput]? = nil
    ) async throws -> SyncOrderResult {

        struct CartItemPayload: Encodable {
            let productId: String
            let productName: String
            let quantity: Int
            let unitPrice: Double
        }

        struct CreateOrderPayload: Encodable {
            struct PaymentSplitPayload: Encodable {
                let method: String
                let amount: Double
                let paymentReference: String?
                let status: String
            }

            let clientId: String?  // explicit client UUID; nil for walk-in POS sales
            let orderNumber: String
            let cartItems: [CartItemPayload]
            let subtotal: Double
            let discountTotal: Double
            let taxTotal: Double
            let grandTotal: Double
            let channel: String
            let currency: String
            let storeId: String?   // nearest store UUID — edge function uses this if present
            let isTaxFree: Bool
            let taxFreeReason: String
            let notes: String?
            let deliveryCity: String?
            let deliveryState: String?
            let paymentSplits: [PaymentSplitPayload]?
        }

        struct EdgeResponse: Decodable {
            let success: Bool?
            let orderId: String?
            let orderNumber: String?
            let storeId: String?
            let itemsInserted: Int?
            let error: String?
            let replenishmentsRequested: Int?
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
            clientId: clientId?.uuidString.lowercased(),
            orderNumber: orderNumber,
            cartItems: items,
            subtotal: subtotal,
            discountTotal: discountTotal,
            taxTotal: taxTotal,
            grandTotal: grandTotal,
            channel: channel,
            currency: "INR",
            storeId: storeId?.uuidString.lowercased(),
            isTaxFree: isTaxFree,
            taxFreeReason: taxFreeReason,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
                ? nil
                : notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            deliveryCity: deliveryCity?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
                ? nil
                : deliveryCity?.trimmingCharacters(in: .whitespacesAndNewlines),
            deliveryState: deliveryState?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
                ? nil
                : deliveryState?.trimmingCharacters(in: .whitespacesAndNewlines),
            paymentSplits: paymentSplits?.map {
                CreateOrderPayload.PaymentSplitPayload(
                    method: $0.method,
                    amount: $0.amount,
                    paymentReference: $0.paymentReference,
                    status: $0.status
                )
            }
        )

        print("[OrderService] Calling create-order edge function for order: \(orderNumber)")

        // Fetch the session token explicitly — the FunctionsClient's internal
        // auth-header injection can silently fall back to the anon key when the
        // session storage lookup runs in a non-isolated async context.
        let accessToken = try await client.auth.session.accessToken

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

        guard response.success == true else {
            throw OrderServiceError.edgeFunctionError("Order sync returned unsuccessful response")
        }

        let orderId = response.orderId ?? "unknown"
        let itemCount = response.itemsInserted ?? 0
        print("[OrderService] ✅ Order \(orderNumber) saved to Supabase — id: \(orderId), items: \(itemCount), status: completed")
        // Store routing is handled entirely server-side (city → state → fallback).
        // The edge function always sets store_id; no client-side patch needed.

        return SyncOrderResult(
            orderId: response.orderId.flatMap(UUID.init(uuidString:)),
            orderNumber: response.orderNumber,
            itemsInserted: itemCount,
            storeId: response.storeId.flatMap(UUID.init(uuidString:)),
            replenishmentsRequested: response.replenishmentsRequested ?? 0
        )
    }
}
