//
//  CreateServiceTicketViewModel.swift
//  RSMS
//
//  ViewModel for after-sales ticket creation with product lookup,
//  client linking, photo uploads, and condition reporting.
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

    // Product
    var productSearchText: String = ""
    var selectedProduct: ProductDTO?
    var searchedProducts: [ProductDTO] = []
    var isSearchingProducts: Bool = false
    var availableProducts: [ProductDTO] = []

    // Photos
    var selectedPhotoItems: [PhotosPickerItem] = []
    var selectedImages: [UIImage] = []
    var isUploadingPhotos: Bool = false

    // Order (optional link)
    var orderNumber: String = ""

    // State
    var isCreatingTicket: Bool = false
    var createdTicket: ServiceTicketDTO?
    var errorMessage: String?
    var successMessage: String?

    // MARK: - Dependencies

    private let ticketService: ServiceTicketServiceProtocol
    private let catalogService: CatalogService
    private let clientService: ClientService

    init(
        ticketService: ServiceTicketServiceProtocol,
        catalogService: CatalogService,
        clientService: ClientService
    ) {
        self.ticketService = ticketService
        self.catalogService = catalogService
        self.clientService = clientService
    }

    convenience init() {
        self.init(
            ticketService: ServiceTicketService.shared,
            catalogService: CatalogService.shared,
            clientService: ClientService.shared
        )
    }

    // MARK: - Validation

    var canCreateTicket: Bool {
        selectedClient != nil
        && selectedProduct != nil
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
    }

    func clearClient() {
        selectedClient = nil
        clientSearchText = ""
        searchedClients = []
    }

    // MARK: - Product Search

    func loadProducts() async {
        guard availableProducts.isEmpty, !isSearchingProducts else { return }
        isSearchingProducts = true
        defer { isSearchingProducts = false }

        do {
            availableProducts = try await catalogService.fetchProducts()
                .filter { $0.isActive }
                .sorted { $0.name < $1.name }
        } catch {
            errorMessage = "Could not load products: \(error.localizedDescription)"
        }
    }

    var filteredProducts: [ProductDTO] {
        let query = productSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return Array(availableProducts.prefix(30)) }

        return availableProducts
            .filter {
                $0.name.lowercased().contains(query)
                || $0.sku.lowercased().contains(query)
                || ($0.brand?.lowercased().contains(query) ?? false)
            }
            .prefix(40)
            .map { $0 }
    }

    func selectProduct(_ product: ProductDTO) {
        selectedProduct = product
        productSearchText = product.name
    }

    func clearProduct() {
        selectedProduct = nil
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
        guard let product = selectedProduct else { return }

        isCreatingTicket = true
        errorMessage = nil

        do {
            // Resolve order context if provided
            var orderId: UUID?
            let trimmedOrder = orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedOrder.isEmpty {
                let context = try? await ticketService.resolveOrderContext(orderNumber: trimmedOrder)
                orderId = context?.orderId
            }

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
                productId: product.id,
                orderId: orderId,
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
        if let product = selectedProduct {
            lines.append("Product: \(product.name) (SKU: \(product.sku))")
        }
        let trimmedOrder = orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOrder.isEmpty {
            lines.append("Order: \(trimmedOrder)")
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
        selectedProduct = nil
        selectedPhotoItems = []
        selectedImages = []
        orderNumber = ""
        createdTicket = nil
        errorMessage = nil
        successMessage = nil
    }
}
