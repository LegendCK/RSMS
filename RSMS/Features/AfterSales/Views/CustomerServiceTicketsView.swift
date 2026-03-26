//
//  CustomerServiceTicketsView.swift
//  RSMS
//
//  Customer-facing view showing their service tickets with status tracking.
//  Accessible from the customer Profile tab.
//

import SwiftUI

@Observable
@MainActor
final class CustomerServiceTicketsViewModel {
    var tickets: [ServiceTicketDTO] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let ticketService: ServiceTicketServiceProtocol

    init(ticketService: ServiceTicketServiceProtocol) {
        self.ticketService = ticketService
    }

    convenience init() {
        self.init(ticketService: ServiceTicketService.shared)
    }

    func loadTickets(clientId: UUID?) async {
        guard let clientId else {
            errorMessage = "Please sign in to view your service tickets."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            tickets = try await ticketService.fetchTickets(clientId: clientId)
        } catch {
            errorMessage = "Could not load your tickets: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

@MainActor
struct CustomerServiceTicketsView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = CustomerServiceTicketsViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.backgroundPrimary, AppColors.backgroundSecondary.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if vm.isLoading && vm.tickets.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        ProgressView().tint(AppColors.accent)
                        Text("Loading your tickets...")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.tickets.isEmpty {
                    emptyState
                } else {
                    ticketList
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("My Service Tickets")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
        }
        .task {
            let clientId = appState.currentClientProfile?.id ?? appState.currentUserProfile?.id
            await vm.loadTickets(clientId: clientId)
        }
        .refreshable {
            let clientId = appState.currentClientProfile?.id ?? appState.currentUserProfile?.id
            await vm.loadTickets(clientId: clientId)
        }
    }
}

// MARK: - Subviews

private extension CustomerServiceTicketsView {

    var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "wrench.and.screwdriver")
                .font(AppTypography.emptyStateIcon)
                .foregroundColor(AppColors.textSecondaryDark.opacity(0.5))
            Text("No Service Tickets")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("You don't have any service tickets yet. Service tickets are created when you bring a product in for repair, authentication, or other services.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            if let error = vm.errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    var ticketList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                // Summary
                HStack(spacing: AppSpacing.sm) {
                    summaryBadge(
                        count: vm.tickets.filter {
                            $0.status != RepairStatus.completed.rawValue
                            && $0.status != RepairStatus.cancelled.rawValue
                        }.count,
                        label: "Active",
                        color: .blue
                    )
                    summaryBadge(
                        count: vm.tickets.filter { $0.status == RepairStatus.completed.rawValue }.count,
                        label: "Completed",
                        color: AppColors.success
                    )
                }
                .padding(.bottom, AppSpacing.xs)
                .padding(.top, 2)

                ForEach(vm.tickets) { ticket in
                    NavigationLink(destination: ServiceTicketDetailView(ticket: ticket, isCustomerView: true)) {
                        customerTicketCard(ticket)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
        }
    }

    func summaryBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label.uppercased())
                .font(AppTypography.nano)
                .tracking(0.8)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundSecondary, cornerRadius: AppSpacing.radiusMedium)
    }

    func customerTicketCard(_ ticket: ServiceTicketDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.displayTicketNumber)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: ticket.ticketType.icon)
                            .font(AppTypography.iconSmall)
                            .foregroundColor(AppColors.accent)
                        Text(ticket.ticketType.displayName)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                        if ticket.hasRepairEstimate {
                            approvalPill(ticket.clientApprovalStatus)
                        }
                    }
                }
                Spacer()
                statusPill(ticket.ticketStatus)
            }

            // Progress indicator
            progressBar(for: ticket.ticketStatus)

            if let condition = ticket.conditionNotes, !condition.isEmpty {
                Text(condition)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(2)
            }

            HStack {
                if let cost = ticket.estimatedCost {
                    Text("Est. INR \(String(format: "%.0f", cost))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                }
                Spacer()
                Text(ticket.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(AppSpacing.cardPadding)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: AppSpacing.radiusMedium)
        .liquidShadow(LiquidShadow.subtle)
    }

    func progressBar(for status: RepairStatus) -> some View {
        let progress: Double = {
            switch status {
            case .intake: return 0.15
            case .inProgress: return 0.4
            case .estimatePending: return 0.55
            case .estimateApproved: return 0.7
            case .completed: return 1.0
            case .cancelled: return 0.0
            }
        }()

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.border.opacity(0.35))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(status == .cancelled ? AppColors.error : status.statusColor)
                    .frame(width: geo.size.width * progress, height: 6)
            }
        }
        .frame(height: 6)
    }

    func statusPill(_ status: RepairStatus) -> some View {
        Text(status.displayName)
            .font(AppTypography.nano)
            .tracking(0.5)
            .foregroundColor(status.statusColor)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 3)
                .background(Capsule().fill(status.statusColor.opacity(0.2)))
    }

    func approvalPill(_ status: ClientApprovalStatus) -> some View {
        Text("Estimate \(status.displayName)")
            .font(AppTypography.nano)
            .foregroundColor(status.color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 3)
            .background(Capsule().fill(status.color.opacity(0.2)))
    }
}
