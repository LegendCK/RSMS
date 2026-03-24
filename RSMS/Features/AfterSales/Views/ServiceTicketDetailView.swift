//
//  ServiceTicketDetailView.swift
//  RSMS
//
//  Detailed view of a service ticket with status timeline,
//  product info, photos, and status update controls.
//

import SwiftUI

@Observable
@MainActor
final class ServiceTicketDetailViewModel {
    var ticket: ServiceTicketDTO
    var isUpdatingStatus: Bool = false
    var errorMessage: String?
    var client: ClientDTO?
    var product: ProductDTO?
    var isLoadingDetails: Bool = false

    private let ticketService: ServiceTicketServiceProtocol
    private let catalogService: CatalogService
    private let clientService: ClientService

    init(
        ticket: ServiceTicketDTO,
        ticketService: ServiceTicketServiceProtocol = ServiceTicketService.shared,
        catalogService: CatalogService = CatalogService.shared,
        clientService: ClientService = ClientService.shared
    ) {
        self.ticket = ticket
        self.ticketService = ticketService
        self.catalogService = catalogService
        self.clientService = clientService
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
        isUpdatingStatus = true
        errorMessage = nil
        do {
            try await ticketService.updateStatus(ticketId: ticket.id, status: newStatus.rawValue)
            ticket = try await ticketService.fetchTicket(id: ticket.id)
        } catch {
            errorMessage = "Status update failed: \(error.localizedDescription)"
        }
        isUpdatingStatus = false
    }

    var nextStatuses: [RepairStatus] {
        switch ticket.ticketStatus {
        case .intake:
            return [.inProgress, .estimatePending, .cancelled]
        case .inProgress:
            return [.estimatePending, .completed, .cancelled]
        case .estimatePending:
            return [.estimateApproved, .cancelled]
        case .estimateApproved:
            return [.inProgress, .completed]
        case .completed, .cancelled:
            return []
        }
    }
}

struct ServiceTicketDetailView: View {
    @State private var vm: ServiceTicketDetailViewModel
    @Environment(AppState.self) private var appState

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
    }
}

// MARK: - Cards

private extension ServiceTicketDetailView {

    var headerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.ticket.displayTicketNumber)
                        .font(AppTypography.heading1)
                        .foregroundColor(.primary)
                    Text("Created \(vm.ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                statusBadge(vm.ticket.ticketStatus)
            }

            HStack(spacing: AppSpacing.sm) {
                Label(vm.ticket.ticketType.displayName, systemImage: vm.ticket.ticketType.icon)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.primary)
                if vm.ticket.isOverdue {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("OVERDUE")
                    }
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.error)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    var statusTimelineCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("STATUS TIMELINE")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(RepairStatus.allCases.enumerated()), id: \.element.id) { index, status in
                    let isCurrent = vm.ticket.ticketStatus == status
                    let isPast = statusOrder(vm.ticket.ticketStatus) >= statusOrder(status)

                    HStack(spacing: AppSpacing.sm) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(isPast ? status.statusColor : Color(.systemGray4))
                                .frame(width: isCurrent ? 16 : 10, height: isCurrent ? 16 : 10)
                                .overlay {
                                    if isCurrent {
                                        Circle().stroke(status.statusColor.opacity(0.3), lineWidth: 3)
                                            .frame(width: 22, height: 22)
                                    }
                                }

                            if index < RepairStatus.allCases.count - 1 {
                                Rectangle()
                                    .fill(isPast ? status.statusColor.opacity(0.4) : Color(.systemGray5))
                                    .frame(width: 2, height: 24)
                            }
                        }
                        .frame(width: 24)

                        Text(status.displayName)
                            .font(isCurrent ? AppTypography.label : AppTypography.bodySmall)
                            .foregroundColor(isPast ? .primary : .secondary)
                            .fontWeight(isCurrent ? .semibold : .regular)

                        Spacer()

                        if isCurrent {
                            Text("Current")
                                .font(AppTypography.nano)
                                .foregroundColor(status.statusColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(status.statusColor.opacity(0.14)))
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    var clientCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CLIENT")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    var productCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PRODUCT")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("DETAILS")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

            if let condition = vm.ticket.conditionNotes, !condition.isEmpty {
                detailRow(title: "Condition", value: condition)
            }
            if let notes = vm.ticket.notes, !notes.isEmpty {
                detailRow(title: "Notes", value: notes)
            }
            if let cost = vm.ticket.estimatedCost {
                detailRow(title: "Estimated Cost", value: "INR \(String(format: "%.2f", cost))")
            }
            if let finalCost = vm.ticket.finalCost {
                detailRow(title: "Final Cost", value: "INR \(String(format: "%.2f", finalCost))")
            }
            if let sla = vm.ticket.slaDueDate {
                detailRow(title: "SLA Due", value: sla)
            }
            detailRow(title: "Last Updated", value: vm.ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    func photosCard(_ photos: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("INTAKE PHOTOS")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
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
            Text("UPDATE STATUS")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

            ForEach(vm.nextStatuses) { status in
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
                }
                .buttonStyle(.plain)
                .disabled(vm.isUpdatingStatus)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
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
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
