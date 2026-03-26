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
import Charts

enum ActiveAdminSheet: Identifiable {
    case profile
    case addSKU
    case addStaff
    case addStore
    case addPromotion
    case export
    case clientActivity
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
        case .clientActivity: return "clientActivity"
        case .salesInsights: return "salesInsights"
        case .inventoryInsights: return "inventoryInsights"
        case .shareFile(let url): return "shareFile-\(url.absoluteString)"
        }
    }
}

private enum SharpCorners {
    static let panel: CGFloat = 8
    static let control: CGFloat = 6
    static let badge: CGFloat = 5
}

private struct AdminActivityPreviewItem: Identifiable {
    let id: String
    let action: String
    let detail: String
    let by: String
    let time: String
}

// MARK: - Main Dashboard View

/// AdminDashboardView is the primary interface for corporate administrators.
///
/// Key Features:
/// - Real-time KPI metrics and system health monitoring
/// - Low stock alerts and inventory management
/// - Staff performance insights and analytics
/// - Report generation and data export (PDF, CSV)
/// - Live data synchronization from Supabase
/// - Quick action shortcuts for common tasks
/// - Activity feed for audit trail tracking
/// - Performance optimized with local/remote data hybrid approach
///
/// The view maintains both local SwiftData models and remote Supabase snapshots
/// to provide instant responsiveness while allowing background sync operations.
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
    @State private var alertCarouselIndex = 0

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
    private var remoteReservations: [ReservationDTO]? { remoteSnapshot?.reservations }
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
            AppColors.backgroundPrimary.ignoresSafeArea()

            // Atmospheric depth layer for premium glass separation.
            LinearGradient(
                colors: [
                    AppColors.backgroundPrimary,
                    AppColors.accent.opacity(0.04),
                    AppColors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Maroon top glow
            LinearGradient(
                colors: [AppColors.accent.opacity(0.13), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.22)
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
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
            .padding(.top, 2)
            .refreshable {
                await fetchLowStock()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSyncingLiveData)
        .animation(.easeInOut(duration: 0.25), value: lowStockAlerts.count)
        .animation(.easeInOut(duration: 0.25), value: activeSheet?.id)
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
                    Button(action: { activeSheet = .clientActivity }) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                        Text(adminInitials)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.accent)
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
            case .clientActivity:
                NavigationStack {
                    CorporateAdminClientActivityView()
                        .environment(appState)
                }
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("GOOD \(greeting.uppercased())")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.5)
                    .foregroundColor(AppColors.accent)
                Text(appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Admin")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
                Text(Date(), style: .date)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.top, 2)
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
        VStack(spacing: 8) {
            sectionHeader("KEY METRICS")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 10
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Icon in a soft rounded square
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(iconColor)
                }
                Spacer()
                // Badge pill
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(badgePositive ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((badgePositive ? AppColors.success : AppColors.warning).opacity(0.10))
                    .clipShape(Capsule())
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
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
                                .font(.system(size: 11, weight: .medium))
                        }
                        Text(isSyncingLiveData ? "Syncing…" : "Sync Now")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accent.opacity(0.08))
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 1)
    }

    // MARK: - Low Stock Section
    
    private var lowStockSection: some View {
        VStack(spacing: 8) {
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
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.success)
                    Text("No low stock items")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
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
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(badgeColor)
                .frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(alert.brand)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(alert.stockCount) left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: 8) {
            HStack {
                sectionHeader("ALERTS")
                Spacer()
                Text("3")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.warning)
                    .clipShape(RoundedRectangle(cornerRadius: SharpCorners.badge, style: .continuous))
                    .padding(.trailing, 20)
            }

            TabView(selection: $alertCarouselIndex) {
                ForEach(Array(alertItems.enumerated()), id: \.offset) { index, item in
                    alertCard(icon: item.icon, color: item.color, title: item.title, detail: item.detail, time: item.time)
                        .padding(.horizontal, 20)
                        .tag(index)
                }
            }
            .frame(height: 102)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(alertItems.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == alertCarouselIndex ? AppColors.accent : AppColors.neutral300.opacity(0.6))
                        .frame(width: index == alertCarouselIndex ? 16 : 6, height: 6)
                }
            }
        }
    }

    private var alertItems: [(icon: String, color: Color, title: String, detail: String, time: String)] {
        [
            ("exclamationmark.triangle.fill", AppColors.error, "Critical: Heritage Bag", "Stock at 1 unit — reorder required", "12m"),
            ("arrow.triangle.2.circlepath", AppColors.warning, "Sync Delay", "Paris boutique inventory 3h behind", "3h"),
            ("person.badge.plus", AppColors.info, "Access Request", "Sophia Laurent requests catalog edit", "5h")
        ]
    }

    private func alertCard(icon: String, color: Color, title: String, detail: String, time: String) -> some View {
        HStack(spacing: 12) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(time)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        VStack(spacing: 8) {
            sectionHeader("QUICK ACTIONS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 10) {
                actionTile(icon: "plus.square.fill", label: "Add SKU", color: AppColors.accent) {
                    impact.impactOccurred(); activeSheet = .addSKU
                }
                actionTile(icon: "person.badge.plus", label: "Add Staff", color: AppColors.secondary) {
                    impact.impactOccurred(); activeSheet = .addStaff
                }
                actionTile(icon: "building.2.fill", label: "Add Store", color: AppColors.info) {
                    impact.impactOccurred(); activeSheet = .addStore
                }
                actionTile(icon: "person.text.rectangle.fill", label: "Activity", color: AppColors.success) {
                    impact.impactOccurred(); activeSheet = .clientActivity
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
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.10))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .padding(.horizontal, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        VStack(spacing: 12) {
            HStack {
                sectionHeader("ACTIVITY")
                Spacer()
                Button(action: { activeSheet = .clientActivity }) {
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
                if activityPreviewItems.isEmpty {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.neutral500)
                        Text("No recent activity yet")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.md)
                } else {
                    ForEach(Array(activityPreviewItems.enumerated()), id: \.element.id) { index, item in
                        activityItem(action: item.action, detail: item.detail, by: item.by, time: item.time)
                        if index < activityPreviewItems.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            .padding(.horizontal, 20)
        }
    }

    private var activityPreviewItems: [AdminActivityPreviewItem] {
        if let remoteOrders {
            let remoteClientsById = Dictionary(uniqueKeysWithValues: (remoteClients ?? []).map { ($0.id, $0) })
            return remoteOrders
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(4)
                .map { order in
                    let actorName = order.clientId.flatMap { remoteClientsById[$0]?.fullName } ?? "System"
                    return AdminActivityPreviewItem(
                        id: order.id.uuidString,
                        action: activityAction(for: order.status),
                        detail: "\(order.orderNumber ?? "Order") — \(channelSummary(for: order.channel)) • \(formatCurrency(order.grandTotal))",
                        by: actorName,
                        time: relativeTimeString(from: order.updatedAt)
                    )
                }
        }

        return allOrders
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(4)
            .map { order in
                AdminActivityPreviewItem(
                    id: order.id.uuidString,
                    action: activityAction(for: order.statusRaw),
                    detail: "\(order.orderNumber) — \(order.fulfillmentType.rawValue) • \(order.formattedTotal)",
                    by: order.customerEmail.isEmpty ? "System" : order.customerEmail,
                    time: relativeTimeString(from: order.updatedAt)
                )
            }
    }

    private func activityAction(for statusRaw: String) -> String {
        switch statusRaw.lowercased() {
        case "completed", "delivered": return "Order Completed"
        case "shipped": return "Order Shipped"
        case "processing": return "Order Processing"
        case "confirmed", "pending": return "Order Updated"
        case "cancelled", "canceled": return "Order Cancelled"
        default: return "Order Activity"
        }
    }

    private func channelSummary(for channel: String) -> String {
        switch channel.lowercased() {
        case "online": return "Online"
        case "bopis": return "BOPIS"
        case "ship_from_store": return "Ship From Store"
        case "in_store": return "In-Store"
        default: return channel.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func activityItem(action: String, detail: String, by: String, time: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.10))
                    .frame(width: 32, height: 32)
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(action)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("by \(by)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.accent.opacity(0.75))
            }
        }
        .padding(.horizontal, 16)
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

            await AdminAuditService.shared.logActivity(
                action: "Exported Report",
                details: [
                    "scope": selectedReportScope.rawValue,
                    "format": selectedReportFormat.rawValue
                ]
            )

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
            .font(.system(size: 11, weight: .semibold))
            .tracking(2)
            .foregroundColor(.secondary)
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
        detailedSalesPoints.map(\.value)
    }

    private enum SalesTrendBucket {
        case day
        case week
        case month
    }

    private var detailedSalesBucket: SalesTrendBucket {
        switch selectedRange {
        case .sevenDays, .thirtyDays:
            return .day
        case .ninetyDays:
            return .week
        case .sixMonths:
            return .month
        case .custom:
            let days = max(Calendar.current.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0, 0)
            if days > 120 { return .month }
            if days > 45 { return .week }
            return .day
        }
    }

    private var detailedSalesPointLimit: Int {
        switch detailedSalesBucket {
        case .day:
            switch selectedRange {
            case .sevenDays:
                return 7
            case .thirtyDays:
                return 30
            case .custom:
                let days = max((Calendar.current.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0) + 1, 1)
                return min(days, 45)
            case .ninetyDays, .sixMonths:
                return 30
            }
        case .week:
            return 13
        case .month:
            return 6
        }
    }

    private var detailedSalesPoints: [(date: Date, value: Double)] {
        guard !filteredOrders.isEmpty else { return [] }
        let grouped = Dictionary(grouping: filteredOrders) { bucketStartDate(for: $0.createdAt) }
        let sortedKeys = grouped.keys.sorted()
        let points = sortedKeys.map { key in
            (
                date: key,
                value: grouped[key]?.reduce(0) { $0 + $1.grandTotal } ?? 0
            )
        }
        return Array(points.suffix(detailedSalesPointLimit))
    }

    private var latestSalesPoint: (date: Date, value: Double)? {
        detailedSalesPoints.last
    }

    private var previousSalesPoint: (date: Date, value: Double)? {
        guard detailedSalesPoints.count > 1 else { return nil }
        return detailedSalesPoints[detailedSalesPoints.count - 2]
    }

    private var recentSalesDelta: Double? {
        guard let latest = latestSalesPoint?.value,
              let previous = previousSalesPoint?.value else { return nil }
        if previous == 0 { return nil }
        return (latest - previous) / previous
    }

    private var detailedSalesTotal: Double {
        filteredOrders.reduce(0) { $0 + $1.grandTotal }
    }

    private var detailedOrderCount: Int { filteredOrders.count }

    private var averageOrderValue: Double {
        guard detailedOrderCount > 0 else { return 0 }
        return detailedSalesTotal / Double(detailedOrderCount)
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

    private var monthlySalesTrendPoints: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let values = monthlySalesTrend
        let count = values.count

        return values.enumerated().map { index, value in
            let offset = (count - 1) - index
            let date = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            return (date: date, value: value)
        }
    }

    private var monthlySalesAverage: Double {
        guard !monthlySalesTrend.isEmpty else { return 0 }
        return monthlySalesTrend.reduce(0, +) / Double(monthlySalesTrend.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                LinearGradient(
                    colors: [AppColors.backgroundPrimary, AppColors.accent.opacity(0.05), AppColors.backgroundPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        salesOverviewTrendChart

                        summaryStrip(
                            title: "Current Selection",
                            stats: [
                                ("Orders", "\(detailedOrderCount)", AppColors.info),
                                ("Revenue", currency(detailedSalesTotal), AppColors.accent),
                                ("Avg Order", currency(averageOrderValue), AppColors.success)
                            ]
                        )

                        salesScopeHintCard

                        sectionLabel("PERFORMANCE SIGNALS")
                        salesSignalsGrid

                        sectionLabel("DETAILED BREAKDOWN")
                        detailedGraphCard
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, AppSpacing.lg)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedRange)
            .animation(.easeInOut(duration: 0.25), value: selectedStoreId)
            .navigationTitle("Sales Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(AppTypography.closeButton)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .liquidGlass(config: .ultraThin, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.control)
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Store & Date Specific")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)

            if snapshot == nil {
                Text("Run live sync to enable per-store detailed graph.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textPrimaryDark)
            } else {
                storePicker
                rangePicker
                if selectedRange == .custom {
                    customDatePickers
                }

                if detailedSalesSeries.isEmpty {
                    Text("No sales data in the selected range.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                        .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundPrimary, cornerRadius: SharpCorners.control)
                } else {
                    detailedSalesTrendChart
                }
            }
        }
        .padding(18)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.medium)
    }

    private var salesOverviewTrendChart: some View {
        let points = monthlySalesTrendPoints
        let maxValue = max(points.map(\.value).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sales Trend (6 Months)")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("Monthly revenue trajectory")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                Spacer()
                Text("Avg \(currency(monthlySalesAverage))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(
                        x: .value("Month", point.date),
                        y: .value("Revenue", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.28), AppColors.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Revenue", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.2))
                    .foregroundStyle(AppColors.accent)

                    PointMark(
                        x: .value("Month", point.date),
                        y: .value("Revenue", point.value)
                    )
                    .symbolSize(26)
                    .foregroundStyle(AppColors.accent.opacity(0.95))
                }

                RuleMark(y: .value("Average", monthlySalesAverage))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(AppColors.info.opacity(0.9))
                    .annotation(position: .topLeading) {
                        Text("Average")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.info)
                    }
            }
            .frame(height: 210)
            .chartYScale(domain: 0...(maxValue * 1.15))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }
        }
        .padding(18)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.medium)
    }

    private var detailedSalesTrendChart: some View {
        let points = detailedSalesPoints
        let maxValue = max(points.map(\.value).max() ?? 1, 1)
        let latestLabel = latestSalesPoint.map { displayDetailedBucketLabel(fromDate: $0.date) } ?? "-"
        let latestValue = latestSalesPoint?.value ?? 0
        let deltaText = recentSalesDelta.map { String(format: "%+.1f%% vs previous %@", $0 * 100, detailedBucketLabel) } ?? "Trend baseline unavailable"
        let deltaTone: Color = (recentSalesDelta ?? 0) >= 0 ? AppColors.success : AppColors.error

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detailed Sales Trend")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("\(detailedOrderCount) orders · \(currency(detailedSalesTotal))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(latestLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(currency(latestValue))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Revenue", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.28), AppColors.accent.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Revenue", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(AppColors.accent)
                }

                if let latestSalesPoint {
                    PointMark(
                        x: .value("Latest", latestSalesPoint.date),
                        y: .value("Latest Revenue", latestSalesPoint.value)
                    )
                    .symbolSize(42)
                    .foregroundStyle(AppColors.accent)
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...(maxValue * 1.15))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel(format: detailedXAxisFormat)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }

            Text(deltaText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(deltaTone)
        }
        .padding(18)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.medium)
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
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundPrimary, cornerRadius: SharpCorners.control)
        }
    }

    private var rangePicker: some View {
        Picker("Date Range", selection: $selectedRange) {
            ForEach(InsightsDateRange.allCases, id: \.self) { range in
                Text(range.shortLabel).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(4)
        .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundTertiary.opacity(0.65), cornerRadius: SharpCorners.control)
    }

    private var customDatePickers: some View {
        HStack(spacing: 8) {
            DatePicker("From", selection: $customStart, displayedComponents: .date)
                .labelsHidden()
            DatePicker("To", selection: $customEnd, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(AppSpacing.xs)
        .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundPrimary, cornerRadius: SharpCorners.control)
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

    private func bucketStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        switch detailedSalesBucket {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
        }
    }

    private func displayDayString(fromDate date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }

    private var detailedBucketLabel: String {
        switch detailedSalesBucket {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        }
    }

    private var detailedXAxisFormat: Date.FormatStyle {
        switch detailedSalesBucket {
        case .day:
            return .dateTime.day().month(.abbreviated)
        case .week:
            return .dateTime.day().month(.abbreviated)
        case .month:
            return .dateTime.month(.abbreviated)
        }
    }

    private func displayDetailedBucketLabel(fromDate date: Date) -> String {
        let formatter = DateFormatter()
        switch detailedSalesBucket {
        case .day:
            formatter.dateFormat = "dd MMM"
            return formatter.string(from: date)
        case .week:
            formatter.dateFormat = "dd MMM"
            return "Wk of \(formatter.string(from: date))"
        case .month:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
    }

    private var salesScopeHintCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accent)

            Text("Use Store and Date filters in Detailed Breakdown to inspect a specific segment.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textPrimaryDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.control)
    }

    private var salesSignalsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            performanceSignalCard(
                title: "Associate Rating",
                value: String(format: "%.2f / 5.00", associateRating),
                status: associateRating >= 4.2 ? "Strong" : (associateRating >= 3.6 ? "Moderate" : "Weak"),
                benchmark: "Target ≥ 4.20",
                normalizedScore: min(max(associateRating / 5, 0), 1),
                higherIsBetter: true,
                tone: associateRating >= 4.2 ? AppColors.success : (associateRating >= 3.6 ? AppColors.warning : AppColors.error)
            )

            performanceSignalCard(
                title: "Rejection Rate",
                value: percent(appointmentRejectionRate),
                status: appointmentRejectionRate <= 0.12 ? "Healthy" : (appointmentRejectionRate <= 0.25 ? "Watch" : "Critical"),
                benchmark: "Target ≤ 12%",
                normalizedScore: min(max(appointmentRejectionRate / 0.35, 0), 1),
                higherIsBetter: false,
                tone: appointmentRejectionRate <= 0.12 ? AppColors.success : (appointmentRejectionRate <= 0.25 ? AppColors.warning : AppColors.error)
            )

            performanceSignalCard(
                title: "Churn Rate",
                value: percent(churnRate),
                status: churnRate <= 0.15 ? "Healthy" : (churnRate <= 0.30 ? "Watch" : "Critical"),
                benchmark: "Target ≤ 15%",
                normalizedScore: min(max(churnRate / 0.40, 0), 1),
                higherIsBetter: false,
                tone: churnRate <= 0.15 ? AppColors.success : (churnRate <= 0.30 ? AppColors.warning : AppColors.error)
            )

            performanceSignalCard(
                title: "Retention",
                value: percent(retentionRate),
                status: retentionRate >= 0.85 ? "Strong" : (retentionRate >= 0.70 ? "Moderate" : "Weak"),
                benchmark: "Target ≥ 85%",
                normalizedScore: min(max(retentionRate, 0), 1),
                higherIsBetter: true,
                tone: retentionRate >= 0.85 ? AppColors.success : (retentionRate >= 0.70 ? AppColors.warning : AppColors.error)
            )

            performanceSignalCard(
                title: "Stocks / Sale Ratio",
                value: String(format: "%.2f", stocksToSaleRatio),
                status: stocksToSaleRatio <= 1.8 ? "Balanced" : (stocksToSaleRatio <= 2.8 ? "Elevated" : "Heavy"),
                benchmark: "Target ≤ 1.80",
                normalizedScore: min(max(stocksToSaleRatio / 3.6, 0), 1),
                higherIsBetter: false,
                tone: stocksToSaleRatio <= 1.8 ? AppColors.success : (stocksToSaleRatio <= 2.8 ? AppColors.warning : AppColors.error)
            )
        }
    }

    private func performanceSignalCard(
        title: String,
        value: String,
        status: String,
        benchmark: String,
        normalizedScore: Double,
        higherIsBetter: Bool,
        tone: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(tone)
                        .frame(width: 6, height: 6)
                    Text(status.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textPrimaryDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { proxy in
                let clamped = min(max(normalizedScore, 0), 1)
                let fillWidth = higherIsBetter ? clamped : (1 - clamped)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppColors.textPrimaryDark.opacity(0.26))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tone.opacity(0.95))
                        .frame(width: max(6, proxy.size.width * fillWidth), height: 5)
                }
            }
            .frame(height: 5)

            Text(benchmark)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.subtle)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(2.5)
            .foregroundColor(AppColors.textPrimaryDark)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private enum InventoryTrendBucket {
        case day
        case week
        case month
    }

    private var detailedInventoryBucket: InventoryTrendBucket {
        switch selectedRange {
        case .sevenDays, .thirtyDays:
            return .day
        case .ninetyDays:
            return .week
        case .sixMonths:
            return .month
        case .custom:
            let days = max(Calendar.current.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0, 0)
            if days > 120 { return .month }
            if days > 45 { return .week }
            return .day
        }
    }

    private var detailedInventoryPointLimit: Int {
        switch detailedInventoryBucket {
        case .day:
            switch selectedRange {
            case .sevenDays:
                return 7
            case .thirtyDays:
                return 30
            case .custom:
                let days = max((Calendar.current.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0) + 1, 1)
                return min(days, 45)
            case .ninetyDays, .sixMonths:
                return 30
            }
        case .week:
            return 13
        case .month:
            return 6
        }
    }

    private var detailedInventoryPoints: [(date: Date, value: Double)] {
        guard let snapshot else { return [] }
        let orderLookup = Dictionary(uniqueKeysWithValues: filteredOrders.map { ($0.id, $0) })
        let filteredItems = snapshot.orderItems.filter { orderLookup[$0.orderId] != nil }
        let grouped = Dictionary(grouping: filteredItems) { item in
            let orderDate = orderLookup[item.orderId]?.createdAt ?? Date()
            return inventoryBucketStartDate(for: orderDate)
        }
        let sortedKeys = grouped.keys.sorted()
        let points = sortedKeys.map { key in
            (date: key, value: grouped[key]?.reduce(0) { $0 + Double($1.quantity) } ?? 0)
        }
        return Array(points.suffix(detailedInventoryPointLimit))
    }

    private var detailedUnitsSeries: [Double] {
        detailedInventoryPoints.map(\.value)
    }

    private var latestInventoryPoint: (date: Date, value: Double)? {
        detailedInventoryPoints.last
    }

    private var previousInventoryPoint: (date: Date, value: Double)? {
        guard detailedInventoryPoints.count > 1 else { return nil }
        return detailedInventoryPoints[detailedInventoryPoints.count - 2]
    }

    private var recentInventoryDelta: Double? {
        guard let latest = latestInventoryPoint?.value,
              let previous = previousInventoryPoint?.value else { return nil }
        if previous == 0 { return nil }
        return (latest - previous) / previous
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

    private var detailedUnitsSold: Int {
        Int(detailedUnitsSeries.reduce(0, +))
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

    private var monthlySellThroughPoints: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let values = monthlySellThroughTrend.map { min(max($0, 0), 1) }
        let count = values.count

        return values.enumerated().map { index, value in
            let offset = (count - 1) - index
            let date = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            return (date: date, value: value)
        }
    }

    private var monthlySellThroughAverage: Double {
        guard !monthlySellThroughTrend.isEmpty else { return 0 }
        let normalized = monthlySellThroughTrend.map { min(max($0, 0), 1) }
        return normalized.reduce(0, +) / Double(normalized.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                LinearGradient(
                    colors: [AppColors.backgroundPrimary, AppColors.secondary.opacity(0.06), AppColors.backgroundPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        inventoryOverviewTrendChart

                        summaryStrip(
                            title: "Current Selection",
                            stats: [
                                ("Units Sold", "\(detailedUnitsSold)", AppColors.secondary),
                                ("On Hand", "\(filteredInventoryUnits)", AppColors.info),
                                ("Sell Through", percent(filteredSellThrough), AppColors.success)
                            ]
                        )

                        inventoryScopeHintCard

                        sectionLabel("INVENTORY SIGNALS")
                        inventorySignalsGrid

                        sectionLabel("DETAILED BREAKDOWN")
                        detailedGraphCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedRange)
            .animation(.easeInOut(duration: 0.25), value: selectedStoreId)
            .navigationTitle("Inventory Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .liquidGlass(config: .ultraThin, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.control)
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Store & Date Specific")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)

            if snapshot == nil {
                Text("Run live sync to enable per-store detailed graph.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textPrimaryDark)
            } else {
                storePicker
                rangePicker
                if selectedRange == .custom {
                    customDatePickers
                }

                if detailedUnitsSeries.isEmpty {
                    Text("No inventory movement in the selected range.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                        .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundPrimary, cornerRadius: SharpCorners.control)
                } else {
                    detailedInventoryTrendChart
                }
            }
        }
        .padding(18)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.medium)
    }

    private var inventoryOverviewTrendChart: some View {
        let points = monthlySellThroughPoints
        let maxValue = max(points.map(\.value).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sell Through (6 Months)")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("Inventory conversion trend")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                Spacer()
                Text("Avg \(percent(monthlySellThroughAverage))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.secondary)
            }

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(
                        x: .value("Month", point.date),
                        y: .value("Sell Through", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.secondary.opacity(0.28), AppColors.secondary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Sell Through", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.2))
                    .foregroundStyle(AppColors.secondary)

                    PointMark(
                        x: .value("Month", point.date),
                        y: .value("Sell Through", point.value)
                    )
                    .symbolSize(26)
                    .foregroundStyle(AppColors.secondary.opacity(0.95))
                }

                RuleMark(y: .value("Average", monthlySellThroughAverage))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(AppColors.info.opacity(0.9))
                    .annotation(position: .topLeading) {
                        Text("Average")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.info)
                    }
            }
            .frame(height: 210)
            .chartYScale(domain: 0...(min(maxValue * 1.15, 1.0)))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }
        }
        .padding(18)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.medium)
    }

    private var detailedInventoryTrendChart: some View {
        let points = detailedInventoryPoints
        let maxValue = max(points.map(\.value).max() ?? 1, 1)
        let latestLabel = latestInventoryPoint.map { displayDetailedInventoryBucketLabel(fromDate: $0.date) } ?? "-"
        let latestValue = latestInventoryPoint?.value ?? 0
        let deltaText = recentInventoryDelta.map { String(format: "%+.1f%% vs previous %@", $0 * 100, detailedInventoryBucketLabel) } ?? "Trend baseline unavailable"
        let deltaTone: Color = (recentInventoryDelta ?? 0) >= 0 ? AppColors.success : AppColors.error

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detailed Inventory Trend")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("Sell Through \(percent(filteredSellThrough)) · On-hand \(filteredInventoryUnits) units")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(latestLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("\(Int(latestValue)) units")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.secondary)
                }
            }

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Units", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.secondary.opacity(0.28), AppColors.secondary.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Units", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(AppColors.secondary)
                }

                if let latestInventoryPoint {
                    PointMark(
                        x: .value("Latest", latestInventoryPoint.date),
                        y: .value("Latest Units", latestInventoryPoint.value)
                    )
                    .symbolSize(42)
                    .foregroundStyle(AppColors.secondary)
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...(maxValue * 1.15))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel(format: detailedInventoryXAxisFormat)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(AppColors.textPrimaryDark.opacity(0.20))
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }

            Text(deltaText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(deltaTone)
        }
        .padding(18)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.medium)
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
            .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundPrimary, cornerRadius: SharpCorners.control)
        }
    }

    private var rangePicker: some View {
        Picker("Date Range", selection: $selectedRange) {
            ForEach(InsightsDateRange.allCases, id: \.self) { range in
                Text(range.shortLabel).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(4)
        .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundTertiary.opacity(0.65), cornerRadius: SharpCorners.control)
    }

    private var customDatePickers: some View {
        HStack(spacing: 8) {
            DatePicker("From", selection: $customStart, displayedComponents: .date)
                .labelsHidden()
            DatePicker("To", selection: $customEnd, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(AppSpacing.xs)
        .liquidGlass(config: .thin, backgroundColor: AppColors.backgroundPrimary, cornerRadius: SharpCorners.control)
    }

    private var selectedStoreLabel: String {
        guard let selectedStoreId else { return "All Stores" }
        return stores.first(where: { $0.id == selectedStoreId })?.name ?? "Selected Store"
    }

    private func inventoryBucketStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        switch detailedInventoryBucket {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
        }
    }

    private var detailedInventoryBucketLabel: String {
        switch detailedInventoryBucket {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        }
    }

    private var detailedInventoryXAxisFormat: Date.FormatStyle {
        switch detailedInventoryBucket {
        case .day:
            return .dateTime.day().month(.abbreviated)
        case .week:
            return .dateTime.day().month(.abbreviated)
        case .month:
            return .dateTime.month(.abbreviated)
        }
    }

    private func displayDetailedInventoryBucketLabel(fromDate date: Date) -> String {
        let formatter = DateFormatter()
        switch detailedInventoryBucket {
        case .day:
            formatter.dateFormat = "dd MMM"
            return formatter.string(from: date)
        case .week:
            formatter.dateFormat = "dd MMM"
            return "Wk of \(formatter.string(from: date))"
        case .month:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
    }

    private var inventoryScopeHintCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.secondary)

            Text("Use Store and Date filters in Detailed Breakdown to inspect inventory flow by period.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textPrimaryDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.control)
    }

    private var inventorySignalsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            inventorySignalCard(
                title: "Turnover Ratio",
                value: String(format: "%.2f", inventoryTurnoverRatio),
                status: inventoryTurnoverRatio >= 1.20 ? "Strong" : (inventoryTurnoverRatio >= 0.80 ? "Moderate" : "Weak"),
                benchmark: "Target ≥ 1.20",
                normalizedScore: min(max(inventoryTurnoverRatio / 2.0, 0), 1),
                higherIsBetter: true,
                tone: inventoryTurnoverRatio >= 1.20 ? AppColors.success : (inventoryTurnoverRatio >= 0.80 ? AppColors.warning : AppColors.error)
            )

            inventorySignalCard(
                title: "Sell Through",
                value: percent(sellThroughRate),
                status: sellThroughRate >= 0.55 ? "Healthy" : (sellThroughRate >= 0.35 ? "Watch" : "Critical"),
                benchmark: "Target ≥ 55%",
                normalizedScore: min(max(sellThroughRate, 0), 1),
                higherIsBetter: true,
                tone: sellThroughRate >= 0.55 ? AppColors.success : (sellThroughRate >= 0.35 ? AppColors.warning : AppColors.error)
            )

            inventorySignalCard(
                title: "No-Purchase Rate",
                value: percent(customerAcquisitionNoPurchaseRate),
                status: customerAcquisitionNoPurchaseRate <= 0.25 ? "Healthy" : (customerAcquisitionNoPurchaseRate <= 0.40 ? "Watch" : "Critical"),
                benchmark: "Target ≤ 25%",
                normalizedScore: min(max(customerAcquisitionNoPurchaseRate / 0.60, 0), 1),
                higherIsBetter: false,
                tone: customerAcquisitionNoPurchaseRate <= 0.25 ? AppColors.success : (customerAcquisitionNoPurchaseRate <= 0.40 ? AppColors.warning : AppColors.error)
            )

            inventorySignalCard(
                title: "After-Sales Losses",
                value: currency(afterSalesLosses),
                status: afterSalesLosses <= 25000 ? "Contained" : (afterSalesLosses <= 75000 ? "Elevated" : "Critical"),
                benchmark: "Target ≤ ₹25k",
                normalizedScore: min(max(afterSalesLosses / 100000, 0), 1),
                higherIsBetter: false,
                tone: afterSalesLosses <= 25000 ? AppColors.success : (afterSalesLosses <= 75000 ? AppColors.warning : AppColors.error)
            )
        }
    }

    private func inventorySignalCard(
        title: String,
        value: String,
        status: String,
        benchmark: String,
        normalizedScore: Double,
        higherIsBetter: Bool,
        tone: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(tone)
                        .frame(width: 6, height: 6)
                    Text(status.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textPrimaryDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { proxy in
                let clamped = min(max(normalizedScore, 0), 1)
                let fillWidth = higherIsBetter ? clamped : (1 - clamped)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppColors.textPrimaryDark.opacity(0.26))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tone.opacity(0.95))
                        .frame(width: max(6, proxy.size.width * fillWidth), height: 5)
                }
            }
            .frame(height: 5)

            Text(benchmark)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
        .liquidShadow(LiquidShadow.subtle)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(2.5)
            .foregroundColor(AppColors.textPrimaryDark)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func trendCard(title: String, subtitle: String, values: [Double], accent: Color) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        Text(title)
            .font(AppTypography.heading3)
            .foregroundColor(AppColors.textPrimaryDark)
        Text(subtitle)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)

        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), accent.opacity(0.70)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: max(20, CGFloat(value) * 86))
            }
        }
        .frame(height: 96, alignment: .bottom)
        .padding(.top, 2)
    }
    .padding(18)
    .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
    .liquidShadow(LiquidShadow.medium)
}

