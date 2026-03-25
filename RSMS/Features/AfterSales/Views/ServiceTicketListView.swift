//
//  ServiceTicketListView.swift
//  RSMS
//
//  Lists all service tickets for the current store (staff view).
//  Supports filtering by status, search, and navigation to detail/create.
//

import SwiftUI

@Observable
@MainActor
final class ServiceTicketListViewModel {
    var tickets: [ServiceTicketDTO] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedStatusFilter: RepairStatus?

    private let ticketService: ServiceTicketServiceProtocol

    init(ticketService: ServiceTicketServiceProtocol) {
        self.ticketService = ticketService
    }

    convenience init() {
        self.init(ticketService: ServiceTicketService.shared)
    }

    var filteredTickets: [ServiceTicketDTO] {
        var result = tickets

        if let filter = selectedStatusFilter {
            result = result.filter { $0.status == filter.rawValue }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.displayTicketNumber.lowercased().contains(query)
                || ($0.conditionNotes?.lowercased().contains(query) ?? false)
                || ($0.notes?.lowercased().contains(query) ?? false)
                || $0.ticketType.displayName.lowercased().contains(query)
            }
        }

        return result
    }

    func loadTickets(storeId: UUID?) async {
        guard let storeId else {
            errorMessage = "Store context unavailable."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            tickets = try await ticketService.fetchTickets(storeId: storeId)
        } catch {
            errorMessage = "Could not load tickets: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

@MainActor
struct ServiceTicketListView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = ServiceTicketListViewModel()
    @State private var showCreateTicket = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if vm.isLoading && vm.tickets.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    ProgressView().tint(AppColors.accent)
                    Text("Loading tickets...")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            } else if let error = vm.errorMessage, vm.tickets.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(AppTypography.emptyStateIcon)
                        .foregroundColor(AppColors.warning)
                    Text(error)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.loadTickets(storeId: appState.currentStoreId) }
                    }
                    .foregroundColor(AppColors.accent)
                }
                .padding()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {
                        // Stats row
                        statsRow

                        // Status filter
                        statusFilterRow

                        // Search
                        searchBar

                        // Tickets
                        if vm.filteredTickets.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: AppSpacing.sm) {
                                ForEach(vm.filteredTickets) { ticket in
                                    NavigationLink(destination: ServiceTicketDetailView(ticket: ticket)) {
                                        ticketCard(ticket)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Service Tickets")
                    .font(AppTypography.navTitle)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateTicket = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(AppTypography.toolbarIcon)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateTicket) {
            NavigationStack {
                CreateServiceTicketView()
            }
            .onDisappear {
                Task { await vm.loadTickets(storeId: appState.currentStoreId) }
            }
        }
        .task { await vm.loadTickets(storeId: appState.currentStoreId) }
        .refreshable { await vm.loadTickets(storeId: appState.currentStoreId) }
    }
}

// MARK: - Subviews

private extension ServiceTicketListView {

    var statsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            statBadge(
                count: vm.tickets.count,
                label: "Total",
                color: AppColors.info
            )
            statBadge(
                count: vm.tickets.filter { $0.status == RepairStatus.intake.rawValue }.count,
                label: "Intake",
                color: AppColors.warning
            )
            statBadge(
                count: vm.tickets.filter { $0.status == RepairStatus.inProgress.rawValue }.count,
                label: "Active",
                color: .blue
            )
            statBadge(
                count: vm.tickets.filter { $0.status == RepairStatus.completed.rawValue }.count,
                label: "Done",
                color: AppColors.success
            )
        }
    }

    func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    var statusFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                filterChip(label: "All", isSelected: vm.selectedStatusFilter == nil) {
                    vm.selectedStatusFilter = nil
                }
                ForEach(RepairStatus.allCases) { status in
                    filterChip(
                        label: status.displayName,
                        isSelected: vm.selectedStatusFilter == status,
                        color: status.statusColor
                    ) {
                        vm.selectedStatusFilter = (vm.selectedStatusFilter == status) ? nil : status
                    }
                }
            }
        }
    }

    func filterChip(label: String, isSelected: Bool, color: Color = AppColors.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule().fill(isSelected ? color : Color(.secondarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
    }

    var searchBar: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search tickets...", text: $vm.searchText)
                .textInputAutocapitalization(.never)
                .font(AppTypography.bodyMedium)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(AppTypography.emptyStateIcon)
                .foregroundColor(.secondary.opacity(0.4))
            Text("No tickets found")
                .font(AppTypography.heading3)
                .foregroundColor(.primary)
            Text(vm.searchText.isEmpty && vm.selectedStatusFilter == nil
                 ? "Create your first service ticket to get started."
                 : "Try adjusting your search or filter.")
                .font(AppTypography.bodySmall)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppSpacing.xxxl)
    }

    func ticketCard(_ ticket: ServiceTicketDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(ticket.displayTicketNumber)
                    .font(AppTypography.label)
                    .foregroundColor(.primary)
                Spacer()
                statusPill(ticket.ticketStatus)
            }

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: ticket.ticketType.icon)
                    .font(AppTypography.iconSmall)
                    .foregroundColor(AppColors.accent)
                Text(ticket.ticketType.displayName)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.primary)
            }

            if let notes = ticket.conditionNotes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                if ticket.isOverdue {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(AppTypography.caption)
                        Text("Overdue")
                            .font(AppTypography.nano)
                    }
                    .foregroundColor(AppColors.error)
                }
                Spacer()
                Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    func statusPill(_ status: RepairStatus) -> some View {
        Text(status.displayName.uppercased())
            .font(AppTypography.nano)
            .tracking(0.8)
            .foregroundColor(status.statusColor)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(status.statusColor.opacity(0.14))
            )
    }
}
