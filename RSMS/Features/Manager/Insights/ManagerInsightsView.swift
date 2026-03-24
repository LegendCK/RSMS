//
//  ManagerInsightsView.swift
//  RSMS
//
//  Boutique Manager insights tab.
//  All data is live from ManagerDashboardService (snapshot) and
//  ManagerInsightsService (order-item level product mix).
//  Cached in UserDefaults — viewable offline.
//

import SwiftUI
import SwiftData

// MARK: - Root View

struct ManagerInsightsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSection = 0

    // Snapshot from ManagerDashboardService
    @State private var snapshot: ManagerDashboardSnapshot?
    // Order-item-level data from ManagerInsightsService
    @State private var insightsSnap: ManagerInsightsSnapshot?

    @State private var isLoading = false
    @State private var isShowingCachedData = false
    @State private var loadError: String?

    private let dashService = ManagerDashboardService.shared
    private let insightsService = ManagerInsightsService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if isLoading && snapshot == nil {
                    insightsLoadingView
                } else if let error = loadError, snapshot == nil {
                    insightsErrorView(message: error)
                } else {
                    VStack(spacing: 0) {
                        // Cached data banner
                        if isShowingCachedData {
                            cachedBanner
                        }

                        Picker("", selection: $selectedSection) {
                            Text("Revenue").tag(0)
                            Text("Products").tag(1)
                            Text("Staff").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.sm)

                        if let snap = snapshot {
                            switch selectedSection {
                            case 0: MgrRevenueSubview(snapshot: snap)
                            case 1: MgrProductInsightsSubview(
                                        snapshot: snap,
                                        insightsSnap: insightsSnap
                                    )
                            case 2: MgrStaffInsightsSubview(snapshot: snap)
                            default: MgrRevenueSubview(snapshot: snap)
                            }
                        } else {
                            insufficientDataView
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Insights")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadData(forceRefresh: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(AppTypography.bellIcon)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .task(id: appState.currentStoreId) {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData(forceRefresh: Bool = false) async {
        guard let storeId = appState.currentStoreId else { return }

        // Show cached immediately
        if !forceRefresh {
            if let cached = dashService.cachedSnapshot(for: storeId) {
                snapshot = cached
                isShowingCachedData = true
            }
            if let cachedInsights = insightsService.cachedSnapshot(for: storeId) {
                insightsSnap = cachedInsights
            }
        }

        isLoading = true
        loadError = nil

        do {
            async let freshSnap = dashService.refreshSnapshot(for: storeId)
            async let freshInsights = insightsService.refreshSnapshot(for: storeId)

            let (s, i) = try await (freshSnap, freshInsights)
            snapshot = s
            insightsSnap = i
            isShowingCachedData = false
        } catch {
            if snapshot != nil {
                isShowingCachedData = true
            } else {
                loadError = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Auxiliary Views

    private var insightsLoadingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.accent)
                .scaleEffect(1.2)
            Text("Loading insights…")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Syncing orders, products, and staff data from your boutique.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func insightsErrorView(message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppColors.warning)
            Text("Unable to Load Insights")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Button { Task { await loadData(forceRefresh: true) } } label: {
                Text("Retry")
                    .font(AppTypography.label)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var insufficientDataView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppColors.textSecondaryDark.opacity(0.5))
            Text("Insufficient data for insights.")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Once your boutique records orders and appointments, insights will appear here.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cachedBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "wifi.slash")
                .foregroundColor(AppColors.warning)
            Text("Showing last synced data. Pull to refresh.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.warning.opacity(0.1))
    }
}

// MARK: - Revenue Subview

struct MgrRevenueSubview: View {
    let snapshot: ManagerDashboardSnapshot

    private var sales: ManagerDashboardSalesMetrics { snapshot.sales }
    private var hasData: Bool { sales.transactions > 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if !hasData {
                emptyState("Insufficient data for insights.",
                           detail: "No transactions recorded for this month yet.")
                    .padding(.top, AppSpacing.xxxl)
            } else {
                VStack(spacing: AppSpacing.xl) {
                    // Hero revenue card
                    VStack(spacing: AppSpacing.xs) {
                        Text(currency(sales.actualRevenue))
                            .font(AppTypography.displayLarge)
                            .foregroundColor(AppColors.textPrimaryDark)

                        HStack(spacing: 4) {
                            let progress = sales.targetProgress
                            Image(systemName: progress >= 1 ? "checkmark.circle.fill" : "arrow.up.right")
                                .font(AppTypography.trendArrow)
                                .foregroundColor(progressColor(progress))
                            Text("\(Int((progress * 100).rounded()))% of \(currency(sales.targetRevenue)) target")
                                .font(AppTypography.caption)
                                .foregroundColor(progressColor(progress))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // KPI target rows
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sLabel("TARGETS")
                        targetRow(
                            label: "Monthly Target",
                            current: currency(sales.actualRevenue),
                            target: currency(sales.targetRevenue),
                            pct: sales.targetProgress
                        )
                        targetRow(
                            label: "Avg. Ticket",
                            current: currency(sales.averageTicket),
                            target: currency(sales.targetRevenue / max(Double(sales.transactions), 1) * 1.15),
                            pct: min(sales.averageTicket / max(sales.targetRevenue / Double(max(sales.transactions, 1)) * 1.15, 1), 1)
                        )
                        targetRow(
                            label: "Transactions",
                            current: "\(sales.transactions)",
                            target: "—",
                            pct: min(Double(sales.transactions) / 50.0, 1)
                        )
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Conversion & clients
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sLabel("PERFORMANCE")
                        statRow(label: "Conversion Rate", value: percent(sales.conversionRate))
                        statRow(label: "Unique Clients",  value: "\(sales.uniqueClients)")
                        statRow(label: "Revenue Gap",
                                value: sales.revenueGap > 0
                                    ? "\(currency(sales.revenueGap)) to target"
                                    : "Ahead by \(currency(abs(sales.revenueGap)))")
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Appointment funnel
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sLabel("APPOINTMENT FUNNEL")
                        let appt = snapshot.appointments
                        statRow(label: "Total Booked",    value: "\(appt.totalBooked)")
                        statRow(label: "Completed",       value: "\(appt.completed)")
                        statRow(label: "Completion Rate", value: percent(appt.completionRate))
                        statRow(label: "No-shows",        value: "\(appt.noShow)")
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func targetRow(label: String, current: String, target: String, pct: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text("\(current) / \(target)").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppColors.backgroundTertiary).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(pct >= 0.8 ? AppColors.success : AppColors.warning)
                        .frame(width: g.size.width * min(max(pct, 0), 1), height: 6)
                }
            }.frame(height: 6)
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            Text(value).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
        }
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressColor(_ p: Double) -> Color {
        p >= 1 ? AppColors.success : p >= 0.8 ? AppColors.warning : AppColors.error
    }

    private func currency(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "INR"
        f.maximumFractionDigits = v >= 10_000 ? 0 : 2
        return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
}

// MARK: - Product Insights Subview

struct MgrProductInsightsSubview: View {
    let snapshot: ManagerDashboardSnapshot
    let insightsSnap: ManagerInsightsSnapshot?

    @Query private var allProducts: [Product]

    /// Minimum orders before we show product insights
    private var hasEnoughData: Bool {
        guard let snap = insightsSnap else { return false }
        return snap.orderItems.count >= 3
    }

    /// Top 5 products by units sold
    private var topSellers: [ProductSalesSummary] {
        guard let snap = insightsSnap else { return [] }
        var totals: [UUID: (units: Int, revenue: Double)] = [:]
        for item in snap.orderItems {
            let existing = totals[item.productId] ?? (0, 0)
            totals[item.productId] = (existing.units + item.quantity, existing.revenue + item.lineTotal)
        }
        let productLookup = Dictionary(uniqueKeysWithValues: allProducts.map { ($0.id, $0) })
        return totals
            .sorted { $0.value.units > $1.value.units }
            .prefix(5)
            .compactMap { (productId, vals) -> ProductSalesSummary? in
                guard let product = productLookup[productId] else { return nil }
                return ProductSalesSummary(
                    id: productId,
                    name: product.name,
                    categoryName: product.categoryName,
                    unitsSold: vals.units,
                    revenue: vals.revenue
                )
            }
    }

    /// Category revenue breakdown
    private var categoryMix: [(name: String, pct: Double, revenue: Double)] {
        guard let snap = insightsSnap else { return [] }
        let productLookup = Dictionary(uniqueKeysWithValues: allProducts.map { ($0.id, $0) })
        var catRevenue: [String: Double] = [:]
        for item in snap.orderItems {
            let catName = productLookup[item.productId]?.categoryName ?? "Other"
            catRevenue[catName, default: 0] += item.lineTotal
        }
        let total = catRevenue.values.reduce(0, +)
        guard total > 0 else { return [] }
        return catRevenue
            .map { (name: $0.key, pct: $0.value / total, revenue: $0.value) }
            .sorted { $0.revenue > $1.revenue }
    }

    /// Slow movers: high stock, low recent sales
    private var slowMovers: [Product] {
        guard let snap = insightsSnap else { return [] }
        let soldProductIds = Set(snap.orderItems.map { $0.productId })
        // Products with stock but 0 recent sales, up to 3
        let unsold = allProducts
            .filter { $0.stockCount > 0 && !soldProductIds.contains($0.id) }
            .sorted { $0.stockCount > $1.stockCount }
            .prefix(3)
        if unsold.isEmpty {
            // Fall back to lowest-sold in-stock products
            var unitsSold: [UUID: Int] = [:]
            for item in snap.orderItems { unitsSold[item.productId, default: 0] += item.quantity }
            return allProducts
                .filter { $0.stockCount > 0 }
                .sorted { (unitsSold[$0.id] ?? 0) < (unitsSold[$1.id] ?? 0) }
                .prefix(3)
                .map { $0 }
        }
        return Array(unsold)
    }

    private let catColors: [Color] = [
        AppColors.accent, AppColors.secondary, AppColors.info,
        AppColors.success, AppColors.warning
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            if !hasEnoughData {
                emptyState("Insufficient data for insights.",
                           detail: "Product insights appear once your boutique has recorded at least a few orders.")
                    .padding(.top, AppSpacing.xxxl)
            } else {
                VStack(spacing: AppSpacing.lg) {
                    // Top sellers
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sLabel("TOP SELLERS")
                        if topSellers.isEmpty {
                            Text("No product data available yet.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                        } else {
                            ForEach(Array(topSellers.enumerated()), id: \.element.id) { idx, p in
                                HStack(spacing: AppSpacing.sm) {
                                    Text("#\(idx + 1)")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(p.name)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                            .lineLimit(1)
                                        Text(p.categoryName)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text("\(p.unitsSold) units")
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                        Text(currency(p.revenue))
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }
                    }

                    // Category mix
                    if !categoryMix.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sLabel("CATEGORY MIX")
                            ForEach(Array(categoryMix.enumerated()), id: \.offset) { idx, cat in
                                catBar(
                                    name: cat.name,
                                    pct: cat.pct,
                                    color: catColors[idx % catColors.count]
                                )
                            }
                        }
                    }

                    // Slow movers
                    if !slowMovers.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sLabel("SLOW MOVERS")
                            ForEach(slowMovers, id: \.id) { p in
                                HStack(spacing: AppSpacing.sm) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(p.name)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                            .lineLimit(1)
                                        Text(p.categoryName)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                    }
                                    Spacer()
                                    Text("\(p.stockCount) in stock")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.neutral700)
                                    Text("Low demand")
                                        .font(AppTypography.demandBadge)
                                        .foregroundColor(AppColors.warning)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.warning.opacity(0.12))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }
                    }
                }
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func catBar(name: String, pct: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text("\(Int((pct * 100).rounded()))%").font(AppTypography.caption).foregroundColor(color)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppColors.backgroundTertiary).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: g.size.width * CGFloat(pct), height: 6)
                }
            }.frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func currency(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "INR"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
    }
}

