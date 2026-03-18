//
//  CreateAppointmentViewModel.swift
//  RSMS
//
//  ViewModel for the appointment creation form.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class CreateAppointmentViewModel {
    struct StatusOption: Identifiable {
        let id: String
        let title: String
        let value: String
    }
    
    // Form Data
    var selectedClientId: UUID?
    var preselectedClientName: String?
    var type: String = "in_store"
    var status: String = "scheduled"
    var scheduledAt: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var durationMinutes: Int = 60
    var notes: String = ""
    var videoLink: String = ""
    var selectedAssociateId: UUID?
    private var editingAppointment: AppointmentDTO?
    private var editingStoreId: UUID?
    var lockClientSelection = false
    
    // State
    var clients: [ClientDTO] = []
    var associates: [UserDTO] = []
    var isSubmitting = false
    var showError = false
    var errorMessage = ""
    
    var isFormValid: Bool {
        selectedClientId != nil && selectedAssociateId != nil
    }

    var isEditing: Bool {
        editingAppointment != nil
    }

    var statusOptions: [StatusOption] {
        guard isEditing else { return [] }

        let options: [StatusOption]
        switch status {
        case "requested":
            options = [
                .init(id: "confirmed", title: "Confirmed", value: "confirmed"),
                .init(id: "cancelled", title: "Cancelled", value: "cancelled")
            ]
        case "scheduled", "confirmed", "in_progress":
            options = [
                .init(id: "completed", title: "Completed", value: "completed"),
                .init(id: "cancelled", title: "Cancelled", value: "cancelled")
            ]
        case "completed":
            options = [.init(id: "completed", title: "Completed", value: "completed")]
        case "cancelled":
            options = [.init(id: "cancelled", title: "Cancelled", value: "cancelled")]
        case "no_show":
            options = [.init(id: "no_show", title: "No Show", value: "no_show")]
        default:
            options = [
                .init(id: "completed", title: "Completed", value: "completed"),
                .init(id: "cancelled", title: "Cancelled", value: "cancelled")
            ]
        }

        if options.contains(where: { $0.value == status }) {
            return options
        }

        let current = StatusOption(
            id: "current-\(status)",
            title: status.replacingOccurrences(of: "_", with: " ").capitalized,
            value: status
        )
        return [current] + options
    }

    var selectedClientName: String {
        if let preselectedClientName, !preselectedClientName.isEmpty {
            return preselectedClientName
        }
        if let id = selectedClientId, let match = clients.first(where: { $0.id == id }) {
            return match.fullName
        }
        return "Selected Client"
    }
    
    init(
        preselectedClientId: UUID? = nil,
        preselectedClientName: String? = nil,
        editingAppointment: AppointmentDTO? = nil
    ) {
        self.selectedClientId = preselectedClientId
        self.preselectedClientName = preselectedClientName
        self.lockClientSelection = preselectedClientId != nil || editingAppointment != nil
        if let appt = editingAppointment {
            self.editingAppointment = appt
            self.editingStoreId = appt.storeId
            self.selectedClientId = appt.clientId
            self.type = Self.normalizeType(appt.type)
            self.status = appt.status
            self.scheduledAt = appt.scheduledAt
            self.durationMinutes = appt.durationMinutes
            self.notes = appt.notes ?? ""
            self.videoLink = appt.videoLink ?? ""
            self.selectedAssociateId = appt.associateId
        }
    }
    
    func loadDataIfNeeded() async {
        // Load session to set default associate
        if selectedAssociateId == nil, let me = await AuthService.shared.restoreSession() {
            self.selectedAssociateId = me.id
        }
        
        if clients.isEmpty {
            do {
                self.clients = try await ClientService.shared.fetchAllClients()
            } catch {
                print("[CreateAppointmentVM] Failed to load clients: \(error)")
            }
        }
        
        if associates.isEmpty {
            do {
                self.associates = try await ProfileService.shared.fetchActiveAssociates()
            } catch {
                print("[CreateAppointmentVM] Failed to load associates: \(error)")
            }
        }
    }
    
    func saveAppointment() async -> AppointmentDTO? {
        guard isFormValid else { return nil }
        guard let clientId = selectedClientId else { return nil }
        guard let associateId = selectedAssociateId else { return nil }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            // Get current associate (UserDTO) to extract the storeId and associateId
            let defaultStoreId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
            guard let me = await AuthService.shared.restoreSession() else {
                errorMessage = "Authentication session error."
                showError = true
                return nil
            }
            let storeId = editingStoreId ?? me.storeId ?? defaultStoreId
            let normalizedType = Self.normalizeType(type)
            let payload = AppointmentInsertDTO(
                clientId: clientId,
                storeId: storeId,
                associateId: associateId,
                type: normalizedType,
                status: status,
                scheduledAt: scheduledAt,
                durationMinutes: durationMinutes,
                notes: notes.isEmpty ? nil : notes,
                videoLink: normalizedType == "video_call" && !videoLink.isEmpty ? videoLink : nil
            )
            if let editingAppointment {
                let appointment = try await AppointmentService.shared.updateAppointment(id: editingAppointment.id, payload: payload)
                return appointment
            } else {
                let appointment = try await AppointmentService.shared.createAppointment(payload)
                return appointment
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    private static func normalizeType(_ value: String) -> String {
        switch value {
        case "virtual": return "video_call"
        case "video": return "video_call"
        case "video_call": return "video_call"
        case "in_store", "phone": return value
        default: return "in_store"
        }
    }
}
