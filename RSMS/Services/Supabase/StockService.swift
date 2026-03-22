//
//  StockService.swift
//  RSMS
//
//  Supabase operations for creating serialized product_items (Stock In flow).
//  Calls the `create_product_items_bulk` PostgreSQL RPC function which performs
//  a single INSERT … SELECT generate_series() for the requested quantity.
//
//  Does NOT touch ScanManager, ScanService, or any scanning pipeline.
//

import Foundation
import Supabase

// MARK: - Protocol

protocol StockServiceProtocol: Sendable {
    /// Creates `quantity` product_items rows for the given product, each with a
    /// unique RSMS-prefixed barcode generated server-side.
    /// Returns the newly created items (including their barcodes) for display.
    func createStock(productId: UUID, quantity: Int) async throws -> [ProductItemDTO]

    /// Fetches all product_items for a product, ordered newest-first.
    func fetchItems(for productId: UUID) async throws -> [ProductItemDTO]
}

// MARK: - Supabase Implementation

final class StockService: StockServiceProtocol, @unchecked Sendable {
    static let shared = StockService()

    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Bulk Stock Creation

    /// Calls the `create_product_items_bulk(p_product_id, p_quantity)` SQL function.
    /// The function uses generate_series() so only ONE database round-trip is made
    /// regardless of quantity.
    nonisolated func createStock(productId: UUID, quantity: Int) async throws -> [ProductItemDTO] {
        guard quantity > 0 && quantity <= 500 else {
            throw StockError.invalidQuantity(quantity)
        }

        // RPC returns SETOF product_items — no joined product here (keep it simple)
        let items: [ProductItemDTO] = try await client
            .rpc("create_product_items_bulk",
                 params: [
                    "p_product_id": .string(productId.uuidString),
                    "p_quantity": .integer(quantity)
                 ] as AnyJSON)
            .execute()
            .value

        return items
    }

    // MARK: - Fetch Items for Product

    /// Fetches existing product_items for a product with their joined product data.
    nonisolated func fetchItems(for productId: UUID) async throws -> [ProductItemDTO] {
        let items: [ProductItemDTO] = try await client
            .from("product_items")
            .select("*, products(*)")
            .eq("product_id", value: productId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return items
    }
}

// MARK: - Errors

enum StockError: LocalizedError {
    case invalidQuantity(Int)
    case creationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuantity(let q):
            return q <= 0
                ? "Quantity must be at least 1."
                : "Quantity cannot exceed 500 items per operation."
        case .creationFailed(let detail):
            return "Stock creation failed: \(detail)"
        }
    }
}
