//
//  AdminDashboardView.swift
//  RSMS
//
//  Corporate Admin enterprise command center.
//  Maroon gradient header, KPI metrics, system health, alerts, quick actions, activity feed.
//

import SwiftUI
import SwiftData
import Supabase

enum ActiveAdminSheet: Identifiable {
    case profile
    case addSKU
    case addStaff
    case addStore
    case addPromotion
    case export
    case salesInsights
    case inventoryInsights
    case shareFile(URL)

    var id: String {
        switch self {
        case .profile: return "profile"
        case .addSKU: return "addSKU"
        case .addStaff: return "addStaff"
        case .addStore: return "addStore"
        case .addPromotion: return "addPromotion"
        case .export: return "export"
        case .salesInsights: return "salesInsights"
        case .inventoryInsights: return "inventoryInsights"
        case .shareFile(let url): return "shareFile-\(url.absoluteString)"
        }
    }
}

// MARK: - Main Dashboard View

struct AdminDashboardView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allProducts: [Product]
    @Query private var allUsers: [User]
    @Query private var allCategories: [Category]
    @Query private var allOrders: [Order]
    @Query private var allStores: [StoreLocation]
    @Query private var allAppointments: [Appointment]
    @Query private var allClients: [ClientProfile]
    @Query private var allAfterSalesTickets: [AfterSalesTicket]
    @State private var activeSheet: ActiveAdminSheet?

    // Low Stock Alert Cache
    @State private var lowStockAlerts: [LowStockAlert] = []
    @State private var isLoadingAlerts = false
    @State private var hasFetchedAlerts = false

    // Insights + Export
  @State private var selectedReportScope: AdminReportScope = .all
  @State private var selectedReportFormat: AdminReportFormat = .pdf
  @State private var isExportingReport = false
  @State private var exportErrorMessage = ""
  @State private var showExportError = false
  @State private var remoteSnapshot: AdminInsightsSnapshot?
  @State private var isSyncingLiveData = false
  @State private var liveSyncErrorMessage: String?
  @State private var lastSyncedAt: Date?

    private let impact = UIImpactFeedbackGenerator(style: .medium)

    private var remoteUsers: [UserDTO]? { remoteSnapshot?.users }
    private var remoteStores: [StoreDTO]? { remoteSnapshot?.stores }
    private var remoteOrders: [OrderDTO]? { remoteSnapshot?.orders }
    private var remoteOrderItems: [OrderItemDTO]? { remoteSnapshot?.orderItems }
    private var remoteAppointments: [AppointmentDTO]? { remoteSnapshot?.appointments }
    private var remoteClients: [ClientDTO]? { remoteSnapshot?.clients }
    private var remoteServiceTickets: [ServiceTicketDTO]? { remoteSnapshot?.serviceTickets }
    private var remoteInventory: [InventoryDTO]? { remoteSnapshot?.inventory }

    private var staffCount: Int {
        if let remoteUsers {
            return remoteUsers.filter { $0.userRole != .customer }.count
        }
        return allUsers.filter { $0.role != .customer }.count
    }
    private var activeStaffCount: Int {
        if let remoteUsers {
            return remoteUsers.filter { $0.userRole != .customer && $0.isActive }.count
        }
        return allUsers.filter { $0.role != .customer && $0.isActive }.count
    }
    private var totalInventoryUnits: Int {
        if let remoteInventory {
            return remoteInventory.reduce(0) { $0 + $1.quantity }
        }
        return allProducts.reduce(0) { $0 + $1.stockCount }
    }
    private var activeStoreCount: Int {
        if let remoteStores {
            return remoteStores.filter(\.isActive).count
        }
        return allStores.isEmpty ? 4 : allStores.filter(\.isOperational).count
    }
    private var totalSales: Double {
        if let remoteOrders {
            return remoteOrders.reduce(0) { $0 + $1.grandTotal }
        }
        return allOrders.reduce(0) { $0 + $1.total }
    }
    private var totalSalesText: String { formatCurrency(totalSales) }
    private var totalUnitsSold: Int {
        if let remoteOrderItems {
            return remoteOrderItems.reduce(0) { $0 + $1.quantity }
        }
        return allOrders.reduce(0) { partial, order in
            partial + parsedOrderQuantity(order)
        }
    }
    private var totalClients: Int {
        if let remoteClients {
            return max(remoteClients.filter(\.isActive).count, 1)
        }
        return max(allClients.count, 1)
    }



    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Maroon top glow
            LinearGradient(
                colors: [AppColors.accent.opacity(0.13), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.22)
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    welcomeHeader
                    metricsGrid
                    systemHealthBar
                    lowStockSection
                    alertsSection
                    quickActionsGrid
                    activityFeed
                    Spacer().frame(height: 40)
                }
            }
            .refreshable {
                await fetchLowStock()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MAISON LUXE")
                    .font(.system(size: 12, weight: .black))
                    .tracking(4)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button(action: {}) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.primary)
                    }
                    Button(action: { activeSheet = .profile }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.12))
                                .frame(width: 30, height: 30)
                            Text(adminInitials)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .profile:
                AdminProfileView()
            case .addSKU:
                CreateProductSheet(modelContext: modelContext, categories: allCategories)
            case .addStaff:
                CreateUserSheet(modelContext: modelContext)
            case .addStore:
                CreateStoreSheet()
            case .addPromotion:
                CreatePromotionSheet()
            case .export:
                AdminReportExportSheet(
                    selectedScope: $selectedReportScope,
                    selectedFormat: $selectedReportFormat,
                    isExporting: isExportingReport,
                    onExport: {
                        Task { await exportReports() }
                    }
                )
            case .salesInsights:
                DashboardSalesInsightsSheet(
                    associateRating: associateRatingFeedback,
                    appointmentRejectionRate: appointmentRejectionRate,
                    churnRate: churnRate,
                    retentionRate: retentionRate,
                    stocksToSaleRatio: stocksToSaleRatio,
                    monthlySalesTrend: monthlySalesTrend,
                    snapshot: remoteSnapshot
                )
            case .inventoryInsights:
                DashboardInventoryInsightsSheet(
                    inventoryTurnoverRatio: inventoryTurnoverRatio,
                    sellThroughRate: sellThroughRate,
                    customerAcquisitionNoPurchaseRate: customerAcquisitionNoPurchaseRate,
                    afterSalesLosses: afterSalesLosses,
                    monthlySellThroughTrend: monthlySellThroughTrend,
                    snapshot: remoteSnapshot
                )
            case .shareFile(let url):
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .task {
            // Run sequentially to avoid task-cancellation races when
            // SwiftData @Query updates cause the view to re-render and
            // restart the .task modifier (NSURLErrorDomain Code=-999).
            if !hasFetchedAlerts {
                await fetchLowStock()
            }
            await refreshLiveInsights()
        }
    }

    private var adminInitials: String {
        let parts = appState.currentUserName.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(appState.currentUserName.prefix(2)).uppercased()
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GOOD \(greeting.uppercased())")
                .font(.system(size: 9, weight: .semibold))
                .tracking(3)
                .foregroundColor(AppColors.accent)
            Text(appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Admin")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.primary)
            Text(Date(), style: .date)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening"
    }

    // MARK: - Insight Metrics

    private var associateRatingFeedback: Double {
        let completed: Double
        let noShows: Double
        if let remoteAppointments {
            completed = Double(remoteAppointments.filter { normalizedAppointmentStatus($0.status) == "completed" }.count)
            noShows = Double(remoteAppointments.filter { normalizedAppointmentStatus($0.status) == "no_show" }.count)
        } else {
            completed = Double(allAppointments.filter { $0.appointmentStatus == .completed }.count)
            noShows = Double(allAppointments.filter { $0.appointmentStatus == .noShow }.count)
        }
        let totalSignals = max(completed + noShows, 1)
        let positive = completed / totalSignals
        return min(max(3 + (positive * 2), 1), 5)
    }

    private var appointmentRejectionRate: Double {
        if let remoteAppointments {
            let rejected = Double(remoteAppointments.filter {
                let status = normalizedAppointmentStatus($0.status)
                return status == "cancelled" || status == "no_show"
            }.count)
            return rejected / Double(max(remoteAppointments.count, 1))
        }
        let rejected = Double(allAppointments.filter {
            $0.appointmentStatus == .cancelled || $0.appointmentStatus == .noShow
        }.count)
        return rejected / Double(max(allAppointments.count, 1))
    }

    private var churnRate: Double {
        if let remoteClients {
            let cutoff = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date()
            let ordersByClient = Dictionary(grouping: remoteOrders ?? [], by: { $0.clientId })
            let apptsByClient = Dictionary(grouping: remoteAppointments ?? [], by: { Optional($0.clientId) })
            let churned = remoteClients.filter { client in
                let clientOrders = ordersByClient[client.id] ?? []
                let clientAppointments = apptsByClient[client.id] ?? []
                let latestOrder = clientOrders.map(\.createdAt).max()
                let latestAppointment = clientAppointments.map(\.scheduledAt).max()
                let lastTouch = [latestOrder, latestAppointment].compactMap { $0 }.max()
                return (lastTouch ?? client.createdAt) < cutoff
            }.count
            return Double(churned) / Double(max(remoteClients.count, 1))
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date()
        let churned = allClients.filter {
            guard let lastVisit = $0.lastVisitDate else { return true }
            return lastVisit < cutoff
        }.count
        return Double(churned) / Double(totalClients)
    }

    private var retentionRate: Double {
        max(0, 1 - churnRate)
    }

    private var stocksToSaleRatio: Double {
        Double(totalInventoryUnits) / Double(max(totalUnitsSold, 1))
    }

    private var inventoryTurnoverRatio: Double {
        let averageInventory = Double(max(totalInventoryUnits, 1))
        return Double(totalUnitsSold) / averageInventory
    }

    private var sellThroughRate: Double {
        let sold = Double(totalUnitsSold)
        let onHand = Double(max(totalInventoryUnits, 0))
        return sold / max(sold + onHand, 1)
    }

    private var customerAcquisitionNoPurchaseRate: Double {
        if let remoteAppointments {
            let appointmentClients = Set(remoteAppointments.map(\.clientId))
            let purchasingClients = Set((remoteOrders ?? []).compactMap(\.clientId))
            let walkedOut = appointmentClients.subtracting(purchasingClients)
            return Double(walkedOut.count) / Double(max(appointmentClients.count, 1))
        }
        let appointmentCustomers = Set(allAppointments.map(\.customerEmail).filter { !$0.isEmpty })
        let purchasingCustomers = Set(allOrders.map(\.customerEmail).filter { !$0.isEmpty })
        let walkedOut = appointmentCustomers.subtracting(purchasingCustomers)
        return Double(walkedOut.count) / Double(max(appointmentCustomers.count, 1))
    }

    private var afterSalesLosses: Double {
        if let remoteServiceTickets {
            return remoteServiceTickets.reduce(0) { result, ticket in
                let isLossType = ["warranty", "return", "exchange"].contains(ticket.type.lowercased())
                let reportedCost = ticket.finalCost ?? ticket.estimatedCost ?? 0
                return result + (isLossType ? reportedCost : 0)
            }
        }
        return allAfterSalesTickets.reduce(0) { result, ticket in
            let isLossType = ticket.ticketType == .warranty || ticket.ticketType == .returnItem || ticket.ticketType == .exchange
            let reportedCost = ticket.actualCost > 0 ? ticket.actualCost : ticket.estimatedCost
            return result + (isLossType ? reportedCost : 0)
        }
    }

    private var monthlySalesTrend: [Double] {
        if let remoteOrders {
            return aggregateMonthly(series: remoteOrders.map { ($0.createdAt, $0.grandTotal) })
        }
        return aggregateMonthly(series: allOrders.map { ($0.createdAt, $0.total) })
    }

    private var monthlySellThroughTrend: [Double] {
        let monthlyUnits = aggregateMonthly(series: allOrders.map { ($0.createdAt, Double(parsedOrderQuantity($0))) })
        let denominator = Double(max(totalInventoryUnits, 1))
        return monthlyUnits.map { min($0 / denominator, 1) }
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            sectionHeader("KEY METRICS")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                metricCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: AppColors.accent,
                    value: totalSalesText,
                    label: "Total Sales",
                    badge: "Insights",
                    badgePositive: true
                ) {
                    activeSheet = .salesInsights
                }
                metricCard(
                    icon: "building.2.fill",
                    iconColor: AppColors.success,
                    value: "\(activeStoreCount)",
                    label: "Active Stores",
                    badge: "Live",
                    badgePositive: true
                )
                metricCard(
                    icon: "person.2.fill",
                    iconColor: AppColors.info,
                    value: "\(activeStaffCount)",
                    label: "Staff Active",
                    badge: "\(staffCount) total",
                    badgePositive: true
                )
                metricCard(
                    icon: "cube.box.fill",
                    iconColor: AppColors.secondaryLight,
                    value: "\(totalInventoryUnits)",
                    label: "Inventory Units",
                    badge: "Insights",
                    badgePositive: true
                ) {
                    activeSheet = .inventoryInsights
                }
            }
            .padding(.horizontal, 20)
            Text("Tap Total Sales or Inventory for deep insights")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricCard(
        icon: String,
        iconColor: Color,
        value: String,
        label: String,
        badge: String,
        badgePositive: Bool,
        action: (() -> Void)? = nil
    ) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    metricCardBody(icon: icon, iconColor: iconColor, value: value, label: label, badge: badge, badgePositive: badgePositive)
                }
                .buttonStyle(LiquidPressButtonStyle())
            } else {
                metricCardBody(icon: icon, iconColor: iconColor, value: value, label: label, badge: badge, badgePositive: badgePositive)
            }
        }
    }

    private func metricCardBody(icon: String, iconColor: Color, value: String, label: String, badge: String, badgePositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .ultraLight))
                    .foregroundColor(iconColor)
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(badgePositive ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((badgePositive ? AppColors.success : AppColors.warning).opacity(0.1))
                    .clipShape(Capsule())
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - System Health

    private var systemHealthBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SYSTEM HEALTH")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.primary.opacity(0.45))
                Spacer()
                Button(action: { Task { await refreshLiveInsights() } }) {
                    HStack(spacing: 4) {
                        if isSyncingLiveData {
                            ProgressView()
                                .scaleEffect(0.65)
                                .tint(AppColors.accent)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text(isSyncingLiveData ? "Syncing…" : "Sync Now")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    healthPill(icon: "checkmark.circle.fill", text: "API", color: AppColors.success)
                    healthPill(icon: "checkmark.circle.fill", text: "Database", color: AppColors.success)
                    healthPill(icon: "checkmark.circle.fill", text: "Payments", color: AppColors.success)
                    healthPill(
                        icon: isSyncingLiveData ? "arrow.triangle.2.circlepath.circle.fill" : (liveSyncErrorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill"),
                        text: syncPillLabel,
                        color: isSyncingLiveData ? AppColors.info : (liveSyncErrorMessage == nil ? AppColors.success : AppColors.warning)
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var syncPillLabel: String {
        if isSyncingLiveData { return "Syncing" }
        if liveSyncErrorMessage != nil { return "Sync Delayed" }
        guard let lastSyncedAt else { return "Sync Pending" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Live \(formatter.localizedString(for: lastSyncedAt, relativeTo: Date()))"
    }

    private func healthPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Low Stock Section
    
    private var lowStockSection: some View {
        VStack(spacing: 12) {
            HStack {
                sectionHeader("LOW STOCK ALERTS")
                Spacer()
                if isLoadingAlerts {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.trailing, 20)
                }
            }
            
            if lowStockAlerts.isEmpty && !isLoadingAlerts {
                Text("No low stock items 🎉")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(lowStockAlerts) { alert in
                        lowStockRow(for: alert)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func lowStockRow(for alert: LowStockAlert) -> some View {
        let isCritical = alert.alertLevel == .critical
        let badgeColor = isCritical ? AppColors.error : AppColors.warning
        
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(badgeColor)
                .frame(width: 3, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.productName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(alert.brand)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Text("\(alert.stockCount) Units Left")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: 12) {
            HStack {
                sectionHeader("ALERTS")
                Spacer()
                Text("3")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.warning)
                    .clipShape(Capsule())
                    .padding(.trailing, 20)
            }

            VStack(spacing: 10) {
                alertRow(icon: "exclamationmark.triangle.fill", color: AppColors.error,
                         title: "Critical: Heritage Bag", detail: "Stock at 1 unit — reorder required", time: "12m")
                alertRow(icon: "arrow.triangle.2.circlepath", color: AppColors.warning,
                         title: "Sync Delay", detail: "Paris boutique inventory 3h behind", time: "3h")
                alertRow(icon: "person.badge.plus", color: AppColors.info,
                         title: "Access Request", detail: "Sophia Laurent requests catalog edit", time: "5h")
            }
            .padding(.horizontal, 20)
        }
    }

    private func alertRow(icon: String, color: Color, title: String, detail: String, time: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 40)

            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(time)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        VStack(spacing: 12) {
            sectionHeader("QUICK ACTIONS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 12) {
                actionTile(icon: "plus.square.fill", label: "Add SKU", color: AppColors.accent) {
                    impact.impactOccurred(); activeSheet = .addSKU
                }
                actionTile(icon: "person.badge.plus", label: "Add Staff", color: AppColors.secondary) {
                    impact.impactOccurred(); activeSheet = .addStaff
                }
                actionTile(icon: "building.2.fill", label: "Add Store", color: AppColors.info) {
                    impact.impactOccurred(); activeSheet = .addStore
                }
                actionTile(icon: "arrow.left.arrow.right", label: "Transfer", color: AppColors.success) {
                    impact.impactOccurred()
                }
                actionTile(icon: "percent", label: "Promotion", color: AppColors.warning) {
                    impact.impactOccurred(); activeSheet = .addPromotion
                }
                actionTile(icon: "doc.text.fill", label: "Report", color: AppColors.secondaryLight) {
                    impact.impactOccurred()
                    guard appState.currentUserRole == .corporateAdmin else {
                        exportErrorMessage = "Only Corporate Admin users can download reports."
                        showExportError = true
                        return
                    }
                    activeSheet = .export
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func actionTile(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .ultraLight))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(LiquidPressButtonStyle())
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        VStack(spacing: 12) {
            HStack {
                sectionHeader("ACTIVITY")
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 3) {
                        Text("View All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.accent)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.trailing, 20)
            }

            VStack(spacing: 0) {
                activityItem(action: "SKU Created", detail: "Artisan Timepiece — Limited Edition", by: "V. Sterling", time: "10m")
                Divider().padding(.horizontal, 14)
                activityItem(action: "Price Override", detail: "Diamond Pendant — $15,800 → $16,200", by: "V. Sterling", time: "1h")
                Divider().padding(.horizontal, 14)
                activityItem(action: "Staff Provisioned", detail: "Isabella Moreau → Sales Associate", by: "J. Beaumont", time: "3h")
                Divider().padding(.horizontal, 14)
                activityItem(action: "Stock Transfer", detail: "Classic Flap Bag — NYC → Paris (2 units)", by: "D. Park", time: "6h")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            .padding(.horizontal, 20)
        }
    }

    private func activityItem(action: String, detail: String, by: String, time: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 5, height: 5)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(action)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(time)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.secondary)
                }
                Text(detail)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("by \(by)")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(AppColors.accent.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func parsedOrderQuantity(_ order: Order) -> Int {
        guard let data = order.orderItems.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return 0
        }
        return items.reduce(0) { partial, item in
            partial + (item["qty"] as? Int ?? 0)
        }
    }

    private func normalizedAppointmentStatus(_ status: String) -> String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @MainActor
    private func refreshLiveInsights() async {
        guard !isSyncingLiveData else { return }
        isSyncingLiveData = true
        defer { isSyncingLiveData = false }

        do {
            let snapshot = try await AdminInsightsService.shared.fetchLatestSnapshot()
            remoteSnapshot = snapshot
            lastSyncedAt = snapshot.syncedAt
            liveSyncErrorMessage = nil
        } catch {
            liveSyncErrorMessage = error.localizedDescription
            print("[AdminDashboardView] Live sync failed: \(error)")
        }
    }

    @MainActor
    private func exportReports() async {
        guard appState.currentUserRole == .corporateAdmin else {
            exportErrorMessage = "Only Corporate Admin users can download reports."
            showExportError = true
            return
        }

        guard !isExportingReport else { return }
        isExportingReport = true
        defer { isExportingReport = false }

        do {
            let freshSnapshot = try await AdminInsightsService.shared.fetchLatestSnapshot()
            remoteSnapshot = freshSnapshot
            lastSyncedAt = freshSnapshot.syncedAt
            liveSyncErrorMessage = nil

            let generatedBy = appState.currentUserName.isEmpty ? "Corporate Admin" : appState.currentUserName
            let fileURL = try AdminReportExportService.export(
                scope: selectedReportScope,
                format: selectedReportFormat,
                snapshot: freshSnapshot,
                generatedBy: generatedBy
            )
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                exportErrorMessage = "Export file could not be prepared."
                showExportError = true
                return
            }

            // Avoid sheet collision (export picker + share sheet).
            activeSheet = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                activeSheet = .shareFile(fileURL)
            }
        } catch {
            exportErrorMessage = "Export failed: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func aggregateMonthly(series: [(Date, Double)]) -> [Double] {
        let calendar = Calendar.current
        var bucket: [Double] = Array(repeating: 0, count: 6)
        let now = Date()

        for (date, value) in series {
            guard let monthDiff = calendar.dateComponents([.month], from: date, to: now).month else { continue }
            if monthDiff >= 0 && monthDiff < 6 {
                let index = 5 - monthDiff
                bucket[index] += value
            }
        }
        return bucket
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(3)
            .foregroundColor(.primary.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
    
    private func fetchLowStock() async {
        isLoadingAlerts = true
        do {
            let alerts = try await InventoryAnalyticsService.shared.fetchLowStockAlerts()
            await MainActor.run {
                self.lowStockAlerts = alerts
                self.hasFetchedAlerts = true
                self.isLoadingAlerts = false
            }
        } catch {
            print("[AdminDashboardView] Failed to fetch low stock alerts:", error)
            await MainActor.run {
                self.isLoadingAlerts = false
            }
        }
    }
}

// MARK: - Insight Sheets

private enum InsightsDateRange: CaseIterable, Hashable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case sixMonths
    case custom

    var shortLabel: String {
        switch self {
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        case .sixMonths: return "6M"
        case .custom: return "Custom"
        }
    }
}

private struct DashboardSalesInsightsSheet: View {
    let associateRating: Double
    let appointmentRejectionRate: Double
    let churnRate: Double
    let retentionRate: Double
    let stocksToSaleRatio: Double
    let monthlySalesTrend: [Double]
    let snapshot: AdminInsightsSnapshot?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStoreId: UUID? = nil
    @State private var selectedRange: InsightsDateRange = .thirtyDays
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd = Date()

    private var stores: [StoreDTO] {
        (snapshot?.stores ?? []).sorted { $0.name < $1.name }
    }

    private var filteredOrders: [OrderDTO] {
        guard let snapshot else { return [] }
        return snapshot.orders.filter { order in
            let inStoreScope = selectedStoreId == nil || order.storeId == selectedStoreId
            let inDateScope = order.createdAt >= dateRange.start && order.createdAt <= dateRange.end
            return inStoreScope && inDateScope
        }
    }

    private var detailedSalesSeries: [Double] {
        guard !filteredOrders.isEmpty else { return [] }
        let grouped = Dictionary(grouping: filteredOrders) { bucketDayString($0.createdAt) }
        let sortedKeys = grouped.keys.sorted()
        let totals = sortedKeys.map { key in
            grouped[key]?.reduce(0) { $0 + $1.grandTotal } ?? 0
        }
        return Array(totals.suffix(14))
    }

    private var detailedSalesTotal: Double {
        filteredOrders.reduce(0) { $0 + $1.grandTotal }
    }

    private var detailedOrderCount: Int { filteredOrders.count }

    private var dateRange: (start: Date, end: Date) {
        switch selectedRange {
        case .sevenDays:
            return (Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(), Date())
        case .thirtyDays:
            return (Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), Date())
        case .ninetyDays:
            return (Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date(), Date())
        case .sixMonths:
            return (Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(), Date())
        case .custom:
            let safeStart = min(customStart, customEnd)
            let safeEnd = max(customStart, customEnd)
            return (safeStart, safeEnd)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        trendCard(
                            title: "Sales Trend (6 Months)",
                            subtitle: "Revenue trajectory",
                            values: normalized(monthlySalesTrend),
                            accent: AppColors.accent
                        )

                        insightCard(title: "Ratings Feedback of Associates", value: String(format: "%.2f / 5.00", associateRating), tone: AppColors.success)
                        insightCard(title: "Appointments Not Approved / High Rejection", value: percent(appointmentRejectionRate), tone: appointmentRejectionRate > 0.25 ? AppColors.error : AppColors.warning)
                        insightCard(title: "Churn Rate", value: percent(churnRate), tone: churnRate > 0.30 ? AppColors.error : AppColors.warning)
                        insightCard(title: "Client Activity / Retention", value: percent(retentionRate), tone: AppColors.success)
                        insightCard(title: "Stocks to Sale Ratio", value: String(format: "%.2f", stocksToSaleRatio), tone: AppColors.info)
                        detailedGraphCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Sales Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let maxValue = values.max() ?? 1
        if maxValue == 0 { return Array(repeating: 0, count: values.count) }
        return values.map { $0 / maxValue }
    }

    private var detailedGraphCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Store & Date Specific")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            if snapshot == nil {
                Text("Run live sync to enable per-store detailed graph.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
            } else {
                storePicker
                rangePicker
                if selectedRange == .custom {
                    customDatePickers
                }

                trendCard(
                    title: "Detailed Sales Graph",
                    subtitle: "\(detailedOrderCount) orders · \(currency(detailedSalesTotal))",
                    values: normalized(detailedSalesSeries),
                    accent: AppColors.accent
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private var storePicker: some View {
        Menu {
            Button("All Stores") { selectedStoreId = nil }
            ForEach(stores, id: \.id) { store in
                Button(store.name) { selectedStoreId = store.id }
            }
        } label: {
            HStack {
                Text(selectedStoreLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var rangePicker: some View {
        Picker("Date Range", selection: $selectedRange) {
            ForEach(InsightsDateRange.allCases, id: \.self) { range in
                Text(range.shortLabel).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var customDatePickers: some View {
        HStack(spacing: 8) {
            DatePicker("From", selection: $customStart, displayedComponents: .date)
                .labelsHidden()
            DatePicker("To", selection: $customEnd, displayedComponents: .date)
                .labelsHidden()
        }
    }

    private var selectedStoreLabel: String {
        guard let selectedStoreId else { return "All Stores" }
        return stores.first(where: { $0.id == selectedStoreId })?.name ?? "Selected Store"
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }

    private func bucketDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct DashboardInventoryInsightsSheet: View {
    let inventoryTurnoverRatio: Double
    let sellThroughRate: Double
    let customerAcquisitionNoPurchaseRate: Double
    let afterSalesLosses: Double
    let monthlySellThroughTrend: [Double]
    let snapshot: AdminInsightsSnapshot?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStoreId: UUID? = nil
    @State private var selectedRange: InsightsDateRange = .thirtyDays
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd = Date()

    private var stores: [StoreDTO] {
        (snapshot?.stores ?? []).sorted { $0.name < $1.name }
    }

    private var filteredOrders: [OrderDTO] {
        guard let snapshot else { return [] }
        return snapshot.orders.filter { order in
            let inStoreScope = selectedStoreId == nil || order.storeId == selectedStoreId
            let inDateScope = order.createdAt >= dateRange.start && order.createdAt <= dateRange.end
            return inStoreScope && inDateScope
        }
    }

    private var detailedUnitsSeries: [Double] {
        guard let snapshot else { return [] }
        let orderLookup = Dictionary(uniqueKeysWithValues: filteredOrders.map { ($0.id, $0) })
        let filteredItems = snapshot.orderItems.filter { orderLookup[$0.orderId] != nil }
        let grouped = Dictionary(grouping: filteredItems) { item in
            let orderDate = orderLookup[item.orderId]?.createdAt ?? Date()
            return bucketDayString(orderDate)
        }
        let sortedKeys = grouped.keys.sorted()
        let totals = sortedKeys.map { key in
            grouped[key]?.reduce(0) { $0 + Double($1.quantity) } ?? 0
        }
        return Array(totals.suffix(14))
    }

    private var filteredInventoryUnits: Int {
        guard let snapshot else { return 0 }
        return snapshot.inventory
            .filter { selectedStoreId == nil || $0.storeId == selectedStoreId }
            .reduce(0) { $0 + $1.quantity }
    }

    private var filteredSellThrough: Double {
        let sold = detailedUnitsSeries.reduce(0, +)
        let onHand = Double(max(filteredInventoryUnits, 0))
        return sold / max(sold + onHand, 1)
    }

    private var dateRange: (start: Date, end: Date) {
        switch selectedRange {
        case .sevenDays:
            return (Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(), Date())
        case .thirtyDays:
            return (Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), Date())
        case .ninetyDays:
            return (Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date(), Date())
        case .sixMonths:
            return (Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(), Date())
        case .custom:
            let safeStart = min(customStart, customEnd)
            let safeEnd = max(customStart, customEnd)
            return (safeStart, safeEnd)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        trendCard(
                            title: "Sell Through (6 Months)",
                            subtitle: "Inventory conversion trend",
                            values: monthlySellThroughTrend.map { min(max($0, 0), 1) },
                            accent: AppColors.secondary
                        )

                        insightCard(title: "Inventory Turnover Ratio", value: String(format: "%.2f", inventoryTurnoverRatio), tone: AppColors.info)
                        insightCard(title: "Sell Through Rate", value: percent(sellThroughRate), tone: AppColors.success)
                        insightCard(
                            title: "Customer Acquisition (Visited, No Purchase)",
                            value: percent(customerAcquisitionNoPurchaseRate),
                            tone: customerAcquisitionNoPurchaseRate > 0.40 ? AppColors.error : AppColors.warning
                        )
                        insightCard(title: "After Sales Losses (Warranty/Defects)", value: currency(afterSalesLosses), tone: AppColors.error)
                        detailedGraphCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Inventory Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }

    private var detailedGraphCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Store & Date Specific")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            if snapshot == nil {
                Text("Run live sync to enable per-store detailed graph.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
            } else {
                storePicker
                rangePicker
                if selectedRange == .custom {
                    customDatePickers
                }

                trendCard(
                    title: "Detailed Inventory Movement",
                    subtitle: "Sell Through \(percent(filteredSellThrough)) · On-hand \(filteredInventoryUnits) units",
                    values: normalized(detailedUnitsSeries),
                    accent: AppColors.secondary
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private var storePicker: some View {
        Menu {
            Button("All Stores") { selectedStoreId = nil }
            ForEach(stores, id: \.id) { store in
                Button(store.name) { selectedStoreId = store.id }
            }
        } label: {
            HStack {
                Text(selectedStoreLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var rangePicker: some View {
        Picker("Date Range", selection: $selectedRange) {
            ForEach(InsightsDateRange.allCases, id: \.self) { range in
                Text(range.shortLabel).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var customDatePickers: some View {
        HStack(spacing: 8) {
            DatePicker("From", selection: $customStart, displayedComponents: .date)
                .labelsHidden()
            DatePicker("To", selection: $customEnd, displayedComponents: .date)
                .labelsHidden()
        }
    }

    private var selectedStoreLabel: String {
        guard let selectedStoreId else { return "All Stores" }
        return stores.first(where: { $0.id == selectedStoreId })?.name ?? "Selected Store"
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let maxValue = values.max() ?? 1
        if maxValue == 0 { return Array(repeating: 0, count: values.count) }
        return values.map { $0 / maxValue }
    }

    private func bucketDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private func trendCard(title: String, subtitle: String, values: [Double], accent: Color) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
        Text(subtitle)
            .font(.system(size: 11, weight: .light))
            .foregroundColor(.secondary)

        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(accent.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(16, CGFloat(value) * 80))
            }
        }
        .frame(height: 88, alignment: .bottom)
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
}

private func insightCard(title: String, value: String, tone: Color) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        Spacer()
        Circle()
            .fill(tone.opacity(0.14))
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(tone.opacity(0.5), lineWidth: 1)
            )
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
}

// MARK: - Liquid Press Button Style

struct LiquidPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Create Store Sheet

struct CreateStoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var storeName = ""
    @State private var storeCity = ""
    @State private var storeCountry = ""
    @State private var storeManager = ""
    @State private var storeType: StoreType = .boutique
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreated = false

    enum StoreType: String, CaseIterable {
        case boutique     = "Boutique"
        case distribution = "Distribution Center"

        var supabaseType: String {
            switch self {
            case .boutique:     return "boutique"
            case .distribution: return "distribution_center"
            }
        }

        var localType: LocationType {
            switch self {
            case .boutique:     return .boutique
            case .distribution: return .distributionCenter
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.info.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(AppColors.info)
                            }
                            Text("Add New Store")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.primary)
                            Text("Register a boutique or distribution center")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("STORE TYPE")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(StoreType.allCases, id: \.self) { type in
                                        Button(action: { storeType = type }) {
                                            Text(type.rawValue)
                                                .font(.system(size: 13, weight: storeType == type ? .semibold : .regular))
                                                .foregroundColor(storeType == type ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 9)
                                                .background(storeType == type ? AppColors.accent : Color(.secondarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(storeType == type ? Color.clear : Color(.systemGray4), lineWidth: 1))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        VStack(spacing: 16) {
                            LuxuryTextField(placeholder: "Store Name", text: $storeName, icon: "building.2")
                            LuxuryTextField(placeholder: "City", text: $storeCity, icon: "mappin")
                            LuxuryTextField(placeholder: "Country", text: $storeCountry, icon: "globe")
                            LuxuryTextField(placeholder: "Manager Name (optional)", text: $storeManager, icon: "person")
                        }
                        .padding(.horizontal, 20)

                        PrimaryButton(title: isCreating ? "Creating…" : "Create Store") {
                            Task { await createStore() }
                        }
                        .disabled(isCreating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .disabled(isCreating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage) }
            .alert("Store Created!", isPresented: $isCreated) {
                Button("Done") { dismiss() }
            } message: { Text("\(storeName) has been added to your store network.") }
        }
    }

    @MainActor
    private func createStore() async {
        let trimmedName    = storeName.trimmingCharacters(in: .whitespaces)
        let trimmedCity    = storeCity.trimmingCharacters(in: .whitespaces)
        let trimmedCountry = storeCountry.trimmingCharacters(in: .whitespaces)
        let trimmedManager = storeManager.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !trimmedCity.isEmpty, !trimmedCountry.isEmpty else {
            errorMessage = "Please fill in the store name, city, and country."
            showError = true
            return
        }

        isCreating = true
        defer { isCreating = false }

        let newId = UUID()
        let code  = String(trimmedName.prefix(3)).uppercased() + String(format: "%03d", Int.random(in: 1...999))

        // 1 — Insert into Supabase `stores` table
        let payload = StoreInsertDTO(
            id: newId,
            code: code,
            name: trimmedName,
            type: storeType.supabaseType,
            country: trimmedCountry,
            city: trimmedCity,
            address: "",
            currency: "INR",
            timezone: "Asia/Kolkata",
            region: trimmedCity,
            managerName: trimmedManager,
            capacityUnits: 0,
            monthlySalesTarget: nil,
            isActive: true
        )

        do {
            let _: StoreDTO = try await SupabaseManager.shared.client
                .from("stores")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            // 2 — Mirror into local SwiftData so StoreConfigView refreshes instantly
            let local = StoreLocation(
                code: code,
                name: trimmedName,
                type: storeType.localType,
                addressLine1: "",
                city: trimmedCity,
                stateProvince: "",
                postalCode: "",
                country: trimmedCountry,
                region: trimmedCity,
                managerName: trimmedManager,
                capacityUnits: 0,
                isOperational: true
            )
            local.id = newId
            modelContext.insert(local)
            try? modelContext.save()

            isCreated = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Create Promotion Sheet

struct CreatePromotionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) var appState

    // Products and categories are fetched fresh from Supabase to ensure
    // UUIDs match the DB (avoids FK constraint violations from stale SwiftData).
    @State private var remoteProducts: [ProductDTO] = []
    @State private var remoteCategories: [CategoryDTO] = []
    @State private var isLoadingTargets = false

    @State private var name = ""
    @State private var details = ""
    @State private var scope: PromotionScope = .product
    @State private var selectedProductId: UUID? = nil
    @State private var selectedCategoryId: UUID? = nil
    @State private var discountType: PromotionDiscountType = .percentage
    @State private var discountValue = ""
    @State private var startsAt = Date()
    @State private var endsAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var isActive = true
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreated = false

    private var selectedProductName: String {
        guard let id = selectedProductId else { return "Select a product…" }
        return remoteProducts.first(where: { $0.id == id })?.name ?? "Select a product…"
    }

    private var selectedCategoryName: String {
        guard let id = selectedCategoryId else { return "Select a category…" }
        return remoteCategories.first(where: { $0.id == id })?.name ?? "Select a category…"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // MARK: Header
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.warning.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "percent")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(AppColors.warning)
                            }
                            Text("Create Promotion")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.primary)
                            Text("Add a discount rule to your catalog")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        // MARK: Scope picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SCOPE")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(PromotionScope.allCases) { s in
                                        Button(action: {
                                            scope = s
                                            selectedProductId = nil
                                            selectedCategoryId = nil
                                        }) {
                                            Text(s.title)
                                                .font(.system(size: 13, weight: scope == s ? .semibold : .regular))
                                                .foregroundColor(scope == s ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 9)
                                                .background(scope == s ? AppColors.accent : Color(.secondarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(scope == s ? Color.clear : Color(.systemGray4), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // MARK: Target selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text(scope == .product ? "TARGET PRODUCT" : "TARGET CATEGORY")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.accent)

                            if scope == .product {
                                Menu {
                                    if remoteProducts.isEmpty {
                                        Text(isLoadingTargets ? "Loading…" : "No products available")
                                            .foregroundColor(.secondary)
                                    }
                                    ForEach(remoteProducts.sorted { $0.name < $1.name }, id: \.id) { product in
                                        Button(product.name) { selectedProductId = product.id }
                                    }
                                } label: {
                                    targetMenuLabel(
                                        icon: "cube.box",
                                        text: selectedProductName,
                                        isPlaceholder: selectedProductId == nil
                                    )
                                }
                            } else {
                                Menu {
                                    if remoteCategories.isEmpty {
                                        Text(isLoadingTargets ? "Loading…" : "No categories available")
                                            .foregroundColor(.secondary)
                                    }
                                    ForEach(remoteCategories.sorted { $0.name < $1.name }, id: \.id) { category in
                                        Button(category.name) { selectedCategoryId = category.id }
                                    }
                                } label: {
                                    targetMenuLabel(
                                        icon: "tag",
                                        text: selectedCategoryName,
                                        isPlaceholder: selectedCategoryId == nil
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // MARK: Name & Details
                        VStack(spacing: 16) {
                            LuxuryTextField(placeholder: "Promotion Name", text: $name, icon: "tag.fill")
                            LuxuryTextField(placeholder: "Details (optional)", text: $details, icon: "text.alignleft")
                        }
                        .padding(.horizontal, 20)

                        // MARK: Discount Type
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DISCOUNT TYPE")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(PromotionDiscountType.allCases) { dt in
                                        Button(action: { discountType = dt }) {
                                            Text(dt.title)
                                                .font(.system(size: 13, weight: discountType == dt ? .semibold : .regular))
                                                .foregroundColor(discountType == dt ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 9)
                                                .background(discountType == dt ? AppColors.accent : Color(.secondarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(discountType == dt ? Color.clear : Color(.systemGray4), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // MARK: Discount Value
                        LuxuryTextField(
                            placeholder: discountType == .percentage ? "Discount % (e.g. 10)" : "Amount off in ₹ (e.g. 500)",
                            text: $discountValue,
                            icon: discountType == .percentage ? "percent" : "indianrupeesign"
                        )
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 20)

                        // MARK: Duration
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DURATION")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.secondary)
                                        .frame(width: 22)
                                    DatePicker("Starts", selection: $startsAt, displayedComponents: .date)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)

                                Divider().padding(.horizontal, 16)

                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.secondary)
                                        .frame(width: 22)
                                    DatePicker("Ends", selection: $endsAt, in: startsAt..., displayedComponents: .date)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                            .padding(.horizontal, 20)
                        }

                        // MARK: Active toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Active immediately")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Promotion applies as soon as it's created")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $isActive)
                                .tint(AppColors.accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                        .padding(.horizontal, 20)

                        // MARK: Submit
                        PrimaryButton(title: isCreating ? "Creating…" : "Create Promotion") {
                            Task { await createPromotion() }
                        }
                        .disabled(isCreating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Fetch products and categories directly from Supabase so UUIDs
                // are guaranteed to match the DB (avoids FK constraint violations).
                isLoadingTargets = true
                async let productsFetch: [ProductDTO] = SupabaseManager.shared.client
                    .from("products")
                    .select("id, name, sku, brand, price, is_active, created_at, updated_at")
                    .eq("is_active", value: true)
                    .order("name", ascending: true)
                    .execute()
                    .value
                async let categoriesFetch: [CategoryDTO] = SupabaseManager.shared.client
                    .from("categories")
                    .select("id, name, is_active, created_at, updated_at")
                    .eq("is_active", value: true)
                    .order("name", ascending: true)
                    .execute()
                    .value
                remoteProducts = (try? await productsFetch) ?? []
                remoteCategories = (try? await categoriesFetch) ?? []
                isLoadingTargets = false
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .disabled(isCreating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage) }
            .alert("Promotion Created!", isPresented: $isCreated) {
                Button("Done") { dismiss() }
            } message: {
                Text("\"\(name)\" has been created and synced to Supabase.")
            }
        }
    }

    // MARK: - Helper Views

    private func targetMenuLabel(icon: String, text: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(.secondary)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(isPlaceholder ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }

    // MARK: - Create Logic

    @MainActor
    private func createPromotion() async {
        let trimmedName    = name.trimmingCharacters(in: .whitespaces)
        let trimmedDetails = details.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a promotion name."
            showError = true
            return
        }
        guard let value = Double(discountValue.trimmingCharacters(in: .whitespaces)), value > 0 else {
            errorMessage = "Please enter a valid discount value greater than 0."
            showError = true
            return
        }
        if discountType == .percentage && value > 100 {
            errorMessage = "Percentage discount cannot exceed 100%."
            showError = true
            return
        }
        guard endsAt > startsAt else {
            errorMessage = "End date must be after the start date."
            showError = true
            return
        }
        // DB constraint: scope='product' requires target_product_id NOT NULL
        if scope == .product && selectedProductId == nil {
            errorMessage = "Please select a specific product for this promotion."
            showError = true
            return
        }
        // DB constraint: scope='category' requires target_category_id NOT NULL
        if scope == .category && selectedCategoryId == nil {
            errorMessage = "Please select a specific category for this promotion."
            showError = true
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let dto = try await PromotionService.shared.createPromotion(
                name: trimmedName,
                details: trimmedDetails,
                scope: scope,
                targetProductId: scope == .product ? selectedProductId : nil,
                targetCategoryId: scope == .category ? selectedCategoryId : nil,
                discountType: discountType,
                discountValue: value,
                startsAt: startsAt,
                endsAt: endsAt,
                isActive: isActive,
                createdBy: appState.currentUserProfile?.id
            )

            // Mirror into local SwiftData so PromotionSyncService picks it up
            let local = PromotionRule(
                id: dto.id,
                name: dto.name,
                details: dto.details ?? "",
                scope: dto.promotionScope,
                targetProductId: dto.targetProductId,
                targetCategoryId: dto.targetCategoryId,
                discountType: dto.promotionDiscountType,
                discountValue: dto.discountValue,
                startsAt: dto.startsAt,
                endsAt: dto.endsAt,
                isActive: dto.isActive,
                createdBy: dto.createdBy,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            modelContext.insert(local)
            try? modelContext.save()

            isCreated = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    AdminDashboardView()
        .environment(AppState())
        .modelContainer(
            for: [
                Product.self,
                Category.self,
                User.self,
                Order.self,
                StoreLocation.self,
                Appointment.self,
                ClientProfile.self,
                AfterSalesTicket.self
            ],
            inMemory: true
        )
}
