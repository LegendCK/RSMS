import Foundation
import SwiftUI

@Observable
@MainActor
final class CustomerAppointmentsViewModel {
    var appointments: [AppointmentDTO] = []
    var storesById: [UUID: StoreDTO] = [:]
    var isLoading = false
    var showError = false
    var errorMessage = ""

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
