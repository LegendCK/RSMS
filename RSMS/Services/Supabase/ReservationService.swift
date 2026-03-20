//
//  ReservationService.swift
//  RSMS
//
//  Handles operations on the `reservations` table in Supabase.
//

import Foundation
import Supabase

@MainActor
final class ReservationService {
    static let shared = ReservationService()
    private let client = SupabaseManager.shared.client

    private init() {}

    /// Creates a new reservation
    func createReservation(_ payload: ReservationInsertDTO) async throws -> ReservationDTO {
        return try await client
            .from("reservations")
            .insert(payload)
            .select("*, products(*)") // Also expanding the product data to render in UI if needed
            .single()
            .execute()
            .value
    }
    
    /// Fetches all active reservations for a specific client
    func fetchMyReservations() async throws -> [ReservationDTO] {
        return try await client
            .from("reservations")
            .select("*, products(*)")
            .neq("status", value: "cancelled")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches reservations for a specific store (for managers/staff)
    func fetchStoreReservations(storeId: UUID) async throws -> [ReservationDTO] {
        return try await client
            .from("reservations")
            .select("*, products(*)")
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    /// Updates an existing reservation status (e.g., to cancel)
    func updateReservationStatus(id: UUID, status: String) async throws -> ReservationDTO {
        let payload = ReservationUpdateDTO(status: status)
        return try await client
            .from("reservations")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select("*, products(*)")
            .single()
            .execute()
            .value
    }
}
