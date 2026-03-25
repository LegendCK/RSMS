//
//  CorporateAdminClientActivityView.swift
//  RSMS
//
//  Dedicated client-portal monitoring workflow for corporate admins.
//  Covers orders, reservations, returns, fulfillment visibility, live sync,
//  and online vs in-store reporting.
//

import SwiftUI

private enum AdminActivityTab: String, CaseIterable, Identifiable {
    case orders = "Orders"
    case reservations = "Reservations"
    case returns = "Returns"

    var id: String { rawValue }
}

private struct AdminActivityShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct CorporateAdminClientActivityView: View {
    @Environment(AppState.self) private var appState
    @State private var snapshot: AdminInsightsSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab: AdminActivityTab = .orders
    @State private var searchText = ""
    @State private var shareFile: AdminActivityShareFile?
    @State private var exportErrorMessage = ""
    @State private var showExportError = false
    @State private var lastSyncedAt: Date?

    private var generatedBy: String {
        appState.currentUserName.isEmpty ? "Corporate Admin" : appState.currentUserName
    }

    private var storesById: [UUID: StoreDTO] {
        Dictionary(uniqueKeysWithValues: (snapshot?.stores ?? []).map { ($0.id, $0) })
    }

    private var clientsById: [UUID: ClientDTO] {
        Dictionary(uniqueKeysWithValues: (snapshot?.clients ?? []).map { ($0.id, $0) })
    }

    private var portalOrders: [OrderDTO] {
        (snapshot?.orders ?? []).filter {
            let channel = $0.channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return channel == "online" || channel == "bopis" || channel == "ship_from_store"
        }
    }

    private var reservations: [ReservationDTO] {
        snapshot?.reservations ?? []
    }

    private var returnTickets: [ServiceTicketDTO] {
        (snapshot?.serviceTickets ?? []).filter {
            let normalizedType = $0.type.lowercased()
            return normalizedType.contains("warranty") || normalizedType.contains("repair") || normalizedType.contains("authentication") || normalizedType.contains("valuation")
        }
    }

    private var activePortalOrders: [OrderDTO] {
        portalOrders.filter {
            let status = normalizedLabel($0.status).lowercased()
            return status != "completed" && status != "delivered" && status != "cancelled"
        }
    }

    private var activeReservationsCount: Int {
        reservations.filter { normalizedLabel($0.status).lowercased() != "expired" }.count
    }

    private var openReturnsCount: Int {
        returnTickets.filter {
            let status = normalizedLabel($0.status).lowercased()
            return status != "completed" && status != "cancelled"
        }.count
    }

    private var onlineRevenue: Double {
        portalOrders.reduce(0) { $0 + $1.grandTotal }
    }

    private var inStoreRevenue: Double {
        (snapshot?.orders ?? []).filter { $0.channel.lowercased() == "in_store" }.reduce(0) { $0 + $1.grandTotal }
    }

