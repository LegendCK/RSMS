//
//  OrderStatusSyncService.swift
//  RSMS
//
//  Pulls order status updates from Supabase back into local SwiftData.
//  Called from OrdersListView (.task + .refreshable) and OrderDetailView.
//

import Foundation
import SwiftData
import Supabase

@MainActor
final class OrderStatusSyncService {
    static let shared = OrderStatusSyncService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Sync all orders for a customer

    /// Pulls customer orders from Supabase and upserts them into local SwiftData,
    /// then applies latest status updates.
    ///
    /// This fixes the case where local orders are empty (new install/device) but
    /// remote orders already exist.
    func syncOrderStatuses(customerEmail: String, clientId: UUID?, modelContext: ModelContext) async throws {
        let normalizedEmail = customerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Fetch local orders for this customer.
        let allLocal = try modelContext.fetch(FetchDescriptor<Order>())
        let localOrders = allLocal.filter {
            $0.customerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedEmail
        }

        // 2. Fetch remote orders.
        let remoteOrders: [RemoteOrderLite]
        if let clientId {
            let response = try await client
                .from("orders")
                .select("id, order_number, status, subtotal, tax_total, grand_total, channel, notes, store_id, created_at, updated_at")
                .eq("client_id", value: clientId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
            remoteOrders = try JSONDecoder().decode([RemoteOrderLite].self, from: response.data)
        } else {
            // Fallback: with no client UUID we can only sync statuses for known local orders.
            let orderNumbers = localOrders.map(\.orderNumber)
            guard !orderNumbers.isEmpty else { return }
            let response = try await client
                .from("orders")
                .select("id, order_number, status, subtotal, tax_total, grand_total, channel, notes, store_id, created_at, updated_at")
                .in("order_number", values: orderNumbers)
                .execute()
            remoteOrders = try JSONDecoder().decode([RemoteOrderLite].self, from: response.data)
        }

        // 3. Fetch remote order items for richer local history cards.
        let remoteOrderIds = remoteOrders.map(\.id)
        let itemsByOrderId = try await fetchOrderItems(orderIds: remoteOrderIds)

        // 4. Upsert local orders.
        var changed = 0
        for remote in remoteOrders {
            let status = mapSupabaseStatus(remote.status)
            let createdAt = parseSupabaseDate(remote.createdAt) ?? Date()
            let updatedAt = parseSupabaseDate(remote.updatedAt ?? "") ?? createdAt
            let itemsJSON = buildItemsJSON(from: itemsByOrderId[remote.id] ?? [])
            let fulfillment = mapChannel(remote.channel)

            if let local = localOrders.first(where: { $0.orderNumber == remote.orderNumber }) {
                if local.status != status { local.status = status; changed += 1 }
                if local.subtotal != remote.subtotal { local.subtotal = remote.subtotal; changed += 1 }
                if local.tax != remote.taxTotal { local.tax = remote.taxTotal; changed += 1 }
                if local.total != remote.grandTotal { local.total = remote.grandTotal; changed += 1 }
                if !itemsJSON.isEmpty, local.orderItems != itemsJSON { local.orderItems = itemsJSON; changed += 1 }
                if local.fulfillmentType != fulfillment { local.fulfillmentType = fulfillment; changed += 1 }
                if local.createdAt != createdAt { local.createdAt = createdAt; changed += 1 }
                local.updatedAt = updatedAt
            } else {
                let newOrder = Order(
                    orderNumber: remote.orderNumber,
                    customerEmail: normalizedEmail,
                    status: status,
                    orderItems: itemsJSON.isEmpty ? "[]" : itemsJSON,
                    subtotal: remote.subtotal,
                    tax: remote.taxTotal,
                    discount: 0,
                    total: remote.grandTotal,
                    shippingAddress: "{}",
                    fulfillmentType: fulfillment,
                    paymentMethod: "Card",
                    notes: remote.notes ?? "",
                    boutiqueId: remote.storeId?.uuidString ?? ""
                )
                newOrder.createdAt = createdAt
                newOrder.updatedAt = updatedAt
                modelContext.insert(newOrder)
                changed += 1
            }
        }

        if changed > 0 {
            try modelContext.save()
            print("[OrderStatusSyncService] Upserted/updated \(changed) local order field changes from Supabase")
        }
    }

    // MARK: - Sync single order

    /// Fetches the latest status for a single order from Supabase.
    func syncSingleOrder(_ order: Order, modelContext: ModelContext) async throws {
        let response = try await client
            .from("orders")
            .select("order_number, status, updated_at")
            .eq("order_number", value: order.orderNumber)
            .limit(1)
            .execute()

        let remoteOrders = try JSONDecoder().decode([RemoteOrderStatus].self, from: response.data)

        guard let remote = remoteOrders.first else {
            print("[OrderStatusSyncService] Order \(order.orderNumber) not found in Supabase")
            return
        }

        let newStatus = mapSupabaseStatus(remote.status)
        if order.status != newStatus {
            order.status = newStatus
            order.updatedAt = parseSupabaseDate(remote.updated_at ?? "") ?? Date()
            try modelContext.save()
            print("[OrderStatusSyncService] Order \(order.orderNumber) updated to: \(newStatus.rawValue)")
        }
    }

    // MARK: - Status Mapping

    private func mapSupabaseStatus(_ raw: String) -> OrderStatus {
        switch OrderStatusMapper.canonical(raw) {
        case "pending":           return .pending
        case "confirmed":         return .confirmed
        case "processing":        return .processing
        case "shipped":           return .shipped
        case "delivered":         return .delivered
        case "ready_for_pickup":  return .readyForPickup
        case "completed":         return .completed
        case "cancelled":         return .cancelled
        default:                  return .confirmed
        }
    }
}

// MARK: - Codable for Supabase response

private struct RemoteOrderStatus: Codable {
    let order_number: String
    let status: String
    let updated_at: String?
}

private struct RemoteOrderLite: Codable {
    let id: UUID
    let orderNumber: String
    let status: String
    let subtotal: Double
    let taxTotal: Double
    let grandTotal: Double
    let channel: String
    let notes: String?
    let storeId: UUID?
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, subtotal, channel, notes
        case orderNumber = "order_number"
        case taxTotal = "tax_total"
        case grandTotal = "grand_total"
        case storeId = "store_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct RemoteOrderItemWithProduct: Codable {
    let orderId: UUID
    let quantity: Int
    let unitPrice: Double
    let products: RemoteProductLite?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case quantity
        case unitPrice = "unit_price"
        case products
    }
}

