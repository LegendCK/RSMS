import Foundation
import SwiftUI

@Observable
@MainActor
final class CustomerAppointmentsViewModel {
    var appointments: [AppointmentDTO] = []
    var storesById: [UUID: StoreDTO] = [:]
    var isLoading = false
    var isProcessing = false
    var showError = false
    var errorMessage = ""
    var showSuccess = false
    var successMessage = ""

    // Action sheet state
    var appointmentToCancel: AppointmentDTO? = nil
    var appointmentToReschedule: AppointmentDTO? = nil
    var showBookingSheet = false
    var showSACancellationAlert = false
    var saCancellationMessage = ""

    /// Tracks statuses from the previous load to detect SA-side cancellations.
    private var lastAppointmentStatuses: [UUID: String] = [:]
    /// IDs the customer cancelled themselves — skip the "SA cancelled" alert for those.
    private var customerCancelledIds: Set<UUID> = []

    var upcomingAppointments: [AppointmentDTO] {
        let now = Date()
        let activeStatuses = Set(["requested", "scheduled", "confirmed", "in_progress"])
        return appointments
            .filter { $0.scheduledAt >= now && activeStatuses.contains(normalizedStatus($0.status)) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pastAppointments: [AppointmentDTO] {
        let now = Date()
        let pastStatuses = Set(["completed", "cancelled", "no_show"])
        return appointments
            .filter { $0.scheduledAt < now || pastStatuses.contains(normalizedStatus($0.status)) }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    func loadAppointments(clientId: UUID?) async {
        guard let clientId else {
            appointments = []
            storesById = [:]
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let rows = try await ClientHistoryService.shared.fetchAppointments(for: clientId)
            handleSACancellations(with: rows)
            appointments = rows
            let stores = try await StoreSyncService.shared.fetchStores(ids: rows.map(\.storeId))
            storesById = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0) })
            await AppointmentReminderService.shared.syncReminders(
                appointments: rows,
                storesById: storesById
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Actions

    /// Returns true if the customer can cancel or reschedule this appointment.
    func canTakeAction(on appointment: AppointmentDTO) -> Bool {
        let actionable = Set(["requested", "scheduled", "confirmed"])
        return actionable.contains(normalizedStatus(appointment.status)) && appointment.scheduledAt > Date()
    }

    /// Cancels the appointment in Supabase and removes local reminders.
    func cancelAppointment(_ appointment: AppointmentDTO) async {
        isProcessing = true
        defer { isProcessing = false }
        // Mark as customer-cancelled so handleSACancellations doesn't misfire
        customerCancelledIds.insert(appointment.id)
        do {
            let updated = try await AppointmentService.shared.cancelAppointment(appointment)
            if let idx = appointments.firstIndex(where: { $0.id == appointment.id }) {
                appointments[idx] = updated
            }
            AppointmentReminderService.shared.cancelReminders(for: appointment.id)
            await AppointmentReminderService.shared.syncReminders(
                appointments: appointments,
                storesById: storesById
            )
            successMessage = "Your appointment has been cancelled."
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Submits a reschedule request to Supabase (status → "requested", new preferred time).
    func requestReschedule(_ appointment: AppointmentDTO, newDate: Date) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let updated = try await AppointmentService.shared.requestReschedule(appointment, newDate: newDate)
            if let idx = appointments.firstIndex(where: { $0.id == appointment.id }) {
                appointments[idx] = updated
            }
            // Remove old reminders — the new slot hasn't been confirmed yet
            AppointmentReminderService.shared.cancelReminders(for: appointment.id)
            successMessage = "Reschedule request submitted. Your associate will confirm the new time."
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - SA Cancellation Detection

    /// Detects when the SA cancelled a previously active appointment and shows an alert.
    /// First load just populates the baseline silently.
    private func handleSACancellations(with freshRows: [AppointmentDTO]) {
        guard !lastAppointmentStatuses.isEmpty else {
            for appt in freshRows { lastAppointmentStatuses[appt.id] = appt.status }
            return
        }

        let activeStatuses = Set(["scheduled", "confirmed", "in_progress"])
        let cancelledBySA = freshRows.filter { appt in
            let prev = lastAppointmentStatuses[appt.id] ?? ""
            guard !customerCancelledIds.contains(appt.id) else { return false }
            return normalizedStatus(appt.status) == "cancelled" && activeStatuses.contains(prev)
        }

        customerCancelledIds.removeAll()

        if !cancelledBySA.isEmpty {
            let count = cancelledBySA.count
            saCancellationMessage = count == 1
                ? "Your appointment has been cancelled by the boutique. Please book a new time if you'd like to reschedule."
                : "\(count) of your appointments have been cancelled by the boutique."
            showSACancellationAlert = true
        }

        for appt in freshRows { lastAppointmentStatuses[appt.id] = appt.status }
    }

    // MARK: - Helpers

    func storeName(for appointment: AppointmentDTO) -> String {
        storesById[appointment.storeId]?.name ?? "Boutique"
    }

    func normalizedType(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    func normalizedStatus(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func statusLabel(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