private func summaryStrip(title: String, stats: [(label: String, value: String, tone: Color)]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .tracking(2.5)
            .foregroundColor(AppColors.textSecondaryDark.opacity(0.8))

        HStack(spacing: 10) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 4) {
                    Text(stat.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(1)
                    Text(stat.value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .liquidGlass(config: .thin, backgroundColor: stat.tone.opacity(0.08), cornerRadius: SharpCorners.control)
            }
        }
    }
    .padding(14)
    .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
    .liquidShadow(LiquidShadow.subtle)
}

private func insightCard(title: String, value: String, tone: Color) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 42, weight: .semibold, design: .default))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundColor(AppColors.textPrimaryDark)
        }
        Spacer()
        ZStack {
            Circle()
                .fill(tone.opacity(0.13))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(tone.opacity(0.45), lineWidth: 1.1)
                .frame(width: 38, height: 38)
            Circle()
                .fill(tone.opacity(0.95))
                .frame(width: 9, height: 9)
        }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .liquidGlass(config: .regular, backgroundColor: AppColors.backgroundSecondary, cornerRadius: SharpCorners.panel)
    .overlay(alignment: .leading) {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(tone.opacity(0.75))
            .frame(width: 4, height: 54)
            .padding(.leading, 6)
    }
    .liquidShadow(LiquidShadow.medium)
}