    private var filteredOrders: [OrderDTO] {
        let query = normalizedLabel(searchText).lowercased()
        guard !query.isEmpty else { return portalOrders }
        return portalOrders.filter { order in
            let client = order.clientId.flatMap { clientsById[$0] }
            let store = storesById[order.storeId]
            return [
                order.orderNumber ?? "",
                order.channel,
                order.status,
                client?.fullName ?? "",
                client?.email ?? "",
                store?.name ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    private var filteredReservations: [ReservationDTO] {
        let query = normalizedLabel(searchText).lowercased()
        guard !query.isEmpty else { return reservations }
        return reservations.filter { reservation in
            let client = clientsById[reservation.clientId]
            let store = reservation.storeId.flatMap { storesById[$0] }
            return [
                reservation.product?.name ?? "",
                reservation.status,
                client?.fullName ?? "",
                client?.email ?? "",
                store?.name ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    private var filteredReturns: [ServiceTicketDTO] {
        let query = normalizedLabel(searchText).lowercased()
        guard !query.isEmpty else { return returnTickets }
        return returnTickets.filter { ticket in
            let client = ticket.clientId.flatMap { clientsById[$0] }
            let store = storesById[ticket.storeId]
            return [
                ticket.displayTicketNumber,
                ticket.type,
                ticket.status,
                client?.fullName ?? "",
                client?.email ?? "",
                store?.name ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    private var fulfillmentRows: [AdminFulfillmentRow] {
        let grouped = Dictionary(grouping: activePortalOrders, by: \.storeId)
        return grouped.map { storeId, orders in
            let store = storesById[storeId]
            let statuses = Dictionary(grouping: orders, by: { normalizedLabel($0.status) }).mapValues(\.count)
            return AdminFulfillmentRow(
                id: storeId,
                storeName: store?.name ?? "Unknown Store",
                location: [store?.city, store?.region].compactMap { $0 }.joined(separator: ", "),
                totalOrders: orders.count,
                pending: statuses["Pending"] ?? 0,
                processing: statuses["Processing"] ?? 0,
                confirmed: statuses["Confirmed"] ?? 0,
                shipped: statuses["Shipped"] ?? 0
            )
        }
        .sorted { $0.totalOrders > $1.totalOrders }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if let snapshot {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        syncBanner
                        summaryGrid
                        channelComparisonCard(snapshot: snapshot)
                        fulfillmentCard
                        filterTabs
                        searchBar
                        contentSection
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
                .refreshable {
                    await loadSnapshot()
                }
            } else if isLoading {
                ProgressView("Loading client activity...")
                    .tint(AppColors.accent)
            } else {
                ContentUnavailableView(
                    "No Live Activity Yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text(errorMessage ?? "Refresh the admin snapshot to load customer portal activity.")
                )
            }
        }
        .navigationTitle("Client Activity")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search orders, reservations, returns")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    Task { await loadSnapshot() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(AppColors.accent)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColors.accent)
                    }
                }

                Button {
                    Task { await exportChannelReport() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppColors.accent)
                }
                .disabled(snapshot == nil || isLoading)
            }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .task {
            if snapshot == nil {
                await loadSnapshot()
            }
        }
    }

    private var syncBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LIVE PORTAL MONITOR")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Text(syncStatusText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            Text(isLoading ? "Syncing" : "Connected")
                .font(AppTypography.micro)
                .foregroundColor(isLoading ? AppColors.info : AppColors.success)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 4)
                .background((isLoading ? AppColors.info : AppColors.success).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            summaryCard(title: "Portal Orders", value: "\(portalOrders.count)", subtitle: "\(activePortalOrders.count) active", color: AppColors.accent)
            summaryCard(title: "Reservations", value: "\(reservations.count)", subtitle: "\(activeReservationsCount) active", color: AppColors.info)
            summaryCard(title: "Returns", value: "\(returnTickets.count)", subtitle: "\(openReturnsCount) open", color: AppColors.warning)
            summaryCard(title: "Fulfillment", value: "\(fulfillmentRows.count)", subtitle: "stores involved", color: AppColors.success)
        }
    }

    private func summaryCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Text(value)
                .font(AppTypography.heading2)
                .foregroundColor(color)
            Text(subtitle)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func channelComparisonCard(snapshot: AdminInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("ONLINE VS IN-STORE")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Spacer()
                Text("Report Ready")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            HStack(spacing: AppSpacing.sm) {
                comparisonColumn(title: "Online / Omnichannel", orders: portalOrders.count, revenue: onlineRevenue, color: AppColors.accent)
                comparisonColumn(title: "In-Store", orders: snapshot.orders.filter { $0.channel.lowercased() == "in_store" }.count, revenue: inStoreRevenue, color: AppColors.success)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
    }

    private func comparisonColumn(title: String, orders: Int, revenue: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Text("\(orders) orders")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(formatCurrency(revenue))
                .font(AppTypography.bodyMedium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(color.opacity(0.08))
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private var fulfillmentCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("STORE FULFILLMENT STATUS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            if fulfillmentRows.isEmpty {
                Text("No active portal fulfillment records found yet.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                ForEach(fulfillmentRows) { row in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.storeName)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                if !row.location.isEmpty {
                                    Text(row.location)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                            Spacer()
                            Text("\(row.totalOrders) orders")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.accent)
                        }

                        HStack(spacing: AppSpacing.xs) {
                            miniStatusPill("Pending \(row.pending)", color: AppColors.warning)
                            miniStatusPill("Processing \(row.processing)", color: AppColors.info)
                            miniStatusPill("Confirmed \(row.confirmed)", color: AppColors.success)
                            miniStatusPill("Shipped \(row.shipped)", color: AppColors.accent)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundPrimary)
                    .cornerRadius(AppSpacing.radiusMedium)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
    }

    private func miniStatusPill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(AppTypography.micro)
            .foregroundColor(color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var filterTabs: some View {
        Picker("Activity Type", selection: $selectedTab) {
            ForEach(AdminActivityTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondaryDark)
            TextField("Search current activity tab", text: $searchText)
                .font(AppTypography.bodyMedium)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .orders:
            activityCard(title: "CLIENT PORTAL ORDERS") {
                if filteredOrders.isEmpty {
                    emptySection("No portal orders match the current filter.")
                } else {
                    ForEach(filteredOrders) { order in
                        orderRow(order)
                    }
                }
            }
        case .reservations:
            activityCard(title: "RESERVATIONS") {
                if filteredReservations.isEmpty {
                    emptySection("No reservations match the current filter.")
                } else {
                    ForEach(filteredReservations) { reservation in
                        reservationRow(reservation)
                    }
                }
            }
        case .returns:
            activityCard(title: "RETURNS / AFTER-SALES") {
                if filteredReturns.isEmpty {
                    emptySection("No return or after-sales records match the current filter.")
                } else {
                    ForEach(filteredReturns) { ticket in
                        returnRow(ticket)
                    }
                }
            }
        }
    }

    private func activityCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
    }

    private func emptySection(_ message: String) -> some View {
        Text(message)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacing.sm)
    }

    private func orderRow(_ order: OrderDTO) -> some View {
        let client = order.clientId.flatMap { clientsById[$0] }
        let store = storesById[order.storeId]
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(order.orderNumber ?? "Order")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                statusBadge(channelLabel(for: order.channel), color: channelColor(for: order.channel))
                statusBadge(normalizedLabel(order.status), color: statusColor(for: order.status))
            }
            Text(client?.fullName ?? "Guest Customer")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
            HStack {
                Text(store?.name ?? "Unknown Store")
                Spacer()
                Text(order.formattedTotal)
            }
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func reservationRow(_ reservation: ReservationDTO) -> some View {
        let client = clientsById[reservation.clientId]
        let store = reservation.storeId.flatMap { storesById[$0] }
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(reservation.product?.name ?? "Reserved Item")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                statusBadge(normalizedLabel(reservation.status), color: reservationStatusColor(for: reservation.status))
            }
            Text(client?.fullName ?? "Client")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
            HStack {
                Text(store?.name ?? "No store assigned")
                Spacer()
                Text("Expires \(reservation.expiresAt.formatted(date: .abbreviated, time: .shortened))")
            }
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func returnRow(_ ticket: ServiceTicketDTO) -> some View {
        let client = ticket.clientId.flatMap { clientsById[$0] }
        let store = storesById[ticket.storeId]
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(ticket.displayTicketNumber)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                statusBadge(normalizedLabel(ticket.type), color: AppColors.warning)
                statusBadge(ticket.ticketStatus.displayName, color: ticket.ticketStatus.statusColor)
            }
            Text(client?.fullName ?? "Client")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
            HStack {
                Text(store?.name ?? "Unknown Store")
                Spacer()
                Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(AppTypography.micro)
            .foregroundColor(color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var syncStatusText: String {
        guard let lastSyncedAt else { return "Waiting for first sync from the client portal." }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Last synced \(formatter.localizedString(for: lastSyncedAt, relativeTo: Date()))."
    }

    @MainActor
    private func loadSnapshot() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let freshSnapshot = try await AdminInsightsService.shared.fetchLatestSnapshot()
            snapshot = freshSnapshot
            lastSyncedAt = freshSnapshot.syncedAt
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func exportChannelReport() async {
        guard let snapshot else { return }
        do {
            let fileURL = try AdminReportExportService.exportChannelComparisonCSV(
                snapshot: snapshot,
                generatedBy: generatedBy
            )
            shareFile = AdminActivityShareFile(url: fileURL)
        } catch {
            exportErrorMessage = "Could not export channel report: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func normalizedLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }

    private func channelLabel(for channel: String) -> String {
        switch channel.lowercased() {
        case "online": return "Online"
        case "bopis": return "BOPIS"
        case "ship_from_store": return "Ship From Store"
        case "in_store": return "In-Store"
        default: return normalizedLabel(channel)
        }
    }

    private func channelColor(for channel: String) -> Color {
        switch channel.lowercased() {
        case "online": return AppColors.accent
        case "bopis": return AppColors.info
        case "ship_from_store": return AppColors.success
        case "in_store": return AppColors.warning
        default: return AppColors.neutral600
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending": return AppColors.warning
        case "processing": return AppColors.info
        case "confirmed": return AppColors.success
        case "shipped", "delivered", "completed": return AppColors.accent
        case "cancelled": return AppColors.error
        default: return AppColors.neutral600
        }
    }

    private func reservationStatusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "confirmed": return AppColors.success
        case "pending": return AppColors.warning
        case "expired", "cancelled": return AppColors.error
        default: return AppColors.info
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }
}

private struct AdminFulfillmentRow: Identifiable {
    let id: UUID
    let storeName: String
    let location: String
    let totalOrders: Int
    let pending: Int
    let processing: Int
    let confirmed: Int
    let shipped: Int
}

