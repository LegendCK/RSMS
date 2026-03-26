//
//  CreateServiceTicketViewModel.swift
//  RSMS
//
//  ViewModel for after-sales ticket creation with client linking,
//  order-item lookup, photo uploads, and condition reporting.
//

import SwiftUI
import PhotosUI

@Observable
@MainActor
final class CreateServiceTicketViewModel {

    // MARK: - Form Fields

    var selectedTicketType: RepairType = .repair
    var conditionNotes: String = ""
    var issueDescription: String = ""
    var additionalNotes: String = ""

    // Client
    var clientSearchText: String = ""
    var selectedClient: ClientDTO?
    var searchedClients: [ClientDTO] = []
    var isSearchingClients: Bool = false
    var availableClients: [ClientDTO] = []

    // Order item (source for service ticket product)
    var productSearchText: String = ""
    var selectedOrderItem: ServiceTicketOrderItem?
    var isSearchingOrderItems: Bool = false
    var availableOrderItems: [ServiceTicketOrderItem] = []

    // Photos
    var selectedPhotoItems: [PhotosPickerItem] = []
    var selectedImages: [UIImage] = []
    var isUploadingPhotos: Bool = false

    // Order (optional manual override)
    var orderNumber: String = ""

    // State
    var isCreatingTicket: Bool = false
    var createdTicket: ServiceTicketDTO?
    var errorMessage: String?
    var successMessage: String?

    // MARK: - Dependencies

    private let ticketService: ServiceTicketServiceProtocol
    private let clientService: ClientService

    init(
        ticketService: ServiceTicketServiceProtocol,
        clientService: ClientService
    ) {
        self.ticketService = ticketService
        self.clientService = clientService
    }

    convenience init() {
        self.init(
            ticketService: ServiceTicketService.shared,
            clientService: ClientService.shared
        )
    }

    // MARK: - Validation

    var canCreateTicket: Bool {
        selectedClient != nil
        && selectedOrderItem != nil
        && !issueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isCreatingTicket
    }

    // MARK: - Client Search

    func loadClients() async {
        guard availableClients.isEmpty, !isSearchingClients else { return }
        isSearchingClients = true
        defer { isSearchingClients = false }

        do {
            availableClients = try await clientService.fetchAllClients()
                .filter { $0.isActive }
                .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        } catch {
            errorMessage = "Could not load clients: \(error.localizedDescription)"
        }
    }

    func searchClients() async {
        let query = clientSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchedClients = []
            return
        }

        isSearchingClients = true
        defer { isSearchingClients = false }

