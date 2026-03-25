//
//  RepairTicketDetailView.swift
//  RSMS
//
//  Full detail view for a single repair ticket.
//  Shows a visual status timeline and lets the IC update status
//  via a confirmation dialog — patches Supabase and refreshes inline.
//  Re-fetches the ticket on appear so status is always current.
//
//  NEW FILE — place in RSMS/Features/Inventory/Repairs/
//

import SwiftUI

@MainActor
struct RepairTicketDetailView: View {

    // MARK: - State

    @State private var ticket: ServiceTicketDTO
    @State private var isUpdating: Bool          = false
    @State private var showStatusDialog: Bool    = false
    @State private var errorMessage: String?     = nil

    private let service: ServiceTicketServiceProtocol

    // MARK: - Init

    init(
        ticket: ServiceTicketDTO,
        service: ServiceTicketServiceProtocol
    ) {
        _ticket      = State(initialValue: ticket)
        self.service = service
    }

    init(ticket: ServiceTicketDTO) {
        self.init(ticket: ticket, service: ServiceTicketService.shared)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    headerCard
                    statusTimeline
                    detailsCard

                    if let err = errorMessage {
                        errorBanner(err)
                    }

                    if ticket.status != RepairStatus.completed.rawValue &&
                       ticket.status != RepairStatus.cancelled.rawValue {
                        updateStatusButton
                    }

                    Spacer(minLength: AppSpacing.xxxl)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(ticket.displayTicketNumber)
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.accent)
            }
        }
        .confirmationDialog(
            "Update Status",
            isPresented: $showStatusDialog,
            titleVisibility: .visible
        ) {
            ForEach(availableStatuses) { s in
                Button(s.displayName) {
                    Task { await applyStatus(s) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task { await refresh() }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Label(ticket.ticketType.displayName, systemImage: ticket.ticketType.icon)
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                statusPill(ticket.ticketStatus)
            }

            if ticket.isOverdue {
                Label("SLA OVERDUE", systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.actionSmall)
                    .foregroundColor(AppColors.error)
            }

            Text("Created \(ticket.createdAt.formatted(date: .long, time: .shortened))")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardSurface)
    }

    // MARK: - Status Timeline

    private var statusTimeline: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionLabel("STATUS TIMELINE")

            VStack(spacing: 0) {
                ForEach(Array(RepairStatus.allCases.enumerated()), id: \.element.id) { idx, s in
                    let isPast    = ordinal(s) < ordinal(ticket.ticketStatus)
                    let isCurrent = s == ticket.ticketStatus

                    HStack(spacing: AppSpacing.sm) {
                        // Node
                        ZStack {
                            Circle()
                                .fill(isCurrent || isPast ? AppColors.accent : AppColors.backgroundTertiary)
                                .frame(width: 20, height: 20)
                            if isPast {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            } else if isCurrent {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 7, height: 7)
                            }
                        }

                        Text(s.displayName)
                            .font(isCurrent ? AppTypography.label : AppTypography.bodySmall)
                            .foregroundColor(
                                isCurrent ? AppColors.textPrimaryDark
                                : isPast   ? AppColors.textSecondaryDark
                                :            AppColors.border
                            )

                        Spacer()

                        if isCurrent {
                            Text("NOW")
                                .font(AppTypography.nano)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(AppColors.accent.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)

                    // Connector line (skip after last)
                    if idx < RepairStatus.allCases.count - 1 {
                        Rectangle()
                            .fill(isPast ? AppColors.accent.opacity(0.35) : AppColors.backgroundTertiary)
                            .frame(width: 2, height: 14)
                            .padding(.leading, 9)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(cardSurface)
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionLabel("TICKET DETAILS")

            VStack(spacing: 0) {
                if let notes = ticket.conditionNotes, !notes.isEmpty {
                    detailRow(label: "Condition", value: notes, multiline: true)
                    thinDivider
                }
                if let notes = ticket.notes, !notes.isEmpty {
                    detailRow(label: "Notes", value: notes, multiline: true)
                    thinDivider
                }
                if let cost = ticket.estimatedCost {
                    detailRow(label: "Est. Cost", value: String(format: "USD %.2f", cost))
                    thinDivider
                }
                if let final_ = ticket.finalCost {
                    detailRow(label: "Final Cost", value: String(format: "USD %.2f", final_))
                    thinDivider
                }
                if let sla = ticket.slaDueDate {
                    detailRow(
                        label: "SLA Due",
                        value: formattedSLA(sla),
                        valueColor: ticket.isOverdue ? AppColors.error : AppColors.textPrimaryDark
                    )
                }
            }
            .background(cardSurface)
        }
    }

    // MARK: - Update Status Button

    private var updateStatusButton: some View {
        Button { showStatusDialog = true } label: {
            HStack(spacing: AppSpacing.sm) {
                if isUpdating {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Updating…")
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Update Status")
                }
            }
            .font(AppTypography.buttonPrimary)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                    .fill(AppColors.accent)
            )
            .opacity(isUpdating ? 0.6 : 1)
        }
        .disabled(isUpdating)
    }

    // MARK: - Helpers

    private var availableStatuses: [RepairStatus] {
        RepairStatus.allCases.filter { $0 != ticket.ticketStatus }
    }

    /// Ordinal position of a status for timeline colouring.
    private func ordinal(_ s: RepairStatus) -> Int {
        RepairStatus.allCases.firstIndex(of: s) ?? 0
    }

    private func applyStatus(_ newStatus: RepairStatus) async {
        isUpdating   = true
        errorMessage = nil
        do {
            try await service.updateStatus(ticketId: ticket.id, status: newStatus.rawValue)
            await refresh()
        } catch {
            errorMessage = "Update failed: \(error.localizedDescription)"
        }
        isUpdating = false
    }

    private func refresh() async {
        do {
            ticket = try await service.fetchTicket(id: ticket.id)
        } catch {
            print("[RepairTicketDetailView] refresh failed (non-fatal): \(error)")
        }
    }

    // MARK: - Sub-views

    private func statusPill(_ s: RepairStatus) -> some View {
        Text(s.displayName)
            .font(AppTypography.actionSmall)
            .foregroundColor(s.statusColor)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(s.statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color = AppColors.textPrimaryDark,
        multiline: Bool = false
    ) -> some View {
        HStack(alignment: multiline ? .top : .center, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(valueColor)
                .lineLimit(multiline ? 5 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.xs + 2)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(1.5)
            .foregroundColor(AppColors.accent)
    }

    private var thinDivider: some View {
        Divider()
            .background(AppColors.border.opacity(0.3))
            .padding(.horizontal, AppSpacing.cardPadding)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
            .fill(AppColors.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                    .stroke(AppColors.border.opacity(0.35), lineWidth: 0.75)
            )
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
            Text(msg).font(AppTypography.bodySmall).foregroundColor(AppColors.textPrimaryDark)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.error.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.error.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func formattedSLA(_ raw: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f.date(from: raw).map { $0.formatted(date: .long, time: .omitted) } ?? raw
    }
}
