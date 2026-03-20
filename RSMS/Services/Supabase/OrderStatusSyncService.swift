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

    /// Fetches all orders for the given customer email from Supabase and updates
    /// their local SwiftData status, so the customer sees live status changes
    /// made by managers / inventory controllers.
    func syncOrderStatuses(customerEmail: String, modelContext: ModelContext) async throws {
        // 1. Fetch local orders for this customer
        let email = customerEmail
        let descriptor = FetchDescriptor<Order>(
            predicate: #Predicate<Order> { $0.customerEmail == email }
        )
        let localOrders = try modelContext.fetch(descriptor)
        guard !localOrders.isEmpty else { return }

        // 2. Fetch matching orders from Supabase by order numbers
        let orderNumbers = localOrders.map { $0.orderNumber }

        // Supabase doesn't support `in` with the Swift client easily,
        // so we fetch all orders for this client and match locally.
        // Use the client_id approach if available, otherwise fall back to order numbers.
        let response = try await client
            .from("orders")
            .select("order_number, status, updated_at")
            .in("order_number", values: orderNumbers)
            .execute()

        let remoteOrders = try JSONDecoder().decode([RemoteOrderStatus].self, from: response.data)

        // 3. Update local orders with remote status
        var updatedCount = 0
        for remote in remoteOrders {
            guard let localOrder = localOrders.first(where: { $0.orderNumber == remote.order_number }) else { continue }

            let newStatus = mapSupabaseStatus(remote.status)
            if localOrder.status != newStatus {
                localOrder.status = newStatus
                localOrder.updatedAt = ISO8601DateFormatter().date(from: remote.updated_at ?? "") ?? Date()
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            try modelContext.save()
            print("[OrderStatusSyncService] Updated \(updatedCount) order(s) with new status")
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
            order.updatedAt = ISO8601DateFormatter().date(from: remote.updated_at ?? "") ?? Date()
            try modelContext.save()
            print("[OrderStatusSyncService] Order \(order.orderNumber) updated to: \(newStatus.rawValue)")
        }
    }

    // MARK: - Status Mapping

    private func mapSupabaseStatus(_ raw: String) -> OrderStatus {
        switch raw.lowercased() {
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
