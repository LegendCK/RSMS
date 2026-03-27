import SwiftUI

struct MyExchangeRequestsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var tickets: [ServiceTicketDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadTask: Task<Void, Never>?
    @State private var pollingTask: Task<Void, Never>?

    private var exchangeTickets: [ServiceTicketDTO] {
        tickets.filter { ticket in
            let notes = (ticket.notes ?? "").lowercased()
            return ticket.type == RepairType.warrantyClaim.rawValue
                || notes.contains("exchange")
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if isLoading && exchangeTickets.isEmpty {
                ProgressView("Loading exchange requests...")
                    .tint(AppColors.accent)
            } else if let errorMessage, exchangeTickets.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.warning)
                    Text("Unable to load requests")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            } else if exchangeTickets.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(AppColors.accent)
                    Text("No exchange requests yet")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("Submit from any order detail page.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(exchangeTickets) { ticket in
                            requestRow(ticket)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
                .refreshable { await loadTickets() }
            }
        }
        .navigationTitle("My Exchange Requests")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadTask?.cancel()
            loadTask = Task { await loadTickets() }
        }
        .task {
            pollingTask?.cancel()
            pollingTask = Task { await startPolling() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            loadTask?.cancel()
            loadTask = Task { await loadTickets() }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    private func requestRow(_ ticket: ServiceTicketDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(ticket.displayTicketNumber)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text(exchangeStatusDisplayName(for: ticket.status).uppercased())
                    .font(AppTypography.nano)
                    .tracking(1.1)
                    .foregroundColor(exchangeStatusColor(for: ticket.status))
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(exchangeStatusColor(for: ticket.status).opacity(0.14), in: Capsule())
            }

            Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            if let notes = ticket.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(3)
            }

            if ticket.assignedTo != nil {
                Text("Assigned to after-sales specialist")
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.success)
            } else {
                Text("Waiting for specialist pickup")
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.warning)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .fill(AppColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @MainActor
    private func loadTickets() async {
        guard !Task.isCancelled else { return }
        guard !isLoading else { return }
        guard !appState.isGuest,
              let clientId = appState.currentUserProfile?.id ?? appState.currentClientProfile?.id else {
            tickets = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tickets = try await ServiceTicketService.shared.fetchTickets(clientId: clientId)
            loadTask = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            loadTask = nil
        }
    }

    private func startPolling() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(20))
            guard scenePhase == .active else { continue }
            await loadTickets()
        }
        pollingTask = nil
    }

    private func exchangeStatusDisplayName(for raw: String) -> String {
        switch canonicalExchangeStatus(raw) {
        case "intake": return "Intake"
        case "estimate_pending": return "Estimate Pending"
        case "estimate_approved": return "Approved"
        case "in_progress": return "In Progress"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        default:
            let normalized = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: " ")
            if normalized.isEmpty { return "Unknown" }
            return normalized.capitalized
        }
    }

    private func exchangeStatusColor(for raw: String) -> Color {
        switch canonicalExchangeStatus(raw) {
        case "intake", "estimate_pending": return AppColors.warning
        case "estimate_approved", "in_progress": return AppColors.accent
        case "completed": return AppColors.success
        case "cancelled": return AppColors.error
        default: return AppColors.textSecondaryDark
        }
    }

    private func canonicalExchangeStatus(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "new", "open", "submitted", "intake": return "intake"
        case "estimate_pending", "awaiting_estimate", "pending_estimate": return "estimate_pending"
        case "estimate_approved", "approved", "approval_done": return "estimate_approved"
        case "in_progress", "processing", "assigned", "working": return "in_progress"
        case "completed", "resolved", "closed", "done": return "completed"
        case "cancelled", "canceled", "rejected": return "cancelled"
        default: return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
}
