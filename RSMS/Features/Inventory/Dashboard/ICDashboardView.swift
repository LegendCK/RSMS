//
//  ICDashboardView.swift
//  RSMS
//
//  Inventory Controller Dashboard — live data from Supabase via SwiftData sync.
//  Shows inventory health, today's scan activity, open repairs, and quick actions.
//

import SwiftUI
import SwiftData
import Supabase

// MARK: - ICDashboardView

struct ICDashboardView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allInventory: [InventoryByLocation]

    @State private var openRepairs: Int         = 0
    @State private var overdueRepairs: Int      = 0
    @State private var todayScans: Int          = 0
    @State private var isLoading: Bool          = false
    @State private var loadError: String?       = nil
    @State private var lowStockItems: [InventoryByLocation] = []

    // Sheet/nav state
    @State private var showInventory: Bool       = false
    @State private var showAddStock: Bool        = false

    // MARK: - Filtered inventory for current store

    private var storeId: UUID? { appState.currentStoreId }

    private var storeInventory: [InventoryByLocation] {
        guard let sid = storeId else { return allInventory }
        return allInventory.filter { $0.locationId == sid }
    }

    private var totalSKUs: Int  { storeInventory.count }
    private var outOfStock: Int { storeInventory.filter { $0.quantity == 0 }.count }
    private var lowStock: Int   { storeInventory.filter { $0.quantity > 0 && $0.quantity <= $0.reorderPoint }.count }
    private var inStock: Int    { storeInventory.filter { $0.quantity > $0.reorderPoint }.count }

    private var icName: String {
        let full = appState.currentUserProfile?.fullName.trimmingCharacters(in: .whitespaces) ?? ""
        return full.isEmpty ? "Controller" : full
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    greetingHeader
                    inventoryHealthSection
                    todayActivitySection
                    quickActionsSection
                    if !lowStockItems.isEmpty {
                        lowStockAlertsSection
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .refreshable { await loadDashboard() }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.accent)
                        .scaleEffect(0.85)
                }
            }
        }
        .task { await loadDashboard() }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryStockUpdated)) { _ in
            Task { await loadDashboard() }
        }
        .navigationDestination(isPresented: $showInventory) {
            ManagerInventoryView()
        }
        .sheet(isPresented: $showAddStock) {
            InventoryAddStockView()
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(greetingText())
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .textCase(.uppercase)
                    .tracking(1.5)

                Text(icName)
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text("Inventory Controller")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
    }

    // MARK: - Inventory Health

    private var inventoryHealthSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Inventory Health", icon: "chart.bar.fill")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.sm),
                GridItem(.flexible(), spacing: AppSpacing.sm),
                GridItem(.flexible(), spacing: AppSpacing.sm)
            ], spacing: AppSpacing.sm) {
                metricTile(
                    value: "\(totalSKUs)",
                    label: "Total SKUs",
                    icon: "square.stack.3d.up.fill",
                    color: AppColors.info
                )
                metricTile(
                    value: "\(lowStock)",
                    label: "Low Stock",
                    icon: "exclamationmark.triangle.fill",
                    color: AppColors.warning
                )
                metricTile(
                    value: "\(outOfStock)",
                    label: "Out of Stock",
                    icon: "xmark.circle.fill",
                    color: AppColors.error
                )
            }

            // Stock health bar
            if totalSKUs > 0 {
                stockHealthBar
            }
        }
    }

    private var stockHealthBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Stock Distribution")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    let inPct  = CGFloat(inStock)   / CGFloat(totalSKUs)
                    let lowPct = CGFloat(lowStock)  / CGFloat(totalSKUs)
                    let outPct = CGFloat(outOfStock) / CGFloat(totalSKUs)

                    if inStock > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.success)
                            .frame(width: geo.size.width * inPct)
                    }
                    if lowStock > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.warning)
                            .frame(width: geo.size.width * lowPct)
                    }
                    if outOfStock > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.error)
                            .frame(width: max(geo.size.width * outPct, 4))
                    }
                }
            }
            .frame(height: 8)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(4)

            HStack {
                legendDot(color: AppColors.success,  label: "In Stock")
                Spacer()
                legendDot(color: AppColors.warning,  label: "Low")
                Spacer()
                legendDot(color: AppColors.error,    label: "Out")
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Today's Activity

    private var todayActivitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Today's Activity", icon: "calendar.badge.clock")

            HStack(spacing: AppSpacing.sm) {
                activityCard(
                    value: "\(todayScans)",
                    label: "Scans Today",
                    icon: "barcode.viewfinder",
                    color: AppColors.accent
                )
                activityCard(
                    value: "\(openRepairs)",
                    label: "Open Repairs",
                    icon: "wrench.and.screwdriver.fill",
                    color: overdueRepairs > 0 ? AppColors.error : AppColors.info
                )
            }

            if overdueRepairs > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.error)

                    Text("\(overdueRepairs) repair\(overdueRepairs == 1 ? "" : "s") past SLA deadline")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.error)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.error.opacity(0.08))
                .cornerRadius(AppSpacing.radiusSmall)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Quick Actions", icon: "bolt.fill")

            VStack(spacing: AppSpacing.xs) {
                quickActionRow(
                    icon: "shippingbox.fill",
                    title: "View Inventory",
                    subtitle: "Browse all SKUs and stock levels",
                    color: AppColors.info
                ) {
                    showInventory = true
                }

                GoldDivider()

                quickActionRow(
                    icon: "plus.square.fill",
                    title: "Add Stock",
                    subtitle: "Generate serialized barcodes",
                    color: AppColors.success
                ) {
                    showAddStock = true
                }

                GoldDivider()

                quickActionRow(
                    icon: "barcode.viewfinder",
                    title: "Start Scan Session",
                    subtitle: "Scan IN / OUT / Audit items",
                    color: AppColors.accent
                ) {
                    NotificationCenter.default.post(name: Notification.Name("switchToScannerTab"), object: nil)
                }

                GoldDivider()

                quickActionRow(
                    icon: "wrench.and.screwdriver.fill",
                    title: "New Repair Ticket",
                    subtitle: "Log a new service intake",
                    color: AppColors.warning
                ) {
                    NotificationCenter.default.post(name: Notification.Name("switchToRepairsTab"), object: nil)
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusLarge)
        }
    }

    // MARK: - Low Stock Alerts

    private var lowStockAlertsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Stock Alerts", icon: "exclamationmark.triangle.fill")

            VStack(spacing: 0) {
                ForEach(Array(lowStockItems.prefix(5).enumerated()), id: \.offset) { index, item in
                    stockAlertRow(item)
                    if index < min(lowStockItems.prefix(5).count, 5) - 1 {
                        GoldDivider()
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusLarge)

            if lowStockItems.count > 5 {
                Text("+ \(lowStockItems.count - 5) more items need attention")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Reusable Sub-views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.accent)

            Text(title.uppercased())
                .font(AppTypography.overline)
                .tracking(1.5)
                .foregroundColor(AppColors.accent)
        }
    }

    private func metricTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(value)
                .font(AppTypography.heading2)
                .foregroundColor(AppColors.textPrimaryDark)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(AppTypography.nano)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.xs)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func activityCard(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .frame(maxWidth: .infinity)
    }

    private func quickActionRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.chevron)
                    .foregroundColor(AppColors.neutral400)
            }
        }
        .buttonStyle(.plain)
    }

    private func stockAlertRow(_ item: InventoryByLocation) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(item.quantity == 0 ? AppColors.error.opacity(0.12) : AppColors.warning.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: item.quantity == 0 ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(item.quantity == 0 ? AppColors.error : AppColors.warning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)

                Text(item.categoryName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.quantity)")
                    .font(AppTypography.label)
                    .foregroundColor(item.quantity == 0 ? AppColors.error : AppColors.warning)

                Text("of \(item.reorderPoint) min")
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AppTypography.nano)
                .foregroundColor(AppColors.textSecondaryDark)
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadDashboard() async {
        guard !isLoading else { return }
        isLoading  = true
        loadError  = nil

        // Refresh local inventory from Supabase
        do {
            try await InventorySyncService.shared.syncInventory(modelContext: modelContext)
        } catch {
            print("[ICDashboard] Inventory sync failed: \(error.localizedDescription)")
        }

        // Build low-stock list from SwiftData
        lowStockItems = storeInventory
            .filter { $0.quantity <= $0.reorderPoint }
            .sorted { $0.quantity < $1.quantity }

        // Fetch open repairs from Supabase
        if let sid = storeId {
            do {
                let tickets = try await ServiceTicketService.shared.fetchTickets(storeId: sid)
                let open = tickets.filter {
                    $0.status != RepairStatus.completed.rawValue &&
                    $0.status != RepairStatus.cancelled.rawValue
                }
                openRepairs    = open.count
                overdueRepairs = open.filter { $0.isOverdue }.count
            } catch {
                print("[ICDashboard] Repair fetch failed: \(error.localizedDescription)")
            }
        }

        // Fetch today's scan count from Supabase
        await loadTodayScanCount()

        isLoading = false
    }

    @MainActor
    private func loadTodayScanCount() async {
        do {
            let client = SupabaseManager.shared.client
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startStr = formatter.string(from: startOfDay)

            // Count scan_log rows created today for this store's sessions
            struct ScanLogCount: Decodable { let count: Int }
            let response = try await client
                .from("scan_logs")
                .select("id", head: false, count: .exact)
                .gte("scanned_at", value: startStr)
                .execute()

            todayScans = response.count ?? 0
        } catch {
            print("[ICDashboard] Scan count fetch failed: \(error.localizedDescription)")
            todayScans = 0
        }
    }

    // MARK: - Helpers

    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default:      return "Good Evening"
        }
    }
}

#Preview {
    ICDashboardView()
        .environment(AppState())
        .modelContainer(for: [InventoryByLocation.self], inMemory: true)
}