        do {
            searchedClients = try await clientService.searchClients(query: query)
        } catch {
            errorMessage = "Client search failed: \(error.localizedDescription)"
        }
    }

    func selectClient(_ client: ClientDTO) {
        selectedClient = client
        clientSearchText = client.fullName
        searchedClients = []
        selectedOrderItem = nil
        productSearchText = ""
        availableOrderItems = []

        Task { await loadOrderItemsForSelectedClient() }
    }

    func clearClient() {
        selectedClient = nil
        clientSearchText = ""
        searchedClients = []
        clearOrderItemSelection()
        availableOrderItems = []
    }

    // MARK: - Order Item Search

    func loadOrderItemsForSelectedClient() async {
        guard let clientId = selectedClient?.id else {
            availableOrderItems = []
            return
        }
        guard !isSearchingOrderItems else { return }

        isSearchingOrderItems = true
        defer { isSearchingOrderItems = false }

        do {
            availableOrderItems = try await ticketService.fetchClientOrderItems(clientId: clientId, limit: 40)
        } catch {
            errorMessage = "Could not load client order items: \(error.localizedDescription)"
        }
    }

    var filteredOrderItems: [ServiceTicketOrderItem] {
        let query = productSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return availableOrderItems }

        return availableOrderItems.filter { item in
            item.productName.lowercased().contains(query)
            || item.productSku.lowercased().contains(query)
            || (item.productBrand?.lowercased().contains(query) ?? false)
            || item.orderNumber.lowercased().contains(query)
        }
    }

    func selectOrderItem(_ item: ServiceTicketOrderItem) {
        selectedOrderItem = item
        productSearchText = item.productName
        orderNumber = item.orderNumber
    }

    func clearOrderItemSelection() {
        selectedOrderItem = nil
        productSearchText = ""
    }

    // MARK: - Photo Handling

    func processSelectedPhotos() async {
        var images: [UIImage] = []
        for item in selectedPhotoItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        selectedImages = images
    }

    func removePhoto(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        if index < selectedPhotoItems.count {
            selectedPhotoItems.remove(at: index)
        }
    }

    // MARK: - Create Ticket

    func createTicket(storeId: UUID?, assignedUserId: UUID?) async {
        guard canCreateTicket else { return }
        guard let storeId else {
            errorMessage = "Store context unavailable. Cannot create ticket."
            return
        }
        guard let orderItem = selectedOrderItem else { return }

        isCreatingTicket = true
        errorMessage = nil

        do {
            // Build condition notes
            let condition = buildConditionNotes()

            // Build full notes
            let notes = buildNotes()

            // Compress images to JPEG data
            let imageDataArray = selectedImages.compactMap { image in
                image.jpegData(compressionQuality: 0.7)
            }

            // Create ticket first (without photos)
            let payload = ServiceTicketInsertDTO(
                clientId: selectedClient?.id,
                storeId: storeId,
                assignedTo: assignedUserId,
                productId: orderItem.productId,
                orderId: orderItem.orderId,
                type: selectedTicketType.rawValue,
                status: RepairStatus.intake.rawValue,
                conditionNotes: condition,
                intakePhotos: nil,
                estimatedCost: nil,
                currency: "INR",
                slaDueDate: nil,
                notes: notes
            )

            let ticket = try await ticketService.createTicket(payload)

            // Upload photos if any
            if !imageDataArray.isEmpty {
                isUploadingPhotos = true
                do {
                    let photoPaths = try await ticketService.uploadPhotos(images: imageDataArray, ticketId: ticket.id)
                    try await ticketService.updateIntakePhotos(ticketId: ticket.id, photoPaths: photoPaths)
                } catch {
                    // Photos failed but ticket was created — non-fatal
                    errorMessage = "Ticket created but photo upload failed: \(error.localizedDescription)"
                }
                isUploadingPhotos = false
            }

            createdTicket = ticket
            successMessage = "Service ticket \(ticket.displayTicketNumber) created successfully."
        } catch {
            errorMessage = "Could not create ticket: \(error.localizedDescription)"
        }

        isCreatingTicket = false
    }

    // MARK: - Helpers

    private func buildConditionNotes() -> String {
        var lines: [String] = []
        let issue = issueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !issue.isEmpty {
            lines.append("Issue: \(issue)")
        }
        let condition = conditionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !condition.isEmpty {
            lines.append("Condition: \(condition)")
        }
        if !selectedImages.isEmpty {
            lines.append("Photos: \(selectedImages.count) attached")
        }
        return lines.joined(separator: "\n")
    }

    private func buildNotes() -> String {
        var lines: [String] = [
            "After-Sales Service Ticket",
            "Type: \(selectedTicketType.displayName)"
        ]
        if let client = selectedClient {
            lines.append("Client: \(client.fullName) (\(client.email))")
        }
        if let orderItem = selectedOrderItem {
            lines.append("Order: \(orderItem.orderNumber)")
            lines.append("Order Item: \(orderItem.productName) (SKU: \(orderItem.productSku))")
        }
        let trimmedOrder = orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOrder.isEmpty {
            lines.append("Reference: \(trimmedOrder)")
        }
        let additional = additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !additional.isEmpty {
            lines.append("Notes: \(additional)")
        }
        return lines.joined(separator: "\n")
    }

    func resetForm() {
        selectedTicketType = .repair
        conditionNotes = ""
        issueDescription = ""
        additionalNotes = ""
        clientSearchText = ""
        selectedClient = nil
        searchedClients = []
        productSearchText = ""
        selectedOrderItem = nil
        availableOrderItems = []
        selectedPhotoItems = []
        selectedImages = []
        orderNumber = ""
        createdTicket = nil
        errorMessage = nil
        successMessage = nil
    }
}
