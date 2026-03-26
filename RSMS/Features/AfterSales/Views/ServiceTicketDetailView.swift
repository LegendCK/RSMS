//
//  ServiceTicketDetailView.swift
//  RSMS
//
//  Detailed view of a service ticket with status timeline,
//  product info, photos, and status update controls.
//

import SwiftUI

fileprivate struct RepairEstimateLineDraft: Identifiable, Hashable {
    var id: UUID
    var title: String
    var amountText: String

    init(id: UUID = UUID(), title: String = "", amountText: String = "") {
        self.id = id
        self.title = title
        self.amountText = amountText
    }
}

@Observable
@MainActor
final class ServiceTicketDetailViewModel {
    var ticket: ServiceTicketDTO
    var isUpdatingStatus: Bool = false
    var errorMessage: String?
    var client: ClientDTO?
    var product: ProductDTO?
    var isLoadingDetails: Bool = false
    var showPartsSheet: Bool = false
    fileprivate var estimateDraftLines: [RepairEstimateLineDraft] = []
    var estimateTaxText: String = "0"
    var isSubmittingEstimate: Bool = false
    var isUpdatingApproval: Bool = false
    var showPickupSheet: Bool = false

    private let ticketService: ServiceTicketServiceProtocol
    private let catalogService: CatalogService
    private let clientService: ClientService

    init(
        ticket: ServiceTicketDTO,
        ticketService: ServiceTicketServiceProtocol,
        catalogService: CatalogService,
        clientService: ClientService
    ) {
        self.ticket = ticket
        self.ticketService = ticketService
        self.catalogService = catalogService
        self.clientService = clientService
        hydrateEstimateDraftFromTicket()
    }

    convenience init(ticket: ServiceTicketDTO) {
        self.init(
            ticket: ticket,
            ticketService: ServiceTicketService.shared,
            catalogService: CatalogService.shared,
            clientService: ClientService.shared
        )
    }

    func loadRelatedData() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        // Load client
        if let clientId = ticket.clientId {
            client = try? await clientService.fetchClient(id: clientId)
        }

