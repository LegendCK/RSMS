//
//  SalesAppointmentsViewModel.swift
//  RSMS
//
//  Manages loading appointments for the Schedule tab.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SalesAppointmentsViewModel {
    
    var appointments: [AppointmentDTO] = []
    var requestedAppointments: [AppointmentDTO] = []
    var clientsById: [UUID: ClientDTO] = [:]
    
    var isLoading = false
    var showError = false
    var errorMessage = ""
    var showRequestAlert = false
    var requestAlertMessage = ""
    private var lastRequestedIds: Set<UUID> = []
    
    var todayAppointments: [AppointmentDTO] {
        let calendar = Calendar.current
        return appointments
            .filter { calendar.isDateInToday($0.scheduledAt) }
            .filter { Self.isUpcomingStatus($0.status) || $0.status == "in_progress" }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }
    
    var upcomingAppointments: [AppointmentDTO] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            return appointments
                .filter { $0.scheduledAt >= tomorrow }
                .filter { Self.isUpcomingStatus($0.status) }
                .sorted { $0.scheduledAt < $1.scheduledAt }
        }
        return []
    }
    
    var pastAppointments: [AppointmentDTO] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return appointments
            .filter { $0.scheduledAt < today || Self.isPastStatus($0.status) }
            .filter { $0.status != "requested" }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    private static func isUpcomingStatus(_ status: String) -> Bool {
        switch status {
        case "scheduled", "confirmed":
            return true
        default:
            return false
        }
    }

    private static func isPastStatus(_ status: String) -> Bool {
        switch status {
        case "completed", "cancelled", "no_show":
            return true
        default:
            return false
        }
    }
    
    func loadSchedule() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let me = await AuthService.shared.restoreSession() else {
                errorMessage = "Authentication failed"
                showError = true
                return
            }
            
            let fetchAppts: [AppointmentDTO]
            let fetchReqs: [AppointmentDTO]

            if let storeId = me.storeId {
                fetchAppts = try await AppointmentService.shared.fetchAppointments(forStoreId: storeId)
                fetchReqs = try await AppointmentService.shared.fetchRequestedAppointments(forStoreId: storeId)
            } else {
                fetchAppts = try await AppointmentService.shared.fetchAppointments(forAssociateId: me.id)
                fetchReqs = try await AppointmentService.shared.fetchRequestedAppointments()
            }
            
            self.appointments = fetchAppts.filter { normalizedStatus($0.status) != "requested" }
            self.requestedAppointments = fetchReqs.filter {
                normalizedStatus($0.status) == "requested" && $0.associateId == nil
            }
            await loadClientDetails(for: fetchAppts + fetchReqs)
            handleRequestAlerts(with: fetchReqs)
            
        } catch {
            print("[SalesAppointmentsViewModel] Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func acceptRequest(_ request: AppointmentDTO) async {
        do {
            guard let me = await AuthService.shared.restoreSession() else { return }
            let storeAppointments = try await AppointmentService.shared.fetchAppointments(forStoreId: request.storeId)
            let hasConflict = storeAppointments.contains { existing in
                guard existing.id != request.id else { return false }
                // Pending requests should not block acceptance; only active scheduled work blocks.
                guard ["scheduled", "confirmed", "in_progress"].contains(existing.status) else { return false }

                let existingStart = existing.scheduledAt
                let existingEnd = existingStart.addingTimeInterval(TimeInterval(existing.durationMinutes * 60))
                let requestStart = request.scheduledAt
                let requestEnd = requestStart.addingTimeInterval(TimeInterval(request.durationMinutes * 60))
                return DateInterval(start: existingStart, end: existingEnd)
                    .intersects(DateInterval(start: requestStart, end: requestEnd))
            }

            if hasConflict {
                errorMessage = "This slot is no longer available. Another appointment already occupies that time."
                showError = true
                return
            }
            
            let updatedDTO = AppointmentInsertDTO(
                clientId: request.clientId,
                storeId: request.storeId,
                associateId: me.id,
                type: request.type,
                status: "confirmed",
                scheduledAt: request.scheduledAt,
                durationMinutes: request.durationMinutes,
                notes: request.notes,
                videoLink: request.videoLink
            )
            
            // Re-use `AppointmentService.shared.updateAppointment` which we'll add next
            _ = try await AppointmentService.shared.updateAppointment(id: request.id, payload: updatedDTO)
            requestedAppointments.removeAll { $0.id == request.id }
            
            // Reload
            await loadSchedule()
        } catch {
            print("[SalesAppointmentsViewModel] Error accepting requested appointment: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func rejectRequest(_ request: AppointmentDTO) async {
        do {
            let rejectedDTO = AppointmentInsertDTO(
                clientId: request.clientId,
                storeId: request.storeId,
                associateId: request.associateId,
                type: request.type,
                status: "cancelled",
                scheduledAt: request.scheduledAt,
                durationMinutes: request.durationMinutes,
                notes: request.notes,
                videoLink: request.videoLink
            )
            _ = try await AppointmentService.shared.updateAppointment(id: request.id, payload: rejectedDTO)
            requestedAppointments.removeAll { $0.id == request.id }
            await loadSchedule()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func customer(for appointment: AppointmentDTO) -> ClientDTO? {
        clientsById[appointment.clientId]
    }

    private func loadClientDetails(for appointments: [AppointmentDTO]) async {
        let clientIds = appointments.map(\.clientId)
        guard !clientIds.isEmpty else {
            clientsById = [:]
            return
        }

        do {
            let clients = try await ClientService.shared.fetchClients(ids: clientIds)
            clientsById = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
        } catch {
            print("[SalesAppointmentsViewModel] Failed loading client details: \(error.localizedDescription)")
            clientsById = [:]
        }
    }

    private func handleRequestAlerts(with requests: [AppointmentDTO]) {
        let current = Set(requests.map(\.id))

        if lastRequestedIds.isEmpty, !current.isEmpty {
            requestAlertMessage = "You have \(current.count) pending appointment request(s) for your boutique."
            showRequestAlert = true
        } else {
            let added = current.subtracting(lastRequestedIds)
            if !added.isEmpty {
                requestAlertMessage = "\(added.count) new appointment request(s) received."
                showRequestAlert = true
            }
        }

        lastRequestedIds = current
    }

    private func normalizedStatus(_ status: String) -> String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
