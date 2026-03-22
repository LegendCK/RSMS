//
//  StoreAssignmentService.swift
//  RSMS
//
//  Assigns online delivery orders to the nearest active store.
//  Priority: exact city match → region/state match → first active store (fallback).
//

import Foundation
import Supabase

final class StoreAssignmentService {
    static let shared = StoreAssignmentService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Find Nearest Store

    /// Returns the UUID of the store nearest to the delivery address.
    /// Used when a customer places an online delivery order so the order
    /// is immediately routed to the right boutique for IC fulfilment.
    ///
    /// - Parameters:
    ///   - city:  Customer delivery city (from their shipping address)
    ///   - state: Customer delivery state/region
    /// - Returns: UUID of the matched store, or `nil` if no stores exist.
    func findNearestStore(city: String, state: String) async throws -> UUID? {
        let stores: [StoreDTO] = try await client
            .from("stores")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value

        guard !stores.isEmpty else { return nil }

        let cityNorm  = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let stateNorm = state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Exact city match (case-insensitive)
        if !cityNorm.isEmpty,
           let match = stores.first(where: { ($0.city ?? "").lowercased() == cityNorm }) {
            print("[StoreAssignment] City match: \(match.name) for city '\(city)'")
            return match.id
        }

        // 2. Region / state match — partial overlap is enough
        if !stateNorm.isEmpty {
            let match = stores.first(where: {
                let region = ($0.region ?? "").lowercased()
                return !region.isEmpty && (region.contains(stateNorm) || stateNorm.contains(region))
            })
            if let match {
                print("[StoreAssignment] Region match: \(match.name) for state '\(state)'")
                return match.id
            }
        }

        // 3. Fallback: any active store (ensures order always has a store_id)
        print("[StoreAssignment] Fallback to first active store: \(stores[0].name)")
        return stores.first?.id
    }
}