// MARK: - Liquid Press Button Style

struct LiquidPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Create Store Sheet

struct CreateStoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var storeName = ""
    @State private var storeCity = ""
    @State private var storeCountry = ""
    @State private var selectedManager: UserDTO? = nil
    @State private var unassignedManagers: [UserDTO] = []
    @State private var isLoadingManagers = false
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
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppColors.info.opacity(0.10))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(AppColors.info)
                            }
                            Text("Add New Store")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Register a boutique or distribution center")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        // Store type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STORE TYPE")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(2)
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
                                                .background(storeType == type ? AppColors.accent : Color(uiColor: .secondarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(storeType == type ? Color.clear : Color(uiColor: .systemGray4), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Fields
                        storeFormSection {
                            storeFieldRow(label: "Store Name", icon: "building.2", placeholder: "Required", text: $storeName)
                            Divider().padding(.leading, 52)
                            storeFieldRow(label: "City", icon: "mappin", placeholder: "Required", text: $storeCity)
                            Divider().padding(.leading, 52)
                            storeFieldRow(label: "Country", icon: "globe", placeholder: "Required", text: $storeCountry)
                            Divider().padding(.leading, 52)
                            managerPickerRow
                        }

                        // Create button
                        Button {
                            Task { await createStore() }
                        } label: {
                            HStack(spacing: 8) {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                }
                                Text(isCreating ? "Creating…" : "Create Store")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isCreating ? AppColors.accent.opacity(0.6) : AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isCreating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .principal) {
                    Text("NEW STORE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
            }
            .task { await loadUnassignedManagers() }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage) }
            .alert("Store Created!", isPresented: $isCreated) {
                Button("Done") { dismiss() }
            } message: { Text("\(storeName) has been added to your store network.") }
        }
    }

    // MARK: - Manager picker row

    private var managerPickerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text("Manager")
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            if isLoadingManagers {
                ProgressView()
                    .scaleEffect(0.75)
            } else {
                Menu {
                    Button("None") { selectedManager = nil }
                    Divider()
                    ForEach(unassignedManagers) { manager in
                        Button(manager.fullName) { selectedManager = manager }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedManager?.fullName ?? "Optional")
                            .font(.system(size: 15))
                            .foregroundColor(selectedManager == nil ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .menuOrder(.fixed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Load unassigned managers

    private func loadUnassignedManagers() async {
        isLoadingManagers = true
        defer { isLoadingManagers = false }
        let managers: [UserDTO]? = try? await SupabaseManager.shared.client
            .from("users")
            .select()
            .eq("role", value: "boutique_manager")
            .eq("is_active", value: true)
            .order("first_name", ascending: true)
            .execute()
            .value
        unassignedManagers = (managers ?? []).filter { $0.storeId == nil }
    }

    @ViewBuilder
    private func storeFormSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 20)
    }

    private func storeFieldRow(label: String, icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @MainActor
    private func createStore() async {
        let trimmedName    = storeName.trimmingCharacters(in: .whitespaces)
        let trimmedCity    = storeCity.trimmingCharacters(in: .whitespaces)
        let trimmedCountry = storeCountry.trimmingCharacters(in: .whitespaces)
        let managerName    = selectedManager?.fullName ?? ""

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
            managerName: managerName,
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

            // 2 — Assign the selected manager to this store
            if let manager = selectedManager {
                struct StoreAssignPatch: Encodable { let store_id: UUID }
                _ = try? await SupabaseManager.shared.client
                    .from("users")
                    .update(StoreAssignPatch(store_id: newId))
                    .eq("id", value: manager.id.uuidString.lowercased())
                    .execute()
            }

            // 3 — Mirror into local SwiftData so StoreConfigView refreshes instantly
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
                managerName: managerName,
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
                                                .clipShape(RoundedRectangle(cornerRadius: SharpCorners.control, style: .continuous))
                                                .overlay(RoundedRectangle(cornerRadius: SharpCorners.control, style: .continuous).strokeBorder(scope == s ? Color.clear : Color(.systemGray4), lineWidth: 1))
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
                                                .clipShape(RoundedRectangle(cornerRadius: SharpCorners.control, style: .continuous))
                                                .overlay(RoundedRectangle(cornerRadius: SharpCorners.control, style: .continuous).strokeBorder(discountType == dt ? Color.clear : Color(.systemGray4), lineWidth: 1))
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
                            .clipShape(RoundedRectangle(cornerRadius: SharpCorners.panel, style: .continuous))
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
                        .clipShape(RoundedRectangle(cornerRadius: SharpCorners.panel, style: .continuous))
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
                scope: PromotionScope(rawValue: dto.promotionScope) ?? .product,
                targetProductId: dto.targetProductId,
                targetCategoryId: dto.targetCategoryId,
                discountType: PromotionDiscountType(rawValue: dto.promotionDiscountType) ?? .percentage,
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

private struct AdminClientActivityMonitorView: View {
    let snapshot: AdminInsightsSnapshot?
    let isSyncing: Bool
    let lastSyncedAt: Date?
    let generatedBy: String
    let onRefresh: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AdminClientActivityTab = .orders
    @State private var searchText = ""
    @State private var shareFile: ShareFile?
    @State private var exportErrorMessage = ""
    @State private var showExportError = false
    @State private var isExporting = false

    private var portalOrders: [OrderDTO] {
        guard let snapshot else { return [] }
        return snapshot.orders.filter { order in
            let channel = order.channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return channel == "online" || channel == "bopis" || channel == "ship_from_store"
        }
    }

    private var reservations: [ReservationDTO] {
        snapshot?.reservations ?? []
    }

    private var returnTickets: [ServiceTicketDTO] {
        guard let snapshot else { return [] }
        return snapshot.serviceTickets.filter { ticket in
            let type = ticket.type.lowercased()
            let notes = ticket.notes?.lowercased() ?? ""
            return type == RepairType.warrantyClaim.rawValue || notes.contains("exchange") || notes.contains("return")
        }
    }

    private var activePortalOrders: [OrderDTO] {
        portalOrders.filter { !["completed", "cancelled", "delivered"].contains($0.status.lowercased()) }
    }

    private var activeReservationsCount: Int {
        reservations.filter { !$0.status.lowercased().contains("cancel") && $0.expiresAt > Date() }.count
    }

    private var openReturnsCount: Int {
        returnTickets.filter { !["completed", "cancelled"].contains($0.status.lowercased()) }.count
    }

    private var clientsById: [UUID: ClientDTO] {
        Dictionary(uniqueKeysWithValues: (snapshot?.clients ?? []).map { ($0.id, $0) })
    }

    private var storesById: [UUID: StoreDTO] {
        Dictionary(uniqueKeysWithValues: (snapshot?.stores ?? []).map { ($0.id, $0) })
    }

    private var productsById: [UUID: ProductDTO] {
        Dictionary(uniqueKeysWithValues: (snapshot?.products ?? []).map { ($0.id, $0) })
    }

    private var ordersById: [UUID: OrderDTO] {
        Dictionary(uniqueKeysWithValues: portalOrders.map { ($0.id, $0) })
    }

    private var onlineRevenue: Double {
        portalOrders.reduce(0.0) { $0 + $1.grandTotal }
    }

    private var inStoreRevenue: Double {
        snapshot?.orders
            .filter { $0.channel.lowercased() == "in_store" }
            .reduce(0.0) { $0 + $1.grandTotal } ?? 0
    }

    private var filteredOrders: [OrderDTO] {
        filter(text: searchText, over: portalOrders) { order in
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
        }
    }

    private var filteredReservations: [ReservationDTO] {
        filter(text: searchText, over: reservations) { reservation in
            let client = clientsById[reservation.clientId]
            let product = productsById[reservation.productId] ?? reservation.product
            let storeName = reservation.storeId.flatMap { storesById[$0]?.name } ?? ""
            return [
                client?.fullName ?? "",
                client?.email ?? "",
                product?.name ?? "",
                reservation.status,
                storeName
            ]
        }
    }

    private var filteredReturns: [ServiceTicketDTO] {
        filter(text: searchText, over: returnTickets) { ticket in
            let client = ticket.clientId.flatMap { clientsById[$0] }
            let order = ticket.orderId.flatMap { ordersById[$0] }
            let store = storesById[ticket.storeId]
            return [
                ticket.displayTicketNumber,
                ticket.type,
                ticket.status,
                client?.fullName ?? "",
                client?.email ?? "",
                order?.orderNumber ?? "",
                store?.name ?? ""
            ]
        }
    }

    private var storeFulfillment: [AdminStoreFulfillmentRow] {
        let grouped = Dictionary(grouping: activePortalOrders, by: \.storeId)
        return grouped.map { storeId, orders in
            let store = storesById[storeId]
            let statusCounts = Dictionary(grouping: orders, by: { normalizedLabel($0.status) })
                .mapValues(\.count)
            return AdminStoreFulfillmentRow(
                storeId: storeId,
                storeName: store?.name ?? "Unknown Store",
                location: [store?.city, store?.region].compactMap { value in
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }.joined(separator: ", "),
                totalOrders: orders.count,
                pendingCount: statusCounts["Pending"] ?? 0,
                processingCount: statusCounts["Processing"] ?? 0,
                confirmedCount: statusCounts["Confirmed"] ?? 0,
                shippedCount: statusCounts["Shipped"] ?? 0
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
            } else {
                ContentUnavailableView(
                    "No Live Activity Yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Refresh the admin snapshot to load customer portal activity.")
                )
            }
        }
        .navigationTitle("Client Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundColor(AppColors.accent)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    Task { await onRefresh() }
                } label: {
                    if isSyncing {
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
                .disabled(snapshot == nil || isExporting)
            }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
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
            Text(isSyncing ? "Syncing" : "Connected")
                .font(AppTypography.micro)
                .foregroundColor(isSyncing ? AppColors.info : AppColors.success)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 4)
                .background((isSyncing ? AppColors.info : AppColors.success).opacity(0.12))
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
            summaryCard(title: "Fulfillment", value: "\(storeFulfillment.count)", subtitle: "stores involved", color: AppColors.success)
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
                Text("Export CSV")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            HStack(spacing: AppSpacing.sm) {
                comparisonColumn(title: "Online / Omnichannel", orders: portalOrders.count, revenue: onlineRevenue, color: AppColors.accent)
                comparisonColumn(title: "In-Store", orders: snapshot.orders.count - portalOrders.count, revenue: inStoreRevenue, color: AppColors.secondary)
            }

            let totalRevenue = max(onlineRevenue + inStoreRevenue, 1)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                progressRow(label: "Online Mix", ratio: onlineRevenue / totalRevenue, color: AppColors.accent)
                progressRow(label: "In-Store Mix", ratio: inStoreRevenue / totalRevenue, color: AppColors.secondary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func comparisonColumn(title: String, orders: Int, revenue: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Text(currency(revenue))
                .font(AppTypography.heading3)
                .foregroundColor(color)
            Text("\(orders) orders")
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
        .cornerRadius(AppSpacing.radiusSmall)
    }

    private func progressRow(label: String, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.backgroundPrimary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
    }

    private var fulfillmentCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("STORE FULFILLMENT STATUS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            if storeFulfillment.isEmpty {
                Text("No active client-portal orders are waiting on store fulfillment.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                ForEach(storeFulfillment.prefix(4)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.storeName)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                if !row.location.isEmpty {
                                    Text(row.location)
                                        .font(AppTypography.micro)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                            Spacer()
                            Text("\(row.totalOrders) open")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.accent)
                        }

                        HStack(spacing: AppSpacing.xs) {
                            fulfillmentPill(label: "Pending", count: row.pendingCount, color: AppColors.warning)
                            fulfillmentPill(label: "Processing", count: row.processingCount, color: AppColors.info)
                            fulfillmentPill(label: "Confirmed", count: row.confirmedCount, color: AppColors.success)
                            fulfillmentPill(label: "Shipped", count: row.shippedCount, color: AppColors.secondary)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundPrimary)
                    .cornerRadius(AppSpacing.radiusSmall)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func fulfillmentPill(label: String, count: Int, color: Color) -> some View {
        Text("\(label) \(count)")
            .font(AppTypography.micro)
            .foregroundColor(color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var filterTabs: some View {
        Picker("", selection: $selectedTab) {
            ForEach(AdminClientActivityTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondaryDark)
            TextField("Search customer, order, store or status", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.neutral500)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusSmall)
    }

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .orders:
            if filteredOrders.isEmpty {
                emptyState("No client-portal orders match the current filters.")
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(filteredOrders) { order in
                        orderRow(order)
                    }
                }
            }
        case .reservations:
            if filteredReservations.isEmpty {
                emptyState("No reservations match the current filters.")
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(filteredReservations) { reservation in
                        reservationRow(reservation)
                    }
                }
            }
        case .returns:
            if filteredReturns.isEmpty {
                emptyState("No returns or exchange requests match the current filters.")
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(filteredReturns) { ticket in
                        returnRow(ticket)
                    }
                }
            }
        case .fulfillment:
            if storeFulfillment.isEmpty {
                emptyState("No store fulfillment activity is pending.")
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(storeFulfillment) { row in
                        fulfillmentDetailRow(row)
                    }
                }
            }
        }
    }

    private func orderRow(_ order: OrderDTO) -> some View {
        let client = order.clientId.flatMap { clientsById[$0] }
        let store = storesById[order.storeId]

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.orderNumber ?? "Order \(order.id.uuidString.prefix(8))")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(client?.fullName ?? "Guest Customer")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    if let email = client?.email {
                        Text(email)
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
                Spacer()
                Text(currency(order.grandTotal))
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.accent)
            }

            HStack(spacing: AppSpacing.xs) {
                statusBadge(channelLabel(for: order.channel), color: channelColor(for: order.channel))
                statusBadge(normalizedLabel(order.status), color: statusColor(for: order.status))
            }

            Text("Fulfillment: \(store?.name ?? "Unknown Store")")
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)

            Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func reservationRow(_ reservation: ReservationDTO) -> some View {
        let client = clientsById[reservation.clientId]
        let product = productsById[reservation.productId] ?? reservation.product
        let storeName = reservation.storeId.flatMap { storesById[$0]?.name } ?? "Boutique TBD"

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product?.name ?? "Reserved Product")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(client?.fullName ?? "Unknown Client")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                statusBadge(normalizedLabel(reservation.status), color: reservationStatusColor(reservation.status))
            }

            Text(storeName)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)

            Text("Expires \(reservation.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func returnRow(_ ticket: ServiceTicketDTO) -> some View {
        let client = ticket.clientId.flatMap { clientsById[$0] }
        let order = ticket.orderId.flatMap { ordersById[$0] }
        let store = storesById[ticket.storeId]

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticket.displayTicketNumber)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(client?.fullName ?? "Unknown Client")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                statusBadge(normalizedLabel(ticket.status), color: statusColor(for: ticket.status))
            }

            HStack(spacing: AppSpacing.xs) {
                statusBadge(normalizedLabel(ticket.type), color: AppColors.warning)
                if let orderNumber = order?.orderNumber {
                    statusBadge(orderNumber, color: AppColors.info)
                }
            }

            Text("Store: \(store?.name ?? "Unknown Store")")
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func fulfillmentDetailRow(_ row: AdminStoreFulfillmentRow) -> some View {
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
                Text("\(row.totalOrders) active")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.accent)
            }

            Text("Pending \(row.pendingCount) · Processing \(row.processingCount) · Confirmed \(row.confirmedCount) · Shipped \(row.shippedCount)")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
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

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(AppSpacing.xl)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
    }

    private var syncStatusText: String {
        guard let lastSyncedAt else { return "Waiting for first sync from the client portal." }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last synced \(formatter.localizedString(for: lastSyncedAt, relativeTo: Date()))."
    }

    private func exportChannelReport() async {
        guard let snapshot else {
            exportErrorMessage = "No snapshot is loaded yet."
            showExportError = true
            return
        }

        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let fileURL = try AdminReportExportService.exportChannelComparisonCSV(
                snapshot: snapshot,
                generatedBy: generatedBy
            )
            shareFile = ShareFile(url: fileURL)
        } catch {
            exportErrorMessage = "Could not export channel report: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }

    private func normalizedLabel(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func channelLabel(for channel: String) -> String {
        switch channel.lowercased() {
        case "online": return "Online Delivery"
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
        case "ship_from_store": return AppColors.secondary
        case "in_store": return AppColors.success
        default: return AppColors.textSecondaryDark
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending", "requested", "intake":
            return AppColors.warning
        case "confirmed", "processing", "in_progress", "estimate_pending":
            return AppColors.info
        case "shipped", "delivered", "completed", "estimate_approved":
            return AppColors.success
        case "cancelled":
            return AppColors.error
        default:
            return AppColors.textSecondaryDark
        }
    }

    private func reservationStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active", "reserved":
            return AppColors.success
        case "expired":
            return AppColors.warning
        case "cancelled":
            return AppColors.error
        default:
            return AppColors.info
        }
    }

    private func filter<T>(
        text: String,
        over source: [T],
        fields: (T) -> [String]
    ) -> [T] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return source }
        return source.filter { item in
            fields(item).contains { $0.lowercased().contains(trimmed) }
        }
    }
}

private enum AdminClientActivityTab: String, CaseIterable, Identifiable {
    case orders = "Orders"
    case reservations = "Reservations"
    case returns = "Returns"
    case fulfillment = "Fulfillment"

    var id: String { rawValue }
}

private struct AdminStoreFulfillmentRow: Identifiable {
    let storeId: UUID
    let storeName: String
    let location: String
    let totalOrders: Int
    let pendingCount: Int
    let processingCount: Int
    let confirmedCount: Int
    let shippedCount: Int

    var id: UUID { storeId }
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
