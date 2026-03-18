//
//  AppointmentService.swift
//  RSMS
//
//  Handles operations on the `appointments` table.
//

import Foundation
import Supabase

@MainActor
final class AppointmentService {
    static let shared = AppointmentService()
    private let client = SupabaseManager.shared.client

    private init() {}

    /// Inserts a new appointment into Supabase.
    func createAppointment(_ payload: AppointmentInsertDTO) async throws -> AppointmentDTO {
        return try await client
            .from("appointments")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }
    /// Fetches all non-requested appointments assigned to a specific associate
    func fetchAppointments(forAssociateId associateId: UUID) async throws -> [AppointmentDTO] {
        return try await client
            .from("appointments")
            .select()
            .eq("associate_id", value: associateId.uuidString)
            .in("status", values: ["scheduled", "confirmed", "in_progress", "completed", "cancelled", "no_show"])
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }
    
    /// Fetches globally requested appointments that have not yet been assigned/accepted
    func fetchRequestedAppointments() async throws -> [AppointmentDTO] {
        return try await client
            .from("appointments")
            .select()
            .eq("status", value: "requested")
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }

    /// Fetches requested appointments for a specific store.
    func fetchRequestedAppointments(forStoreId storeId: UUID) async throws -> [AppointmentDTO] {
        return try await client
            .from("appointments")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .eq("status", value: "requested")
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }

    /// Fetches all appointments for a specific store.
    func fetchAppointments(forStoreId storeId: UUID) async throws -> [AppointmentDTO] {
        return try await client
            .from("appointments")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .in("status", values: ["requested", "scheduled", "confirmed", "in_progress", "completed", "cancelled", "no_show"])
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }
    
    /// Updates an existing appointment
    func updateAppointment(id: UUID, payload: AppointmentInsertDTO) async throws -> AppointmentDTO {
        return try await client
            .from("appointments")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}
