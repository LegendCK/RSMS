//
//  ClientDetailViewModel.swift
//  RSMS
//
//  ViewModel for the client detail / history dashboard used by sales associates.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class ClientDetailViewModel {

    // MARK: - Live data
    var client: ClientDTO
    var orders: [OrderDTO] = []
    var appointments: [AppointmentDTO] = []
    var serviceTickets: [ServiceTicketDTO] = []
    
    var upcomingAppointments: [AppointmentDTO] {
        let now = Date()
        return appointments
            .filter { $0.scheduledAt >= now }
            .filter { Self.isUpcomingStatus($0.status) || $0.status == "in_progress" }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }
    
    var pastAppointments: [AppointmentDTO] {
        let now = Date()
        return appointments
            .filter { $0.scheduledAt < now || Self.isPastStatus($0.status) }
            .filter { $0.status != "requested" }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    // MARK: - Loading states
    var isLoadingHistory = false
    var isSaving = false

    // MARK: - Alerts
    var showSaveError = false
    var saveErrorMessage = ""
    var showSaveSuccess = false

    // MARK: - Edit mode
    var isEditing = false

    // Personal
    var editFirstName = ""
    var editLastName = ""
    var editPhone = ""
    var editDobDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    var editNationality = ""
    var editPreferredLanguage = "en"
    var editAddressLine1 = ""
    var editAddressLine2 = ""
    var editCity = ""
    var editState = ""
    var editPostalCode = ""
    var editCountry = ""
    var editSegment = "standard"
    var editMarketingOptIn = false

    // Preferences / Notes
    var editFreeNotes = ""
    var editPreferredCategories: Set<String> = []
    var editPreferredBrands: [String] = []
    var editCommunicationPreference = "Email"
    var editSizeRing = ""
    var editSizeWrist = ""
    var editSizeDress = ""
    var editSizeShoe = ""
    var editSizeJacket = ""
    var editAnniversaries: [ClientAnniversary] = []
    var newBrandText = ""

    // All known categories (default + any custom ones from blob)
    var availableCategories = ["Jewellery", "Watches", "Handbags", "Ready-to-Wear", "Shoes", "Accessories"]

    // MARK: - Convenience
    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var blob: ClientNotesBlob {
        ClientNotesBlob.from(jsonString: client.notes)
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

    /// Lifetime value — sum of all completed order totals
    var lifetimeValue: Double {
        orders.filter { $0.status == "completed" || $0.status == "delivered" }
              .reduce(0) { $0 + $1.grandTotal }
    }

    init(client: ClientDTO) {
        self.client = client
    }

    // MARK: - History Loading

    func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        async let o = ClientHistoryService.shared.fetchOrders(for: client.id)
        async let a = ClientHistoryService.shared.fetchAppointments(for: client.id)
        async let t = ClientHistoryService.shared.fetchServiceTickets(for: client.id)
        do {
            let (ord, apt, tkt) = try await (o, a, t)
            orders = ord
            appointments = apt
            serviceTickets = tkt
        } catch {
            print("[ClientDetailVM] loadHistory failed: \(error)")
        }
    }

    // MARK: - Edit Lifecycle

    func startEditing() {
        editFirstName = client.firstName
        editLastName = client.lastName
        editPhone = client.phone ?? ""
        if let dob = client.dateOfBirth, let date = Self.isoFormatter.date(from: dob) {
            editDobDate = date
        } else {
            editDobDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        }
        editNationality = client.nationality ?? ""
        editPreferredLanguage = client.preferredLanguage ?? "en"
        editAddressLine1 = client.addressLine1 ?? ""
        editAddressLine2 = client.addressLine2 ?? ""
        editCity = client.city ?? ""
        editState = client.state ?? ""
        editPostalCode = client.postalCode ?? ""
        editCountry = client.country ?? ""
        editSegment = client.segment ?? "standard"
        editMarketingOptIn = client.marketingOptIn

        let b = blob
        editFreeNotes = b.notes
        editPreferredCategories = Set(b.preferences.preferredCategories)
        editPreferredBrands = b.preferences.preferredBrands
        editCommunicationPreference = b.preferences.communicationPreference
        editSizeRing = b.sizes.ring
        editSizeWrist = b.sizes.wrist
        editSizeDress = b.sizes.dress
        editSizeShoe = b.sizes.shoe
        editSizeJacket = b.sizes.jacket
        editAnniversaries = b.anniversaries

        // Merge custom categories from blob into available list
        let merged = Set(availableCategories).union(editPreferredCategories)
        availableCategories = Array(merged).sorted()

        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
    }

    func saveEdits() async {
        isSaving = true
        defer { isSaving = false }

        var newBlob = ClientNotesBlob()
        newBlob.notes = editFreeNotes
        newBlob.preferences.preferredCategories = Array(editPreferredCategories)
        newBlob.preferences.preferredBrands = editPreferredBrands
        newBlob.preferences.communicationPreference = editCommunicationPreference
        newBlob.sizes.ring = editSizeRing
        newBlob.sizes.wrist = editSizeWrist
        newBlob.sizes.dress = editSizeDress
        newBlob.sizes.shoe = editSizeShoe
        newBlob.sizes.jacket = editSizeJacket
        newBlob.anniversaries = editAnniversaries

        let payload = ClientAssociateUpdateDTO(
            firstName: editFirstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: editLastName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: editPhone.isEmpty ? nil : editPhone,
            dateOfBirth: Self.isoFormatter.string(from: editDobDate),
            nationality: editNationality.isEmpty ? nil : editNationality,
            preferredLanguage: editPreferredLanguage,
            addressLine1: editAddressLine1.isEmpty ? nil : editAddressLine1,
            addressLine2: editAddressLine2.isEmpty ? nil : editAddressLine2,
            city: editCity.isEmpty ? nil : editCity,
            state: editState.isEmpty ? nil : editState,
            postalCode: editPostalCode.isEmpty ? nil : editPostalCode,
            country: editCountry.isEmpty ? nil : editCountry,
            segment: editSegment,
            notes: newBlob.toJSONString(),
            marketingOptIn: editMarketingOptIn
        )

        do {
            let updated = try await ClientService.shared.updateClient(id: client.id, payload: payload)
            client = updated
            isEditing = false
            showSaveSuccess = true
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    // MARK: - Preference helpers

    func toggleCategory(_ cat: String) {
        if editPreferredCategories.contains(cat) {
            editPreferredCategories.remove(cat)
        } else {
            editPreferredCategories.insert(cat)
        }
    }

    func addBrand() {
        let t = newBrandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !editPreferredBrands.contains(t) else { newBrandText = ""; return }
        editPreferredBrands.append(t)
        newBrandText = ""
    }

    func removeBrand(_ brand: String) {
        editPreferredBrands.removeAll { $0 == brand }
    }

    func addAnniversary() {
        editAnniversaries.append(ClientAnniversary(label: "Special Day", date: ""))
    }

    func removeAnniversary(at idx: Int) {
        guard editAnniversaries.indices.contains(idx) else { return }
        editAnniversaries.remove(at: idx)
    }

    func anniversaryDateBinding(for index: Int) -> Binding<Date> {
        Binding<Date>(
            get: { Self.isoFormatter.date(from: self.editAnniversaries[index].date) ?? Date() },
            set: { self.editAnniversaries[index].date = Self.isoFormatter.string(from: $0) }
        )
    }
}
