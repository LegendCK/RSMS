import SwiftUI

@Observable
@MainActor
final class SalesAfterSalesViewModel {

    var requestType: AfterSalesRequestType = .exchange
    var lookupMode: WarrantyLookupMode = .productId
    var lookupQuery: String = ""
    var productSearchText: String = ""
    var customerNotes: String = ""

    var replacementProductIdText: String = ""
    var replacementQuantityText: String = "1"

    var isLookingUp: Bool = false
    var isCreatingTicket: Bool = false
    var isLoadingProducts: Bool = false
    var isApprovingExchange: Bool = false
    var isCreatingReplacementOrder: Bool = false
    var isCompletingExchange: Bool = false

    var warrantyResult: WarrantyLookupResult?
    var availableProducts: [ProductDTO] = []
    var selectedLookupProductId: UUID?
    var unassignedExchangeTickets: [ServiceTicketDTO] = []
    var myExchangeTickets: [ServiceTicketDTO] = []
    var createdTicket: ServiceTicketDTO?
    var replacementOrderNumber: String?
    var exchangeApproved: Bool = false
    var exchangeCompleted: Bool = false

    var errorMessage: String?
    var queueMessage: String?
    var isLoadingExchangeQueue: Bool = false
    var isClaimingTicketId: UUID?

    private let warrantyService: WarrantyServiceProtocol
    private let ticketService: ServiceTicketServiceProtocol
    private let exchangeService: ExchangeProcessingServiceProtocol
    private let catalogService: CatalogService

    init(
        warrantyService: WarrantyServiceProtocol,
        ticketService: ServiceTicketServiceProtocol,
        exchangeService: ExchangeProcessingServiceProtocol,
        catalogService: CatalogService
    ) {
        self.warrantyService = warrantyService
        self.ticketService = ticketService
        self.exchangeService = exchangeService
        self.catalogService = catalogService
    }

    convenience init() {
        self.init(
            warrantyService: WarrantyService.shared,
            ticketService: ServiceTicketService.shared,
            exchangeService: ExchangeProcessingService.shared,
            catalogService: CatalogService.shared
        )
    }

    var canLookup: Bool {
        !lookupQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLookingUp
    }

    var canCreateTicket: Bool {
        warrantyResult != nil && !isCreatingTicket
    }

    var canApproveExchange: Bool {
        requestType == .exchange && createdTicket != nil && !isApprovingExchange && !exchangeApproved
    }

    var canCreateReplacementOrder: Bool {
        requestType == .exchange && createdTicket != nil && exchangeApproved && !isCreatingReplacementOrder && replacementOrderNumber == nil
    }

    var canCompleteExchange: Bool {
        requestType == .exchange && createdTicket != nil && exchangeApproved && replacementOrderNumber != nil && !isCompletingExchange && !exchangeCompleted
    }

    var filteredProducts: [ProductDTO] {
        let query = productSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return Array(availableProducts.prefix(30))
        }