private struct RemoteProductLite: Codable {
    let name: String?
    let brand: String?
    let imageUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case name, brand
        case imageUrls = "image_urls"
    }
}

private extension OrderStatusSyncService {
    func fetchOrderItems(orderIds: [UUID]) async throws -> [UUID: [RemoteOrderItemWithProduct]] {
        guard !orderIds.isEmpty else { return [:] }

        let response = try await client
            .from("order_items")
            .select("order_id, quantity, unit_price, products(name,brand,image_urls)")
            .in("order_id", values: orderIds.map { $0.uuidString.lowercased() })
            .execute()

        let rows = try JSONDecoder().decode([RemoteOrderItemWithProduct].self, from: response.data)
        return Dictionary(grouping: rows, by: \.orderId)
    }

    func buildItemsJSON(from items: [RemoteOrderItemWithProduct]) -> String {
        let payload: [[String: Any]] = items.map { item in
            [
                "name": item.products?.name ?? "Product",
                "brand": item.products?.brand ?? "Maison Luxe",
                "qty": item.quantity,
                "price": item.unitPrice,
                "image": item.products?.imageUrls?.first ?? "bag.fill"
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    func mapChannel(_ channel: String) -> FulfillmentType {
        switch channel.lowercased() {
        case "bopis":
            return .bopis
        case "ship_from_store":
            return .shipFromStore
        case "in_store":
            return .inStore
        default:
            return .standard
        }
    }

    /// Parses Supabase ISO 8601 timestamps, handling fractional seconds
    /// (e.g. "2026-03-15T08:30:00.123456+00:00") which the default
    /// ISO8601DateFormatter fails to parse.
    func parseSupabaseDate(_ raw: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: raw) { return date }
        return ISO8601DateFormatter().date(from: raw)
    }
}
