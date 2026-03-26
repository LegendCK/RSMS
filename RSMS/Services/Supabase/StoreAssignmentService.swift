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

    func findNearestStore(city: String, state: String) async throws -> UUID? {
        let stores: [StoreDTO] = try await client
            .from("stores")
            .select("id, name")
            .eq("is_active", value: true)
            .execute()
            .value

        guard !stores.isEmpty else { return nil }

        let cityNorm  = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let stateNorm = state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. City match via name (case-insensitive)
        if !cityNorm.isEmpty,
           let match = stores.first(where: { $0.name.lowercased().contains(cityNorm) }) {
            print("[StoreAssignment] City match: \(match.name) for city '\(city)'")
            return match.id
        }

        // 2. Region / state match via name
        if !stateNorm.isEmpty {
            let match = stores.first(where: {
                let name = $0.name.lowercased()
                return name.contains(stateNorm) || stateNorm.contains(name)
            })
            if let match {
                print("[StoreAssignment] Region match: \(match.name) for state '\(state)'")
                return match.id
            }
        }

        // 3. Fallback: any active store
        print("[StoreAssignment] Fallback to first active store: \(stores[0].name)")
        return stores.first?.id
    }
}
