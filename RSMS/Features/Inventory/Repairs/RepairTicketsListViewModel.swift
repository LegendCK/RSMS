//
//  RepairTicketsListViewModel.swift
//  RSMS
//
//  Owns the list of service_tickets for the current store.
//  Supports optional status filter and pull-to-refresh.
//  Status updates (swipe or detail view) patch Supabase then re-fetch.
//
//  NEW FILE — place in RSMS/Features/Inventory/Repairs/
//

import SwiftUI

extension Notification.Name {
    static let repairTicketCreated = Notification.Name("repairTicketCreated")
}

@Observable
@MainActor
final class RepairTicketsListViewModel {

    // MARK: - State

    var tickets: [ServiceTicketDTO]         = []
    var isLoading: Bool                     = false
    var errorMessage: String?               = nil
    var selectedFilter: RepairStatus?       = nil   // nil = show all

    // MARK: - Computed

    var filteredTickets: [ServiceTicketDTO] {
        guard let f = selectedFilter else { return tickets }
        return tickets.filter { $0.status == f.rawValue }
    }

    var openCount: Int {
        tickets.filter {
            $0.status != RepairStatus.completed.rawValue &&
            $0.status != RepairStatus.cancelled.rawValue
        }.count
    }

    // MARK: - Dependencies

    private let storeId: UUID
    private let service: ServiceTicketServiceProtocol

    // MARK: - Init

    init(
        storeId: UUID,
        service: ServiceTicketServiceProtocol = ServiceTicketService.shared
    ) {
        self.storeId = storeId
        self.service = service
        
        NotificationCenter.default.addObserver(forName: .repairTicketCreated, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    // MARK: - Load

    func load() async {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil
        do {
            tickets = try await service.fetchTickets(storeId: storeId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Status Update

    func updateStatus(ticket: ServiceTicketDTO, to newStatus: RepairStatus) async {
        do {
            try await service.updateStatus(ticketId: ticket.id, status: newStatus.rawValue)
            await load()
        } catch {
            errorMessage = "Status update failed: \(error.localizedDescription)"
        }
    }
}
