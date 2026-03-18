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
    var showCancellationAlert = false
    var cancellationAlertMessage = ""
    /// Set by acceptRequest / rejectRequest to tell the view which tab to switch to.
    var pendingTabSwitch: Int? = nil
    private var lastRequestedIds: Set<UUID> = []
    /// Tracks appointment statuses from the previous load so we can detect cancellations.
    private var lastAppointmentStatuses: [UUID: String] = [:]
    /// IDs of appointments the SA just cancelled themselves — skip the "customer cancelled" alert for these.
    private var saCancelledIds: Set<UUID> = []
    
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
            await handleCancellations(with: fetchAppts)
            
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
            let confirmed = try await AppointmentService.shared.updateAppointment(id: request.id, payload: updatedDTO)

            // ── Optimistic local update ──────────────────────────────────────
            // Remove from requests immediately and add the confirmed appointment to
            // the appointments array. We do NOT call loadSchedule() here because it
            // races against the DB write and can fetch the row while it still has the
            // old "requested" status — the filter then strips it from `appointments`
            // and the card vanishes until the next manual refresh.
            requestedAppointments.removeAll { $0.id == request.id }
            appointments.removeAll { $0.id == confirmed.id }
            appointments.append(confirmed)

            // Tell the view to switch to the Upcoming tab so the SA can see it.
            pendingTabSwitch = 1

            // Refresh only the requests list (much less likely to have stale data for
            // a row we didn't just touch) so remaining open requests stay accurate.
            if let storeId = me.storeId {
                let freshReqs = try await AppointmentService.shared.fetchRequestedAppointments(forStoreId: storeId)
                requestedAppointments = freshReqs.filter {
                    normalizedStatus($0.status) == "requested" && $0.associateId == nil
                }
            } else {
                let freshReqs = try await AppointmentService.shared.fetchRequestedAppointments()
                requestedAppointments = freshReqs.filter {
                    normalizedStatus($0.status) == "requested" && $0.associateId == nil
                }
            }
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
            // Mark as SA-cancelled so handleCancellations doesn't misfire
            saCancelledIds.insert(request.id)
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
        let clientIds = Array(Set(appointments.map(\.clientId)))
        guard !clientIds.isEmpty else { return }  // nothing to fetch; keep whatever we already have

        do {
            var fetched = try await ClientService.shared.fetchClients(ids: clientIds)

            // If RLS or a permissions issue silently returns an empty array, fall back to
            // fetching all clients (which the staff_select_all_clients policy always allows)
            // and then filter to the IDs we actually need.
            if fetched.isEmpty {
                print("[SalesAppointmentsViewModel] Batch fetch returned empty — trying fetchAllClients fallback")
                let all = try await ClientService.shared.fetchAllClients()
                let needed = Set(clientIds)
                fetched = all.filter { needed.contains($0.id) }
            }

            // Merge into the existing dictionary so any previously-loaded entries are preserved.
            for client in fetched {
                clientsById[client.id] = client
            }
            print("[SalesAppointmentsViewModel] Loaded \(fetched.count) client(s); total cached: \(clientsById.count)")
        } catch {
            print("[SalesAppointmentsViewModel] Failed loading client details: \(error.localizedDescription)")
            // Do NOT clear clientsById — preserve whatever data we already have.
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

    /// Detects appointments that were previously active and are now cancelled.
    /// On first load only populates the tracking dictionary without alerting.
    private func handleCancellations(with newAppointments: [AppointmentDTO]) async {
        guard !lastAppointmentStatuses.isEmpty else {
            // First load — just capture the current statuses as a baseline.
            for appt in newAppointments {
                lastAppointmentStatuses[appt.id] = appt.status
            }
            return
        }

        let activeStatuses = Set(["scheduled", "confirmed", "in_progress"])
        let newlyCancelled = newAppointments.filter { appt in
            let prev = lastAppointmentStatuses[appt.id] ?? ""
            // Skip appointments the SA cancelled themselves — only alert for customer cancellations.
            guard !saCancelledIds.contains(appt.id) else { return false }
            return normalizedStatus(appt.status) == "cancelled" && activeStatuses.contains(prev)
        }
        // Clear the SA-cancelled set now that we've processed this load.
        saCancelledIds.removeAll()

        // Only alert about cancellations if there's a way to distinguish customer-initiated
        // from SA-initiated cancellations. For now, we suppress all alerts since SAs manually
        // changing status in the edit form would incorrectly trigger "customer cancelled" alerts.
        // TODO: Add a `cancelled_by` field to the appointments table to properly track who cancelled.
        if !newlyCancelled.isEmpty {
            // NOTE: Alerts are currently disabled to prevent confusing "customer cancelled" messages
            // when SAs cancel appointments themselves. This should be re-enabled once we add proper
            // cancellation tracking (e.g., a cancelled_by_client_id or cancelled_by_role field).
            
            /*
            // Fire a local push notification on the SA's device for each cancellation.
            for appt in newlyCancelled {
                let name = clientsById[appt.clientId]?.fullName ?? "A customer"
                await AppointmentReminderService.shared.notifyAssociateCancellation(
                    appointmentDate: appt.scheduledAt,
                    customerName: name
                )
            }
            // Also surface an in-app alert.
            let count = newlyCancelled.count
            cancellationAlertMessage = count == 1
                ? "An appointment was cancelled by the customer."
                : "\(count) appointments were cancelled by customers."
            showCancellationAlert = true
            */
        }

        // Update baseline for the next refresh.
        for appt in newAppointments {
            lastAppointmentStatuses[appt.id] = appt.status
        }
    }

    private func normalizedStatus(_ status: String) -> String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
