//
//  TicketPartsViewModel.swift
//  RSMS
//
//  Manages spare-part allocation for a service ticket.
//

import SwiftUI

@Observable
@MainActor
final class TicketPartsViewModel {

    // MARK: - State

    var parts: [ServiceTicketPartDTO] = []
    var isLoading: Bool = false
    var isAllocating: Bool = false
    var errorMessage: String?
    var successMessage: String?

    // Part search / selection
    var availableProducts: [ProductDTO] = []
    var isLoadingProducts: Bool = false
    var productSearchText: String = ""
    var selectedProduct: ProductDTO?
    var quantityToAllocate: Int = 1
    var allocationNotes: String = ""

    // Availability check
    var checkedAvailability: Int? = nil
    var isCheckingAvailability: Bool = false

    // MARK: - Context

    let ticketId: UUID
    let storeId: UUID
    let allocatedByUserId: UUID?

    // MARK: - Dependencies

    private let partsService: ServiceTicketPartsServiceProtocol
    private let catalogService: CatalogService

    init(
        ticketId: UUID,
        storeId: UUID,
        allocatedByUserId: UUID?,
        partsService: ServiceTicketPartsServiceProtocol = ServiceTicketPartsService.shared,
        catalogService: CatalogService = CatalogService.shared
    ) {
        self.ticketId = ticketId
        self.storeId = storeId
        self.allocatedByUserId = allocatedByUserId
        self.partsService = partsService
        self.catalogService = catalogService
    }

    // MARK: - Filtered products

    var filteredProducts: [ProductDTO] {
        let q = productSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Array(availableProducts.prefix(30)) }
        return availableProducts
            .filter {
                $0.name.lowercased().contains(q)
                || $0.sku.lowercased().contains(q)
                || ($0.brand?.lowercased().contains(q) ?? false)
            }
            .prefix(40)
            .map { $0 }
    }

    var canAllocate: Bool {
        guard let avail = checkedAvailability else { return false }
        return selectedProduct != nil
            && quantityToAllocate > 0
            && avail >= quantityToAllocate
            && !isAllocating
    }

    // MARK: - Load

    func loadParts() async {
        isLoading = true
        errorMessage = nil
        do {
            parts = try await partsService.fetchParts(ticketId: ticketId)
        } catch {
            errorMessage = "Could not load parts: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadProducts() async {
        guard availableProducts.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        do {
            availableProducts = try await catalogService.fetchProducts()
                .filter { $0.isActive }
                .sorted { $0.name < $1.name }
        } catch {
            errorMessage = "Could not load products: \(error.localizedDescription)"
        }
        isLoadingProducts = false
    }

    // MARK: - Availability check

    func selectProduct(_ product: ProductDTO) {
        selectedProduct = product
        productSearchText = product.name
        checkedAvailability = nil
        Task { await checkAvailability() }
    }

    func checkAvailability() async {
        guard let product = selectedProduct else { return }
        isCheckingAvailability = true
        do {
            checkedAvailability = try await partsService.checkAvailability(
                productId: product.id,
                storeId: storeId
            )
        } catch {
            errorMessage = "Availability check failed: \(error.localizedDescription)"
        }
        isCheckingAvailability = false
    }

    // MARK: - Allocate

    func allocatePart() async {
        guard canAllocate, let product = selectedProduct else { return }

        isAllocating = true
        errorMessage = nil
        successMessage = nil

        let payload = ServiceTicketPartInsertDTO(
            ticketId: ticketId,
            productId: product.id,
            storeId: storeId,
            quantityRequired: quantityToAllocate,
            notes: allocationNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                       ? nil
                       : allocationNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            allocatedBy: allocatedByUserId
        )

        do {
            let newPart = try await partsService.allocatePart(payload)
            parts.append(newPart)
            successMessage = "\(product.name) × \(quantityToAllocate) reserved successfully."
            resetForm()
        } catch {
            // DB trigger raises a human-readable EXCEPTION message
            errorMessage = error.localizedDescription
        }

        isAllocating = false
    }

    // MARK: - Mark as used

    func markAsUsed(_ part: ServiceTicketPartDTO) async {
        isAllocating = true
        errorMessage = nil
        let patch = ServiceTicketPartStatusPatch(
            status: TicketPartStatus.used.rawValue,
            quantityUsed: part.quantityRequired
        )
        do {
            let updated = try await partsService.updatePartStatus(partId: part.id, patch: patch)
            replace(part: updated)
            successMessage = "\(updated.product?.name ?? "Part") marked as used."
        } catch {
            errorMessage = "Could not update part: \(error.localizedDescription)"
        }
        isAllocating = false
    }

    // MARK: - Release (return to inventory)

    func releasePart(_ part: ServiceTicketPartDTO) async {
        isAllocating = true
        errorMessage = nil
        do {
            let updated = try await partsService.releasePart(partId: part.id)
            replace(part: updated)
            successMessage = "\(updated.product?.name ?? "Part") released back to inventory."
        } catch {
            errorMessage = "Could not release part: \(error.localizedDescription)"
        }
        isAllocating = false
    }

    // MARK: - Helpers

    private func replace(part updated: ServiceTicketPartDTO) {
        if let idx = parts.firstIndex(where: { $0.id == updated.id }) {
            parts[idx] = updated
        }
    }

    func resetForm() {
        selectedProduct = nil
        productSearchText = ""
        quantityToAllocate = 1
        allocationNotes = ""
        checkedAvailability = nil
    }
}
