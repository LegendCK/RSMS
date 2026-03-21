//
//  ManagerInsightsService.swift
//  RSMS
//
//  Fetches order-item level data for the Manager Insights tab
//  (product mix, top-sellers by item quantity).
//  Scoped to a single store via the `orders` join.
//  Results are cached in UserDefaults for offline access.
//

import Foundation
import Supabase

// MARK: - Product Sales Summary

struct ProductSalesSummary: Identifiable {
    let id: UUID           // product_id
    let name: String
    let categoryName: String
    let unitsSold: Int
    let revenue: Double
}

// MARK: - Insights Snapshot

struct ManagerInsightsSnapshot: Codable {
    let storeId: UUID
    let syncedAt: Date
    /// Raw order-item rows joined with their order's store_id / created_at
    let orderItems: [InsightOrderItem]
}

struct InsightOrderItem: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let productId: UUID
    let quantity: Int
    let lineTotal: Double
    let orderCreatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId        = "order_id"
        case productId      = "product_id"
        case quantity
        case lineTotal      = "line_total"
        case orderCreatedAt = "order_created_at"
    }
}

// MARK: - Service

@MainActor
final class ManagerInsightsService {
    static let shared = ManagerInsightsService()

    private let client  = SupabaseManager.shared.client
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Cache

    func cachedSnapshot(for storeId: UUID) -> ManagerInsightsSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: storeId)) else { return nil }
        return try? decoder.decode(ManagerInsightsSnapshot.self, from: data)
    }

    private func persist(_ snapshot: ManagerInsightsSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: snapshot.storeId))
    }

    private func cacheKey(for storeId: UUID) -> String {
        "manager.insights.snapshot.\(storeId.uuidString.lowercased())"
    }

    // MARK: - Fetch

    /// Fetches all order_items for orders belonging to `storeId`.
    /// The query embeds a foreign-key join:
    ///   order_items → orders (id = order_id) filtered by store_id.
    func refreshSnapshot(for storeId: UUID) async throws -> ManagerInsightsSnapshot {
        // 1. Fetch all orders for this store (non-cancelled)
        let orders: [OrderDTO] = try await client
            .from("orders")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .neq("status", value: "cancelled")
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !orders.isEmpty else {
            let snapshot = ManagerInsightsSnapshot(storeId: storeId, syncedAt: Date(), orderItems: [])
            persist(snapshot)
            return snapshot
        }

        // 2. Fetch order_items for those orders
        let orderIds = orders.map { $0.id.uuidString.lowercased() }
        let rawItems: [OrderItemDTO] = try await client
            .from("order_items")
            .select()
            .in("order_id", values: orderIds)
            .execute()
            .value

        // 3. Build an id→createdAt lookup from orders
        let orderDateLookup: [UUID: Date] = Dictionary(
            uniqueKeysWithValues: orders.map { ($0.id, $0.createdAt) }
        )

        // 4. Map to InsightOrderItem (include order date for time-range filtering)
        let items: [InsightOrderItem] = rawItems.compactMap { item in
            guard let orderDate = orderDateLookup[item.orderId] else { return nil }
            return InsightOrderItem(
                id: item.id,
                orderId: item.orderId,
                productId: item.productId,
                quantity: item.quantity,
                lineTotal: item.lineTotal,
                orderCreatedAt: orderDate
            )
        }

        let snapshot = ManagerInsightsSnapshot(storeId: storeId, syncedAt: Date(), orderItems: items)
        persist(snapshot)
        return snapshot
    }
}
