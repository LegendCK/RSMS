//
//  RepairTicketsListView.swift
//  RSMS
//
//  Inventory Controller's Repairs tab — lists all service tickets for the
//  current store with status filter chips, swipe-to-update actions, and
//  NavigationLink to RepairTicketDetailView.
//
//  NEW FILE — place in RSMS/Features/Inventory/Repairs/
//

import SwiftUI

struct RepairTicketsListView: View {

    // MARK: - ViewModel

    @State private var vm: RepairTicketsListViewModel

    // MARK: - Init

    init(storeId: UUID) {
        _vm = State(initialValue: RepairTicketsListViewModel(storeId: storeId))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                filterChips
                    .padding(.vertical, AppSpacing.xs)

                if vm.isLoading && vm.tickets.isEmpty {
                    loadingView
                } else if vm.filteredTickets.isEmpty {
                    emptyState
                } else {
                    ticketList
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Repair Tickets")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                    if vm.openCount > 0 {
                        Text("\(vm.openCount) open")
                            .font(AppTypography.nano)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.accent)
                }
                .disabled(vm.isLoading)
            }
        }
        .task   { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                chip(label: "All", status: nil)
                ForEach(RepairStatus.allCases) { s in
                    chip(label: s.displayName, status: s)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func chip(label: String, status: RepairStatus?) -> some View {
        let selected = vm.selectedFilter == status
        return Button {
            withAnimation(.spring(response: 0.25)) {
                vm.selectedFilter = selected ? nil : status
            }
        } label: {
            Text(label)
                .font(AppTypography.actionSmall)
                .foregroundColor(selected ? .white : AppColors.textSecondaryDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selected ? AppColors.accent : AppColors.backgroundSecondary)
                        .overlay(
                            Capsule().stroke(
                                selected ? Color.clear : AppColors.border.opacity(0.5),
                                lineWidth: 0.75
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ticket List

    private var ticketList: some View {
        List {
            ForEach(vm.filteredTickets) { ticket in
                NavigationLink(destination: RepairTicketDetailView(ticket: ticket)) {
                    TicketRowView(ticket: ticket)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: AppSpacing.xxs,
                    leading: AppSpacing.screenHorizontal,
                    bottom: AppSpacing.xxs,
                    trailing: AppSpacing.screenHorizontal
                ))
                // Swipe left → mark In Progress
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if ticket.status == RepairStatus.intake.rawValue {
                        Button {
                            Task { await vm.updateStatus(ticket: ticket, to: .inProgress) }
                        } label: {
                            Label("In Progress", systemImage: "wrench.fill")
                        }
                        .tint(.blue)
                    }
                }
                // Swipe right → mark Completed
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if ticket.status != RepairStatus.completed.rawValue &&
                       ticket.status != RepairStatus.cancelled.rawValue {
                        Button {
                            Task { await vm.updateStatus(ticket: ticket, to: .completed) }
                        } label: {
                            Label("Complete", systemImage: "checkmark.circle.fill")
                        }
                        .tint(AppColors.success)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondaryDark.opacity(0.35))

            Text(vm.selectedFilter == nil
                 ? "No Repair Tickets"
                 : "No \(vm.selectedFilter!.displayName) Tickets")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)

            Text("Scan a barcode and tap \"Log Repair\" to create a ticket.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView().tint(AppColors.accent).scaleEffect(1.2)
            Text("Loading tickets…")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
        }
    }
}

// MARK: - Ticket Row

struct TicketRowView: View {
    let ticket: ServiceTicketDTO

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {

            // Top: ticket number + overdue badge + date
            HStack {
                Text(ticket.displayTicketNumber)
                    .font(AppTypography.monoID)
                    .foregroundColor(AppColors.accent)

                if ticket.isOverdue {
                    Text("OVERDUE")
                        .font(AppTypography.nano)
                        .foregroundColor(AppColors.error)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppColors.error.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(ticket.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            // Middle: type + status pill
            HStack(spacing: AppSpacing.sm) {
                Label(ticket.ticketType.displayName, systemImage: ticket.ticketType.icon)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                statusPill(ticket.ticketStatus)
            }

            // Bottom: condition note preview
            if let notes = ticket.conditionNotes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(2)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .fill(AppColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .stroke(AppColors.border.opacity(0.35), lineWidth: 0.75)
                )
        )
    }

    private func statusPill(_ status: RepairStatus) -> some View {
        Text(status.displayName)
            .font(AppTypography.actionSmall)
            .foregroundColor(status.statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(status.statusColor.opacity(0.12))
            .clipShape(Capsule())
    }
}
