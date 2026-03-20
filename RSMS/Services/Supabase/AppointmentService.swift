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
            .is("associate_id", value: nil)
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
            .is("associate_id", value: nil)
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

    /// Cancels an appointment by setting its status to "cancelled".
    func cancelAppointment(_ appointment: AppointmentDTO) async throws -> AppointmentDTO {
        let payload = AppointmentInsertDTO(
            clientId: appointment.clientId,
            storeId: appointment.storeId,
            associateId: appointment.associateId,
            type: appointment.type,
            status: "cancelled",
            scheduledAt: appointment.scheduledAt,
            durationMinutes: appointment.durationMinutes,
            notes: appointment.notes,
            videoLink: appointment.videoLink
        )
        return try await updateAppointment(id: appointment.id, payload: payload)
    }

    /// Submits a reschedule request: sets status back to "requested", clears the associate,
    /// and updates scheduledAt to the customer's preferred new time.
    func requestReschedule(_ appointment: AppointmentDTO, newDate: Date) async throws -> AppointmentDTO {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let originalStr = formatter.string(from: appointment.scheduledAt)
        let rescheduleNote = "Reschedule requested (original: \(originalStr))"
        let combinedNotes = [appointment.notes?.isEmpty == false ? appointment.notes : nil, rescheduleNote]
            .compactMap { $0 }
            .joined(separator: "\n")
        let payload = AppointmentInsertDTO(
            clientId: appointment.clientId,
            storeId: appointment.storeId,
            associateId: nil,
            type: appointment.type,
            status: "requested",
            scheduledAt: newDate,
            durationMinutes: appointment.durationMinutes,
            notes: combinedNotes,
            videoLink: appointment.videoLink
        )
        return try await updateAppointment(id: appointment.id, payload: payload)
    }
}
