import Foundation
import SwiftUI

@Observable
@MainActor
final class CustomerBookAppointmentViewModel {
    var stores: [StoreDTO] = []
    var selectedStoreId: UUID?
    var scheduledAt: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var durationMinutes: Int = 60
    var type: String = "in_store"
    var notes: String = ""
    private(set) var storeAppointments: [AppointmentDTO] = []

    var isLoadingStores = false
    var isSubmitting = false
    var showError = false
    var errorMessage = ""

    var selectedStore: StoreDTO? {
        guard let selectedStoreId else { return nil }
        return stores.first(where: { $0.id == selectedStoreId })
    }

    var canSubmit: Bool {
        selectedStoreId != nil && scheduledAt > Date() && !hasSlotConflict
    }

    var hasSlotConflict: Bool {
        let candidate = candidateInterval
        return storeAppointments.contains { appointment in
            guard isActive(appointment.status) else { return false }
            return intersects(candidate, existing: interval(for: appointment))
        }
    }

    var slotConflictMessage: String? {
        hasSlotConflict ? "That time slot is already booked for this boutique. Please choose a different time." : nil
    }

    func loadStores() async {
        guard stores.isEmpty else { return }
        isLoadingStores = true
        defer { isLoadingStores = false }

        do {
            stores = try await StoreSyncService.shared.fetchActiveBoutiques()
            if selectedStoreId == nil {
                selectedStoreId = stores.first?.id
            }
            await refreshAvailabilityForSelectedStore()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func refreshAvailabilityForSelectedStore() async {
        guard let storeId = selectedStoreId else {
            storeAppointments = []
            return
        }

        do {
            storeAppointments = try await AppointmentService.shared.fetchAppointments(forStoreId: storeId)
        } catch {
            storeAppointments = []
            errorMessage = "Unable to load boutique availability right now."
            showError = true
        }
    }

    func submitAppointmentRequest(clientId fallbackClientId: UUID?) async -> AppointmentDTO? {
        guard canSubmit else { return nil }
        guard let storeId = selectedStoreId else { return nil }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            await refreshAvailabilityForSelectedStore()
            if hasSlotConflict {
                errorMessage = slotConflictMessage ?? "Selected slot is unavailable."
                showError = true
                return nil
            }

            let resolvedClientId: UUID
            if let fallbackClientId {
                resolvedClientId = fallbackClientId
            } else if let me = await AuthService.shared.restoreSession() {
                resolvedClientId = me.id
            } else {
                errorMessage = "Unable to resolve customer account. Please sign in again."
                showError = true
                return nil
            }

            let payload = AppointmentInsertDTO(
                clientId: resolvedClientId,
                storeId: storeId,
                associateId: nil,
                type: normalizeType(type),
                status: "requested",
                scheduledAt: scheduledAt,
                durationMinutes: durationMinutes,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                videoLink: nil
            )

            return try await AppointmentService.shared.createAppointment(payload)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    private func normalizeType(_ value: String) -> String {
        switch value {
        case "video_call", "video", "virtual": return "video_call"
        case "phone": return "phone"
        default: return "in_store"
        }
    }

    private func isActive(_ status: String) -> Bool {
        ["requested", "scheduled", "confirmed", "in_progress"].contains(status)
    }

    private func interval(for appointment: AppointmentDTO) -> DateInterval {
        let start = appointment.scheduledAt
        let end = start.addingTimeInterval(TimeInterval(appointment.durationMinutes * 60))
        return DateInterval(start: start, end: end)
    }

    private var candidateInterval: DateInterval {
        let start = scheduledAt
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return DateInterval(start: start, end: end)
    }

    private func intersects(_ lhs: DateInterval, existing rhs: DateInterval) -> Bool {
        lhs.intersects(rhs)
    }
}