// MARK: - Staff Insights Subview

struct MgrStaffInsightsSubview: View {
    let snapshot: ManagerDashboardSnapshot

    private var staff: [ManagerDashboardStaffPerformance] { snapshot.staffRanking }
    private var hasData: Bool { !staff.isEmpty }
    private var topRevenue: Double { max(staff.first?.revenue ?? 0, 1) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if !hasData {
                emptyState("Insufficient data for insights.",
                           detail: "Staff insights appear once associates have been assigned to orders or appointments.")
                    .padding(.top, AppSpacing.xxxl)
            } else {
                VStack(spacing: AppSpacing.lg) {
                    // Sales leaderboard
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sLabel("SALES LEADERBOARD")
                        ForEach(Array(staff.prefix(5).enumerated()), id: \.element.id) { idx, member in
                            leaderRow(rank: idx + 1, member: member)
                        }
                    }

                    // Conversion rates
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sLabel("CONVERSION RATES")
                        ForEach(staff.prefix(5), id: \.id) { member in
                            convRow(member: member)
                        }
                    }

                    // Appointments handled
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sLabel("APPOINTMENTS HANDLED")
                        ForEach(staff.prefix(5), id: \.id) { member in
                            apptRow(member: member)
                        }
                    }

                    // Recommendations from operational signals
                    if !snapshot.operationalSignals.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sLabel("STAFFING RECOMMENDATIONS")
                            ForEach(snapshot.operationalSignals) { signal in
                                HStack(alignment: .top, spacing: AppSpacing.sm) {
                                    Circle()
                                        .fill(signalColor(signal.severity).opacity(0.16))
                                        .frame(width: 34, height: 34)
                                        .overlay {
                                            Image(systemName: signalIcon(signal.severity))
                                                .foregroundColor(signalColor(signal.severity))
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(signal.title)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                        Text(signal.detail)
                                            .font(AppTypography.bodySmall)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }
                    }
                }
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func leaderRow(rank: Int, member: ManagerDashboardStaffPerformance) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Text("#\(rank)")
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    Text("\(member.transactions) transactions")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(currency(member.revenue))
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.accent)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppColors.backgroundTertiary).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3).fill(AppColors.secondary)
                        .frame(width: g.size.width * CGFloat(member.revenue / topRevenue), height: 4)
                }
            }.frame(height: 4)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func convRow(member: ManagerDashboardStaffPerformance) -> some View {
        HStack {
            Text(member.name)
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
                .lineLimit(1)
            Spacer()
            Text(percent(member.conversionRate))
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            let isGood = member.conversionRate >= 0.40
            Text(isGood ? "On track" : "Needs focus")
                .font(AppTypography.demandBadge)
                .foregroundColor(isGood ? AppColors.success : AppColors.warning)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background((isGood ? AppColors.success : AppColors.warning).opacity(0.12))
                .cornerRadius(4)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func apptRow(member: ManagerDashboardStaffPerformance) -> some View {
        HStack {
            Text(member.name)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .lineLimit(1)
            Spacer()
            Text("\(member.appointmentsHandled) appointments")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func signalColor(_ s: ManagerDashboardSignalSeverity) -> Color {
        switch s { case .positive: return AppColors.success; case .attention: return AppColors.warning; case .warning: return AppColors.error }
    }

    private func signalIcon(_ s: ManagerDashboardSignalSeverity) -> String {
        switch s { case .positive: return "arrow.up.right"; case .attention: return "exclamationmark.circle"; case .warning: return "exclamationmark.triangle.fill" }
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func currency(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "INR"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
}

// MARK: - Shared Helpers

private func emptyState(_ title: String, detail: String) -> some View {
    VStack(spacing: AppSpacing.lg) {
        Image(systemName: "chart.bar.xaxis")
            .font(.system(size: 40, weight: .light))
            .foregroundColor(AppColors.textSecondaryDark.opacity(0.5))
        Text(title)
            .font(AppTypography.heading3)
            .foregroundColor(AppColors.textPrimaryDark)
            .multilineTextAlignment(.center)
        Text(detail)
            .font(AppTypography.bodySmall)
            .foregroundColor(AppColors.textSecondaryDark)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.xl)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, AppSpacing.screenHorizontal)
}

// MARK: - Preview

#Preview {
    let appState = AppState()
    appState.currentUserRole = .boutiqueManager
    appState.currentStoreId = UUID()

    return ManagerInsightsView()
        .environment(appState)
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