        // Load product
        if let productId = ticket.productId {
            let products = (try? await catalogService.fetchProducts()) ?? []
            product = products.first { $0.id == productId }
        }
    }

    func refreshTicket() async {
        do {
            ticket = try await ticketService.fetchTicket(id: ticket.id)
        } catch {
            errorMessage = "Could not refresh ticket: \(error.localizedDescription)"
        }
    }

    func updateStatus(to newStatus: RepairStatus) async {
        if newStatus == .inProgress,
           ticket.hasRepairEstimate,
           ticket.clientApprovalStatus != .approved {
            errorMessage = "Repair cannot start until client approval is recorded."
            return
        }

        isUpdatingStatus = true
        errorMessage = nil
        do {
            try await ticketService.updateStatus(ticketId: ticket.id, status: newStatus.rawValue)
            ticket = try await ticketService.fetchTicket(id: ticket.id)
            hydrateEstimateDraftFromTicket()
        } catch {
            errorMessage = "Status update failed: \(error.localizedDescription)"
        }
        isUpdatingStatus = false
    }

    var estimateSubtotal: Double {
        estimateDraftLines.reduce(0) { $0 + parseAmount($1.amountText) }
    }

    var estimateTax: Double {
        parseAmount(estimateTaxText)
    }

    var estimateTotal: Double {
        estimateSubtotal + estimateTax
    }

    var canSendEstimate: Bool {
        !isSubmittingEstimate
        && estimateDraftLines.contains {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parseAmount($0.amountText) > 0
        }
    }

    func addEstimateLine() {
        estimateDraftLines.append(RepairEstimateLineDraft())
    }

    func addQuickLineItem(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let emptyIndex = estimateDraftLines.firstIndex(where: {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parseAmount($0.amountText) == 0
        }) {
            estimateDraftLines[emptyIndex].title = trimmed
            return
        }

        estimateDraftLines.append(RepairEstimateLineDraft(title: trimmed, amountText: ""))
    }

    func removeEstimateLine(id: UUID) {
        estimateDraftLines.removeAll { $0.id == id }
    }

    func sendEstimateForApproval() async {
        guard canSendEstimate else {
            errorMessage = "Add at least one valid estimate line before sending to client."
            return
        }

        isSubmittingEstimate = true
        errorMessage = nil
        defer { isSubmittingEstimate = false }

        let normalized = estimateDraftLines.compactMap { line -> RepairEstimateLineItem? in
            let title = line.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = parseAmount(line.amountText)
            guard !title.isEmpty, amount > 0 else { return nil }
            return RepairEstimateLineItem(id: line.id, title: title, amount: amount)
        }

        do {
            let notesLine = "Estimate sent to client at \(Date().formatted(date: .abbreviated, time: .shortened))."
            let updatedNotes = appendNote(base: ticket.notes, line: notesLine)

            ticket = try await ticketService.updateTicket(
                ticketId: ticket.id,
                patch: ServiceTicketUpdatePatch(
                    status: RepairStatus.estimatePending.rawValue,
                    notes: updatedNotes,
                    estimatedCost: estimateTotal,
                    finalCost: nil,
                    assignedTo: nil,
                    estimateBreakdown: normalized,
                    estimateSubtotal: estimateSubtotal,
                    estimateTax: estimateTax,
                    estimateTotal: estimateTotal,
                    estimateSentAt: Date(),
                    clientApprovalStatus: ClientApprovalStatus.pending.rawValue,
                    clientApprovedAt: nil,
                    clientRejectedAt: nil,
                    approvedEstimateSnapshot: nil
                )
            )
            hydrateEstimateDraftFromTicket()
        } catch {
            errorMessage = "Failed to send estimate: \(error.localizedDescription)"
        }
    }

    func recordClientApproval(_ status: ClientApprovalStatus) async {
        guard status == .approved || status == .rejected else { return }

        isUpdatingApproval = true
        errorMessage = nil
        defer { isUpdatingApproval = false }

        let approvedSnapshot: RepairEstimateSnapshot? = {
            guard status == .approved else { return nil }
            return RepairEstimateSnapshot(
                lines: ticket.estimateBreakdown ?? [],
                subtotal: ticket.estimateSubtotal ?? 0,
                tax: ticket.estimateTax ?? 0,
                total: ticket.estimateTotal ?? ticket.estimatedCost ?? 0,
                currency: ticket.currency,
                approvedAt: Date()
            )
        }()

        let approvalLine = status == .approved
            ? "Client approved estimate at \(Date().formatted(date: .abbreviated, time: .shortened))."
            : "Client rejected estimate at \(Date().formatted(date: .abbreviated, time: .shortened))."

        do {
            ticket = try await ticketService.updateTicket(
                ticketId: ticket.id,
                patch: ServiceTicketUpdatePatch(
                    status: status == .approved ? RepairStatus.estimateApproved.rawValue : RepairStatus.estimatePending.rawValue,
                    notes: appendNote(base: ticket.notes, line: approvalLine),
                    estimatedCost: ticket.estimateTotal ?? ticket.estimatedCost,
                    finalCost: nil,
                    assignedTo: nil,
                    estimateBreakdown: ticket.estimateBreakdown,
                    estimateSubtotal: ticket.estimateSubtotal,
                    estimateTax: ticket.estimateTax,
                    estimateTotal: ticket.estimateTotal,
                    estimateSentAt: ticket.estimateSentAt,
                    clientApprovalStatus: status.rawValue,
                    clientApprovedAt: status == .approved ? Date() : nil,
                    clientRejectedAt: status == .rejected ? Date() : nil,
                    approvedEstimateSnapshot: approvedSnapshot
                )
            )
            hydrateEstimateDraftFromTicket()
        } catch {
            errorMessage = "Failed to update client approval: \(error.localizedDescription)"
        }
    }

    private func hydrateEstimateDraftFromTicket() {
        if let breakdown = ticket.estimateBreakdown, !breakdown.isEmpty {
            estimateDraftLines = breakdown.map {
                RepairEstimateLineDraft(
                    id: $0.id,
                    title: $0.title,
                    amountText: Self.decimalFormatter.string(from: NSNumber(value: $0.amount)) ?? "\($0.amount)"
                )
            }
        } else if let estimate = ticket.estimatedCost, estimate > 0 {
            estimateDraftLines = [
                RepairEstimateLineDraft(
                    title: "Repair Service",
                    amountText: Self.decimalFormatter.string(from: NSNumber(value: estimate)) ?? "\(estimate)"
                )
            ]
        } else {
            estimateDraftLines = [RepairEstimateLineDraft(title: "", amountText: "")]
        }

        let tax = ticket.estimateTax ?? 0
        estimateTaxText = Self.decimalFormatter.string(from: NSNumber(value: tax)) ?? "0"
    }

    private func parseAmount(_ value: String) -> Double {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }

    private func appendNote(base: String?, line: String) -> String {
        let existing = (base ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty { return line }
        return existing + "\n" + line
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var nextStatuses: [RepairStatus] {
        switch ticket.ticketStatus {
        case .intake:
            return [.inProgress, .cancelled]
        case .inProgress:
            return [.completed, .cancelled]
        case .estimatePending:
            return [.cancelled]
        case .estimateApproved:
            return [.inProgress, .completed]
        case .completed, .cancelled:
            return []
        }
    }
}

@MainActor
struct ServiceTicketDetailView: View {
    @State private var vm: ServiceTicketDetailViewModel
    @Environment(AppState.self) private var appState
    
    @State private var showCompleteConfirmation = false
    @State private var showCompletionToast = false

    /// Whether this is shown to a customer (read-only status)
    var isCustomerView: Bool = false

    init(ticket: ServiceTicketDTO, isCustomerView: Bool = false) {
        self._vm = State(initialValue: ServiceTicketDetailViewModel(ticket: ticket))
        self.isCustomerView = isCustomerView
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                headerCard
                statusTimelineCard
                if vm.client != nil { clientCard }
                if vm.product != nil { productCard }
                detailsCard
                estimateCard
                if let photos = vm.ticket.intakePhotos, !photos.isEmpty {
                    photosCard(photos)
                }
                if !isCustomerView && !vm.nextStatuses.isEmpty {
                    actionsCard
                }
                if let error = vm.errorMessage {
                    errorBanner(error)
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(vm.ticket.displayTicketNumber)
                    .font(AppTypography.navTitle)
                    .foregroundColor(.primary)
            }
        }
        .task { await vm.loadRelatedData() }
        .refreshable { await vm.refreshTicket() }
        .sheet(isPresented: $vm.showPartsSheet) {
            TicketPartsView(
                ticketId: vm.ticket.id,
                storeId: vm.ticket.storeId,
                allocatedByUserId: appState.currentUserProfile?.id
            )
        }
        .sheet(isPresented: $vm.showPickupSheet) {
            TicketPickupView(
                vm: TicketPickupViewModel(
                    ticket: vm.ticket,
                    client: vm.client,
                    product: vm.product,
                    parts: [],          // parts loaded separately inside TicketPickupViewModel if needed
                    storeName: appState.currentUserProfile?.storeId != nil ? "Boutique" : "Store",
                    storeAddress: nil,
                    specialistName: appState.currentUserProfile?.fullName ?? "Specialist",
                    currentUserId: appState.currentUserProfile?.id
                )
            )
        }
        .confirmationDialog(
            "Are you sure you want to mark this repair as completed?",
            isPresented: $showCompleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm", role: .none) {
                Task {
                    await vm.updateStatus(to: .completed)
                    if vm.errorMessage == nil {
                        // Flash the success toast to simulate client notification
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showCompletionToast = true
                        }
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation {
                            showCompletionToast = false
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if showCompletionToast {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppColors.accent)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Client Notified")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Your product is ready for pickup! Visit the boutique for handover.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 15, x: 0, y: 8)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Cards

private extension ServiceTicketDetailView {

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status accent strip
            HStack(spacing: 6) {
                Circle()
                    .fill(vm.ticket.ticketStatus.statusColor)
                    .frame(width: 6, height: 6)
                Text(vm.ticket.ticketStatus.displayName.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(vm.ticket.ticketStatus.statusColor)
                Spacer()
                if vm.ticket.isOverdue {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("OVERDUE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                    }
                    .foregroundStyle(AppColors.error)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, 10)
            .background(vm.ticket.ticketStatus.statusColor.opacity(0.10))

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.ticket.displayTicketNumber)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("Created \(vm.ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Label(vm.ticket.ticketType.displayName, systemImage: vm.ticket.ticketType.icon)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.cardPadding)
        }
        .ticketCardStyle()
    }

    var statusTimelineCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Status Timeline", systemImage: "list.bullet.clipboard")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(RepairStatus.allCases.enumerated()), id: \.element.id) { index, status in
                    let isCurrent = vm.ticket.ticketStatus == status
                    let isPast = statusOrder(vm.ticket.ticketStatus) > statusOrder(status)

                    HStack(spacing: 14) {
                        VStack(spacing: 0) {
                            if isPast {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(status.statusColor)
                            } else if isCurrent {
                                ZStack {
                                    Circle()
                                        .fill(status.statusColor.opacity(0.15))
                                        .frame(width: 30, height: 30)
                                    Circle()
                                        .fill(status.statusColor)
                                        .frame(width: 16, height: 16)
                                }
                            } else {
                                Circle()
                                    .stroke(Color(.systemGray4), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }

                            if index < RepairStatus.allCases.count - 1 {
                                Rectangle()
                                    .fill(isPast ? status.statusColor.opacity(0.35) : Color(.systemGray5))
                                    .frame(width: 1.5, height: isCurrent ? 28 : 20)
                            }
                        }
                        .frame(width: 30)

                        HStack {
                            Text(status.displayName)
                                .font(isCurrent ? .system(size: 15, weight: .semibold) : AppTypography.bodySmall)
                                .foregroundStyle(isPast || isCurrent ? .primary : .secondary)
                            Spacer()
                            if isCurrent {
                                Text("Current")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(status.statusColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(status.statusColor.opacity(0.12)))
                            }
                        }
                        .padding(.vertical, isCurrent ? 5 : 0)
                    }
                    .padding(.vertical, AppSpacing.xxs)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .ticketCardStyle()
    }

    var clientCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Client", systemImage: "person.circle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            if let client = vm.client {
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle().fill(AppColors.accent.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Text(client.initials)
                            .font(AppTypography.avatarSmall)
                            .foregroundColor(AppColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.fullName)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.primary)
                        Text(client.email)
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                        if let phone = client.phone {
                            Text(phone)
                                .font(AppTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .ticketCardStyle()
    }

    var productCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Product", systemImage: "shippingbox")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            if let product = vm.product {
                HStack(spacing: AppSpacing.sm) {
                    if let raw = product.primaryImageUrl {
                        ProductArtworkView(imageSource: raw, fallbackSymbol: "shippingbox.fill", cornerRadius: 10)
                            .frame(width: 56, height: 56)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray5))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "shippingbox.fill")
                                    .foregroundColor(.secondary)
                            )
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        if let brand = product.brand {
                            Text(brand.uppercased())
                                .font(AppTypography.nano)
                                .tracking(1.2)
                                .foregroundColor(AppColors.accent)
                        }
                        Text(product.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.primary)
                        Text("SKU: \(product.sku)")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                        Text(product.formattedPrice)
                            .font(AppTypography.priceCompact)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .ticketCardStyle()
    }

    var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Details", systemImage: "doc.text")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                if let condition = vm.ticket.conditionNotes, !condition.isEmpty {
                    detailRow(title: "Condition", value: condition)
                    Divider().padding(.leading, 12)
                }
                if let notes = vm.ticket.notes, !notes.isEmpty {
                    detailRow(title: "Notes", value: notes)
                    Divider().padding(.leading, 12)
                }
                if let cost = vm.ticket.estimatedCost {
                    detailRow(title: "Est. Cost", value: "INR \(String(format: "%.2f", cost))")
                    Divider().padding(.leading, 12)
                }
                if let finalCost = vm.ticket.finalCost {
                    detailRow(title: "Final Cost", value: "INR \(String(format: "%.2f", finalCost))")
                    Divider().padding(.leading, 12)
                }
                detailRow(title: "Approval", value: vm.ticket.clientApprovalStatus.displayName)
                if let sla = vm.ticket.slaDueDate {
                    Divider().padding(.leading, 12)
                    detailRow(title: "SLA Due", value: sla)
                }
                Divider().padding(.leading, 12)
                detailRow(title: "Updated", value: vm.ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(AppSpacing.cardPadding)
        .ticketCardStyle()
    }

    var estimateCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Label("Repair Estimate", systemImage: "wrench")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                approvalPill(vm.ticket.clientApprovalStatus)
            }

            if isCustomerView {
                readOnlyEstimateBreakdown
            } else {
                editableEstimateBreakdown
            }
        }
        .padding(AppSpacing.cardPadding)
        .ticketCardStyle()
    }

    var readOnlyEstimateBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let lines = vm.ticket.estimateBreakdown, !lines.isEmpty {
                ForEach(lines) { line in
                    HStack {
                        Text(line.title)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(currency(line.amount))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(.primary)
                    }
                }
            } else {
                Text("Estimate is not yet shared.")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Text("Total")
                    .font(AppTypography.label)
                    .foregroundColor(.primary)
                Spacer()
                Text(currency(vm.ticket.estimateTotal ?? vm.ticket.estimatedCost ?? 0))
                    .font(AppTypography.label)
                    .foregroundColor(.primary)
            }
        }
    }

    var editableEstimateBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Quick Add")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(commonEstimateLineItems, id: \.self) { option in
                            Button {
                                vm.addQuickLineItem(title: option)
                            } label: {
                                Text(option)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.accent)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.accent.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ForEach(vm.estimateDraftLines.indices, id: \.self) { index in
                HStack(spacing: AppSpacing.xs) {
                    TextField(
                        "Line item",
                        text: Binding(
                            get: { vm.estimateDraftLines[index].title },
                            set: { vm.estimateDraftLines[index].title = $0 }
                        )
                    )
                    .textInputAutocapitalization(.words)
                    .font(AppTypography.bodySmall)

                    TextField(
                        "Amount",
                        text: Binding(
                            get: { vm.estimateDraftLines[index].amountText },
                            set: { vm.estimateDraftLines[index].amountText = $0 }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .font(AppTypography.bodySmall)

                    Button {
                        let id = vm.estimateDraftLines[index].id
                        vm.removeEstimateLine(id: id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(AppColors.error)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.estimateDraftLines.count <= 1)
                }
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .fill(Color(.systemGray6))
                )
            }

            Button {
                vm.addEstimateLine()
            } label: {
                Label("Add Line Item", systemImage: "plus")
                    .font(AppTypography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppColors.accent)

            HStack {
                Text("Tax")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("0", text: $vm.estimateTaxText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .font(AppTypography.bodySmall)
            }

            Divider()

            summaryRow(title: "Subtotal", amount: vm.estimateSubtotal, emphasize: false)
            summaryRow(title: "Tax", amount: vm.estimateTax, emphasize: false)
            summaryRow(title: "Total", amount: vm.estimateTotal, emphasize: true)

            Button {
                Task { await vm.sendEstimateForApproval() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if vm.isSubmittingEstimate {
                        ProgressView().tint(.white)
                    }
                    Text(vm.ticket.estimateSentAt == nil ? "Send Estimate For Approval" : "Resend Estimate For Approval")
                        .font(AppTypography.buttonSecondary)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.accent)
                )
                .opacity(vm.canSendEstimate ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSendEstimate)

            HStack(spacing: AppSpacing.xs) {
                Button {
                    Task { await vm.recordClientApproval(.approved) }
                } label: {
                    Text("Mark Approved")
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .fill(AppColors.success)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await vm.recordClientApproval(.rejected) }
                } label: {
                    Text("Mark Rejected")
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .fill(AppColors.error)
                        )
                }
                .buttonStyle(.plain)
            }
            .opacity((vm.ticket.estimateSentAt != nil && !vm.isUpdatingApproval) ? 1 : 0.45)
            .disabled(vm.ticket.estimateSentAt == nil || vm.isUpdatingApproval)

            if vm.ticket.hasRepairEstimate && vm.ticket.clientApprovalStatus != .approved {
                Text("Repairs are blocked until approval is recorded as Approved.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.warning)
            }
        }
    }

    func photosCard(_ photos: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Intake Photos", systemImage: "photo.stack")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.xs) {
                ForEach(Array(photos.enumerated()), id: \.offset) { _, photoPath in
                    let url = resolvePhotoURL(photoPath)
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                        case .failure:
                            placeholderPhoto
                        default:
                            ProgressView()
                                .frame(height: 100)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .ticketCardStyle()
    }

    var placeholderPhoto: some View {
        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
            .fill(Color(.systemGray5))
            .frame(height: 100)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            )
    }

    var actionsCard: some View {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("Update Status", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                if vm.nextStatuses.contains(.completed) {
                    Button {
                        showCompleteConfirmation = true
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            if vm.isUpdatingStatus {
                                ProgressView().tint(.white)
                            }
                            Image(systemName: "checkmark.seal.fill")
                            Text("Mark as Completed")
                                .font(AppTypography.buttonSecondary)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .fill(AppColors.success)
                        )
                        .opacity(statusActionDisabled(.completed) ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isUpdatingStatus || statusActionDisabled(.completed))
                    .padding(.bottom, 4)
                }

                ForEach(vm.nextStatuses.filter { $0 != .completed }) { status in
                    Button {
                        Task { await vm.updateStatus(to: status) }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            if vm.isUpdatingStatus {
                                ProgressView().tint(.white)
                            }
                            Circle()
                                .fill(status.statusColor)
                                .frame(width: 8, height: 8)
                            Text("Move to \(status.displayName)")
                                .font(AppTypography.buttonSecondary)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .fill(status == .cancelled ? AppColors.error : AppColors.accent)
                        )
                        .opacity(statusActionDisabled(status) ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isUpdatingStatus || statusActionDisabled(status))
                }

                if vm.ticket.hasRepairEstimate && vm.ticket.clientApprovalStatus != .approved {
                    Text("Cannot move to In Progress until estimate is approved by client.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.warning)
                }

                if vm.ticket.ticketStatus == .estimatePending {
                    Text("Use the estimate approval controls above to mark Approved or Rejected.")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }

                // ── Spare Parts ──────────────────────────────────────────────
                Button {
                    vm.showPartsSheet = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                        Text("Manage Spare Parts")
                            .font(AppTypography.buttonSecondary)
                    }
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(AppColors.accent, lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)

                // ── Pickup & Handover ────────────────────────────────────────
                if vm.ticket.ticketStatus == .completed {
                    VStack(spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(AppColors.success)
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Repair Completed")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(.primary)
                                    .fontWeight(.bold)
                                Text("Completed on: \(vm.ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.success.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))

                        Button {
                            vm.showPickupSheet = true
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "shippingbox.fill")
                                Text("Schedule Pickup & Handover")
                                    .font(AppTypography.buttonSecondary)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .fill(AppColors.success)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .ticketCardStyle(cornerRadius: AppSpacing.radiusMedium)
        }

    // MARK: - Helpers

    func statusBadge(_ status: RepairStatus) -> some View {
        Text(status.displayName.uppercased())
            .font(AppTypography.nano)
            .tracking(0.8)
            .foregroundColor(status.statusColor)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 4)
            .background(Capsule().fill(status.statusColor.opacity(0.14)))
    }

    func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
    }

    func approvalPill(_ status: ClientApprovalStatus) -> some View {
        Text(status.displayName.uppercased())
            .font(AppTypography.nano)
            .foregroundColor(status.color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 4)
            .background(Capsule().fill(status.color.opacity(0.15)))
    }

    func summaryRow(title: String, amount: Double, emphasize: Bool) -> some View {
        HStack {
            Text(title)
                .font(emphasize ? AppTypography.label : AppTypography.caption)
                .foregroundColor(.primary)
            Spacer()
            Text(currency(amount))
                .font(emphasize ? AppTypography.label : AppTypography.caption)
                .foregroundColor(.primary)
        }
    }

    func currency(_ amount: Double) -> String {
        "INR \(String(format: "%.2f", amount))"
    }

    func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.error.opacity(0.1))
        )
    }

    func statusOrder(_ status: RepairStatus) -> Int {
        switch status {
        case .intake: return 0
        case .inProgress: return 1
        case .estimatePending: return 2
        case .estimateApproved: return 3
        case .completed: return 4
        case .cancelled: return 5
        }
    }

    func statusActionDisabled(_ status: RepairStatus) -> Bool {
        status == .inProgress && vm.ticket.hasRepairEstimate && vm.ticket.clientApprovalStatus != .approved
    }

    var commonEstimateLineItems: [String] {
        [
            "Diagnostic Inspection",
            "Labor Charge",
            "Spare Part",
            "Polishing and Cleaning",
            "Pickup and Delivery"
        ]
    }

    func resolvePhotoURL(_ path: String) -> URL? {
        let value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: value), url.scheme != nil { return url }

        let base = SupabaseConfig.projectURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if value.hasPrefix("service-ticket-photos/") {
            return URL(string: "\(base)/storage/v1/object/public/\(value)")
        }
        return URL(string: "\(base)/storage/v1/object/public/\(value)")
    }
}

private extension View {
    func ticketCardStyle(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.6)
            )
    }
}
