//
//  TicketPickupViewModel.swift
//  RSMS
//
//  Manages pickup scheduling, handover, and document generation
//  for a completed service ticket.
//

import SwiftUI

@Observable
@MainActor
final class TicketPickupViewModel {

    // MARK: - State

    var pickup: TicketPickupDTO?
    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String?
    var successMessage: String?

    // Schedule form
    var scheduledDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var handoverNotes: String = ""

    // Document
    var generatedDocumentURL: URL?
    var showShareSheet: Bool = false
    var isGeneratingDoc: Bool = false

    // Handover confirmation
    var showHandoverConfirm: Bool = false

    // MARK: - Context (passed in — not fetched here)

    let ticket: ServiceTicketDTO
    let client: ClientDTO?
    let product: ProductDTO?
    let parts: [ServiceTicketPartDTO]
    let storeName: String
    let storeAddress: String?
    let specialistName: String
    let currentUserId: UUID?

    private let pickupService: TicketPickupServiceProtocol

    init(
        ticket: ServiceTicketDTO,
        client: ClientDTO?,
        product: ProductDTO?,
        parts: [ServiceTicketPartDTO],
        storeName: String,
        storeAddress: String?,
        specialistName: String,
        currentUserId: UUID?,
        pickupService: TicketPickupServiceProtocol? = nil
    ) {
        self.ticket         = ticket
        self.client         = client
        self.product        = product
        self.parts          = parts
        self.storeName      = storeName
        self.storeAddress   = storeAddress
        self.specialistName = specialistName
        self.currentUserId  = currentUserId
        self.pickupService  = pickupService ?? TicketPickupService.shared
    }

    // MARK: - Load

    func loadPickup() async {
        isLoading = true
        errorMessage = nil
        do {
            pickup = try await pickupService.fetchPickup(ticketId: ticket.id)
            // Pre-fill notes from existing record
            if let existing = pickup {
                handoverNotes = existing.handoverNotes ?? ""
                if let sched = existing.scheduledAt { scheduledDate = sched }
            }
        } catch {
            errorMessage = "Could not load pickup info: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Create pickup record (if not yet created)

    func ensurePickupRecord() async {
        guard pickup == nil else { return }
        isSaving = true
        errorMessage = nil
        let payload = TicketPickupInsertDTO(
            ticketId: ticket.id,
            storeId: ticket.storeId,
            clientId: ticket.clientId,
            scheduledAt: nil,
            status: PickupStatus.pending.rawValue,
            handoverNotes: nil
        )
        do {
            pickup = try await pickupService.createPickup(payload)
        } catch {
            errorMessage = "Could not initialise pickup: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // MARK: - Schedule

    func schedulePickup() async {
        await ensurePickupRecord()
        guard let p = pickup else { return }
        isSaving = true
        errorMessage = nil
        let patch = TicketPickupSchedulePatch(
            scheduledAt: scheduledDate,
            status: PickupStatus.scheduled.rawValue,
            appointmentId: nil
        )
        do {
            pickup = try await pickupService.schedulePickup(pickupId: p.id, patch: patch)
            successMessage = "Pickup scheduled for \(scheduledDate.formatted(date: .abbreviated, time: .shortened))."
        } catch {
            errorMessage = "Could not schedule pickup: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // MARK: - Mark ready

    func markReadyForPickup() async {
        await ensurePickupRecord()
        guard let p = pickup else { return }
        isSaving = true
        errorMessage = nil
        do {
            pickup = try await pickupService.markReadyForPickup(pickupId: p.id)
            successMessage = "Marked as ready for pickup."
        } catch {
            errorMessage = "Could not update status: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // MARK: - Confirm handover

    func confirmHandover() async {
        await ensurePickupRecord()
        guard let p = pickup, let userId = currentUserId else {
            errorMessage = "Cannot confirm handover: missing user context."
            return
        }
        isSaving = true
        errorMessage = nil
        let patch = TicketPickupHandoverPatch(
            status: PickupStatus.handedOver.rawValue,
            handoverNotes: handoverNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                               ? nil
                               : handoverNotes,
            handedOverBy: userId,
            handedOverAt: Date()
        )
        do {
            pickup = try await pickupService.confirmHandover(pickupId: p.id, patch: patch)
            successMessage = "Handover confirmed. Product returned to client."
        } catch {
            errorMessage = "Could not confirm handover: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // MARK: - Generate document

    func generateHandoverDocument() {
        isGeneratingDoc = true
        errorMessage = nil

        let usedParts = parts.filter { $0.partStatus == .used }.map {
            HandoverPartLine(
                name: $0.product?.name ?? "Unknown",
                sku: $0.product?.sku ?? "—",
                quantity: $0.quantityUsed
            )
        }

        let repairSummary = buildRepairSummary()

        let docData = HandoverDocumentData(
            ticketNumber:    ticket.displayTicketNumber,
            ticketType:      ticket.ticketType.displayName,
            clientName:      client?.fullName ?? "Client",
            clientEmail:     client?.email ?? "—",
            clientPhone:     client?.phone,
            productName:     product?.name ?? "—",
            productSKU:      product?.sku ?? "—",
            productBrand:    product?.brand,
            storeName:       storeName,
            storeAddress:    storeAddress,
            repairSummary:   repairSummary,
            estimatedCost:   ticket.estimatedCost,
            finalCost:       ticket.finalCost,
            currency:        ticket.currency,
            partsUsed:       usedParts,
            pickupScheduledAt: pickup?.scheduledAt,
            generatedAt:     Date(),
            specialistName:  specialistName
        )

        do {
            generatedDocumentURL = try HandoverDocumentService.generate(data: docData)
            showShareSheet = true
        } catch {
            errorMessage = "Document generation failed: \(error.localizedDescription)"
        }
        isGeneratingDoc = false
    }

    // MARK: - Helpers

    var canSchedule: Bool {
        ticket.ticketStatus == .completed
        && (pickup == nil || pickup?.pickupStatus == .pending)
        && !isSaving
    }

    var canMarkReady: Bool {
        pickup?.pickupStatus == .scheduled && !isSaving
    }

    var canConfirmHandover: Bool {
        let s = pickup?.pickupStatus
        return (s == .scheduled || s == .readyForPickup) && !isSaving
    }

    var isHandedOver: Bool {
        pickup?.pickupStatus == .handedOver
    }

    private func buildRepairSummary() -> String {
        var lines: [String] = []
        if let notes = ticket.conditionNotes, !notes.isEmpty { lines.append(notes) }
        if let notes = ticket.notes, !notes.isEmpty { lines.append(notes) }
        if lines.isEmpty { lines.append("No additional repair notes recorded.") }
        return lines.joined(separator: "\n\n")
    }
}