        return availableProducts
            .filter { product in
                product.name.lowercased().contains(query)
                || product.sku.lowercased().contains(query)
                || product.id.uuidString.lowercased().contains(query)
                || (product.brand?.lowercased().contains(query) ?? false)
            }
            .prefix(40)
            .map { $0 }
    }

    func loadProductsIfNeeded() async {
        guard lookupMode == .productId, availableProducts.isEmpty, !isLoadingProducts else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            availableProducts = try await catalogService.fetchProducts()
                .filter { $0.isActive }
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = "Could not load products for lookup: \(error.localizedDescription)"
        }
    }

    func selectProductForLookup(_ product: ProductDTO) {
        selectedLookupProductId = product.id
        lookupMode = .productId
        lookupQuery = product.id.uuidString
    }

    func lookupWarranty() async {
        guard canLookup else { return }

        isLookingUp = true
        errorMessage = nil
        createdTicket = nil
        replacementOrderNumber = nil
        exchangeApproved = false
        exchangeCompleted = false
        selectedLookupProductId = lookupMode == .productId ? UUID(uuidString: lookupQuery) : nil

        do {
            warrantyResult = try await warrantyService.lookupWarranty(mode: lookupMode, query: lookupQuery)
        } catch {
            warrantyResult = nil
            errorMessage = error.localizedDescription
        }

        isLookingUp = false
    }

    func createAfterSalesTicket(currentStoreId: UUID?, assignedUserId: UUID?) async {
        guard let result = warrantyResult else { return }

        let resolvedStoreId = currentStoreId ?? result.storeId
        guard let storeId = resolvedStoreId else {
            errorMessage = "Unable to create AST because store context is unavailable."
            return
        }

        isCreatingTicket = true
        errorMessage = nil

        do {
            let ticketTypeRaw: String = {
                switch requestType {
                case .exchange:
                    return RepairType.repair.rawValue
                case .warrantyValidation:
                    return RepairType.warrantyClaim.rawValue
                }
            }()

            let payload = ServiceTicketInsertDTO(
                clientId: result.clientId,
                storeId: storeId,
                assignedTo: assignedUserId,
                productId: result.productId,
                orderId: result.orderId,
                type: ticketTypeRaw,
                status: RepairStatus.intake.rawValue,
                conditionNotes: conditionSummary(for: result),
                estimatedCost: nil,
                currency: "INR",
                slaDueDate: nil,
                notes: buildNotes(for: result)
            )

            createdTicket = try await ticketService.createTicket(payload)

            if requestType == .exchange {
                replacementProductIdText = result.productId?.uuidString ?? ""
                replacementQuantityText = "1"
            }
        } catch {
            errorMessage = "Could not create AST: \(error.localizedDescription)"
        }

        isCreatingTicket = false
    }

    func approveExchange() async {
        guard let ticket = createdTicket else { return }

        isApprovingExchange = true
        errorMessage = nil

        do {
            let approvedNotes = appendNote(
                base: ticket.notes,
                line: "Exchange Approved At: \(Date().formatted(date: .abbreviated, time: .shortened))"
            )
            createdTicket = try await ticketService.updateTicket(
                id: ticket.id,
                patch: ServiceTicketUpdatePatch(
                    status: RepairStatus.estimateApproved.rawValue,
                    notes: approvedNotes,
                    estimatedCost: nil,
                    finalCost: nil,
                    assignedTo: nil
                )
            )
            exchangeApproved = true
        } catch {
            errorMessage = "Could not approve exchange: \(error.localizedDescription)"
        }

        isApprovingExchange = false
    }

    func createReplacementOrder() async {
        guard let ticket = createdTicket, let result = warrantyResult else { return }

        isCreatingReplacementOrder = true
        errorMessage = nil

        do {
            let replacementId = try resolveReplacementProductId(from: replacementProductIdText, fallback: result.productId)
            let quantity = Int(replacementQuantityText) ?? 1

            let orderResult = try await exchangeService.createReplacementOrder(
                lookupResult: result,
                replacementProductId: replacementId,
                quantity: quantity
            )

            replacementOrderNumber = orderResult.orderNumber

            let withOrderNotes = appendNote(
                base: ticket.notes,
                line: "Replacement Order: \(orderResult.orderNumber) • Product: \(orderResult.replacementProductName) • Qty: \(orderResult.quantity)"
            )

            createdTicket = try await ticketService.updateTicket(
                id: ticket.id,
                patch: ServiceTicketUpdatePatch(
                    status: RepairStatus.inProgress.rawValue,
                    notes: withOrderNotes,
                    estimatedCost: nil,
                    finalCost: nil,
                    assignedTo: nil
                )
            )
        } catch {
            errorMessage = "Could not create replacement order: \(error.localizedDescription)"
        }

        isCreatingReplacementOrder = false
    }

    func completeExchange() async {
        guard let ticket = createdTicket else { return }

        isCompletingExchange = true
        errorMessage = nil

        do {
            let completionNotes = appendNote(
                base: ticket.notes,
                line: "Exchange Completed At: \(Date().formatted(date: .abbreviated, time: .shortened))"
            )

            createdTicket = try await ticketService.updateTicket(
                id: ticket.id,
                patch: ServiceTicketUpdatePatch(
                    status: RepairStatus.completed.rawValue,
                    notes: completionNotes,
                    estimatedCost: nil,
                    finalCost: 0,
                    assignedTo: nil
                )
            )
            exchangeCompleted = true
        } catch {
            errorMessage = "Could not complete exchange: \(error.localizedDescription)"
        }

        isCompletingExchange = false
    }

    func refreshExchangeQueue(storeId: UUID?, staffUserId: UUID?) async {
        guard requestType == .exchange else { return }
        guard let storeId else {
            queueMessage = "Store context unavailable."
            return
        }

        isLoadingExchangeQueue = true
        defer { isLoadingExchangeQueue = false }

        do {
            let tickets = try await ticketService.fetchTickets(storeId: storeId)
            let openExchange = tickets.filter { ticket in
                let notes = (ticket.notes ?? "").lowercased()
                let isExchangeType = ticket.type == RepairType.warrantyClaim.rawValue || ticket.type == RepairType.repair.rawValue
                let hasExchangeNote = notes.contains("exchange")
                let isOpen = ticket.status != RepairStatus.completed.rawValue && ticket.status != RepairStatus.cancelled.rawValue
                return isOpen && (isExchangeType || hasExchangeNote)
            }

            unassignedExchangeTickets = openExchange.filter { $0.assignedTo == nil }
            if let staffUserId {
                myExchangeTickets = openExchange.filter { $0.assignedTo == staffUserId }
            } else {
                myExchangeTickets = []
            }
            queueMessage = nil
        } catch {
            queueMessage = "Could not load exchange queue: \(error.localizedDescription)"
        }
    }

    func claimExchangeTicket(
        _ ticket: ServiceTicketDTO,
        staffUserId: UUID?,
        staffName: String
    ) async {
        guard let staffUserId else {
            queueMessage = "Unable to claim ticket because user context is unavailable."
            return
        }
        guard isClaimingTicketId == nil else { return }

        isClaimingTicketId = ticket.id
        defer { isClaimingTicketId = nil }

        let claimLine = "Claimed By: \(staffName) • \(Date().formatted(date: .abbreviated, time: .shortened))"
        let notes = appendNote(base: ticket.notes, line: claimLine)

        do {
            _ = try await ticketService.updateTicket(
                ticketId: ticket.id,
                patch: ServiceTicketUpdatePatch(
                    status: nil,
                    notes: notes,
                    estimatedCost: nil,
                    finalCost: nil,
                    assignedTo: staffUserId
                )
            )
            queueMessage = "Ticket \(ticket.displayTicketNumber) assigned to you."
        } catch {
            queueMessage = "Could not claim ticket: \(error.localizedDescription)"
        }
    }

    private func resolveReplacementProductId(from text: String, fallback: UUID?) throws -> UUID {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty, let explicit = UUID(uuidString: cleaned) {
            return explicit
        }
        if let fallback {
            return fallback
        }
        throw ExchangeProcessingError.productMissing
    }

    private func appendNote(base: String?, line: String) -> String {
        let existing = (base ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty { return line }
        return existing + "\n" + line
    }

    private func conditionSummary(for result: WarrantyLookupResult) -> String {
        let issueText = customerNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = requestType == .exchange ? "Exchange request" : "Warranty verification"

        if issueText.isEmpty {
            return "\(headline) initiated by after-sales specialist. Warranty: \(result.status.rawValue)."
        }

        return "\(headline) initiated by after-sales specialist. \(issueText)"
    }

    private func buildNotes(for result: WarrantyLookupResult) -> String {
        let services = result.eligibleServices.isEmpty
            ? "None listed"
            : result.eligibleServices.joined(separator: ", ")

        let purchaseText = result.purchasedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unavailable"

        return [
            "AST Warranty Link",
            "Request Type: \(requestType.rawValue)",
            "Lookup Source: \(result.lookupMode.rawValue)",
            "Lookup Query: \(result.lookupQuery)",
            "Warranty Status: \(result.status.rawValue)",
            "Coverage Period: \(result.coveragePeriodText)",
            "Purchase Date: \(purchaseText)",
            "Eligible Services: \(services)",
            result.orderNumber.map { "Order Number: \($0)" },
            result.productName.map { "Product: \($0)" },
            customerNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : "Specialist Notes: \(customerNotes.trimmingCharacters(in: .whitespacesAndNewlines))"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}
