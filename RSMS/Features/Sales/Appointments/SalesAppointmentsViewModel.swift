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
    
    var isLoading = false
    var showError = false
    var errorMessage = ""
    
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
            
            let fetchAppts = try await AppointmentService.shared.fetchAppointments(forAssociateId: me.id)
            let fetchReqs = try await AppointmentService.shared.fetchRequestedAppointments()
            
            self.appointments = fetchAppts
            self.requestedAppointments = fetchReqs
            
        } catch {
            print("[SalesAppointmentsViewModel] Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func acceptRequest(_ request: AppointmentDTO) async {
        do {
            guard let me = await AuthService.shared.restoreSession() else { return }
            
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
            
            // Reload
            await loadSchedule()
        } catch {
            print("[SalesAppointmentsViewModel] Error accepting requested appointment: \(error.localizedDescription)")
        }
    }
}
