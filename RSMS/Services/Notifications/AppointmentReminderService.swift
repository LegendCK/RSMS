import Foundation
import UserNotifications

@MainActor
final class AppointmentReminderService {
    static let shared = AppointmentReminderService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func syncReminders(
        appointments: [AppointmentDTO],
        storesById: [UUID: StoreDTO]
    ) async {
        let activeStatuses = Set(["scheduled", "confirmed", "in_progress"])
        let activeAppointments = appointments.filter {
            activeStatuses.contains(normalizedStatus($0.status)) && $0.scheduledAt > Date()
        }

        let granted = await ensureAuthorization()
        guard granted else { return }

        let desiredIdentifiers = Set(activeAppointments.flatMap { identifiers(for: $0.id) })
        let existingIdentifiers = await pendingIdentifiers(prefix: "appointment-reminder-")
        let stale = existingIdentifiers.subtracting(desiredIdentifiers)

        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(stale))
        }

        for appointment in activeAppointments {
            await scheduleReminders(for: appointment, storesById: storesById)
        }
    }

    private func scheduleReminders(for appointment: AppointmentDTO, storesById: [UUID: StoreDTO]) async {
        let storeName = storesById[appointment.storeId]?.name ?? "your boutique"
        let title = "Appointment Reminder"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let startsAt = formatter.string(from: appointment.scheduledAt)

        let rules: [(idSuffix: String, offset: TimeInterval, phrase: String)] = [
            ("24h", 24 * 3600, "in 24 hours"),
            ("1h", 1 * 3600, "in 1 hour")
        ]

        for rule in rules {
            let fireDate = appointment.scheduledAt.addingTimeInterval(-rule.offset)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Your appointment at \(storeName) is \(rule.phrase) (\(startsAt))."
            content.sound = .default

            let interval = fireDate.timeIntervalSinceNow
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "appointment-reminder-\(appointment.id.uuidString)-\(rule.idSuffix)",
                content: content,
                trigger: trigger
            )

            do {
                try await add(request)
            } catch {
                print("[AppointmentReminderService] Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization()
        default:
            return false
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func pendingIdentifiers(prefix: String) async -> Set<String> {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let ids = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(prefix) }
                continuation.resume(returning: Set(ids))
            }
        }
    }

    private func normalizedStatus(_ status: String) -> String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func identifiers(for appointmentId: UUID) -> [String] {
        [
            "appointment-reminder-\(appointmentId.uuidString)-24h",
            "appointment-reminder-\(appointmentId.uuidString)-1h"
        ]
    }
}
