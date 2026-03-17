//
//  ManagerDashboardView.swift
//  RSMS
//
//  Boutique Manager store command center.
//  Maroon gradient header, KPIs, alerts, top sellers, staff, quick actions.
//

import SwiftUI
import SwiftData

struct ManagerDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var allStores: [StoreLocation]

    @State private var snapshot: ManagerDashboardSnapshot?
    @State private var showProfile = false
    @State private var isShowingCachedData = false
    @State private var statusMessage: String?

    private let service = ManagerDashboardService.shared

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            LinearGradient(
                colors: [AppColors.accent.opacity(0.14), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.34)
            )
            .ignoresSafeArea()

            if appState.currentUserRole != .boutiqueManager {
                restrictedAccessView
            } else if appState.currentStoreId == nil {
                unavailableStoreView
            } else {
                dashboardContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MAISON LUXE")
                    .font(.system(size: 12, weight: .black))
                    .tracking(4)
                    .foregroundColor(AppColors.textPrimaryDark)
            }

            if appState.currentUserRole == .boutiqueManager {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showProfile = true }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.12))
                                .frame(width: 30, height: 30)

                            Text(managerInitials)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ManagerProfileView()
        }
        .task(id: appState.currentStoreId) {
            await loadDashboard()
        }
    }

    private var dashboardContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                dashboardHeader

                if let statusMessage {
                    statusBanner(message: statusMessage, isWarning: isShowingCachedData)
                }

                if let snapshot {
                    heroMetrics(snapshot)
                    supportingMetrics(snapshot)
                    operationalSignals(snapshot)
                    staffPerformanceSection(snapshot)
                    appointmentSection(snapshot)
                } else {
                    loadingState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .refreshable {
            await loadDashboard(forceRefresh: true)
        }
    }

    private var dashboardHeader: some View {
        dashboardCard(
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("GOOD \(greeting.uppercased())")
                                .font(AppTypography.overline)
                                .tracking(3)
                                .foregroundColor(AppColors.accent)

                            Text(managerFirstName)
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(AppColors.textPrimaryDark)

                            Text("\(currentStoreName) · Boutique Performance Command")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)

                            Text(headerSubtitle)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        syncPill
                    }

                    if let snapshot {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: AppSpacing.sm) {
                                labelPill(
                                    title: monthLabel(from: snapshot.periodStart),
                                    color: AppColors.secondary
                                )
                                labelPill(
                                    title: isShowingCachedData ? "Cached KPI data" : "Live KPI data",
                                    color: isShowingCachedData ? AppColors.warning : AppColors.success
                                )
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                labelPill(
                                    title: monthLabel(from: snapshot.periodStart),
                                    color: AppColors.secondary
                                )
                                labelPill(
                                    title: isShowingCachedData ? "Cached KPI data" : "Live KPI data",
                                    color: isShowingCachedData ? AppColors.warning : AppColors.success
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            glassConfig: .regular,
            padding: AppSpacing.md
        )
    }

    private func heroMetrics(_ snapshot: ManagerDashboardSnapshot) -> some View {
        LazyVGrid(columns: heroMetricColumns, spacing: AppSpacing.md) {
            dashboardCard(
                content: {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            sectionTitle("SALES VS TARGET")
                            Spacer()
                            performanceBadge(progress: snapshot.sales.targetProgress)
                        }

                        HStack(alignment: .lastTextBaseline) {
                            Text(currency(snapshot.sales.actualRevenue))
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Target")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                Text(currency(snapshot.sales.targetRevenue))
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }
                        }

                        ProgressView(value: min(max(snapshot.sales.targetProgress, 0), 1.25))
                            .tint(progressColor(progress: snapshot.sales.targetProgress))

                        HStack {
                            Text("Gap")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                            Spacer()
                            Text(snapshot.sales.revenueGap > 0 ? currency(snapshot.sales.revenueGap) : "Ahead by \(currency(abs(snapshot.sales.revenueGap)))")
                                .font(AppTypography.label)
                                .foregroundColor(progressColor(progress: snapshot.sales.targetProgress))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .frame(minHeight: 164, alignment: .topLeading)
                },
                glassConfig: .thin,
                padding: AppSpacing.md
            )

            dashboardCard(
                content: {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            sectionTitle("CONVERSION RATE")
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(AppColors.secondary)
                        }

                        Text(percent(snapshot.sales.conversionRate))
                            .font(AppTypography.displaySmall)
                            .foregroundColor(AppColors.textPrimaryDark)

                        Text("Transactions closed from attended appointments this month")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)

                        HStack(spacing: AppSpacing.md) {
                            compactMetric(label: "Transactions", value: "\(snapshot.sales.transactions)")
                            compactMetric(label: "Clients", value: "\(snapshot.sales.uniqueClients)")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .frame(minHeight: 164, alignment: .topLeading)
                },
                glassConfig: .thin,
                padding: AppSpacing.md
            )
        }
    }

    private func supportingMetrics(_ snapshot: ManagerDashboardSnapshot) -> some View {
        LazyVGrid(columns: metricColumns, spacing: AppSpacing.md) {
            dashboardMetricCard(
                label: "Transactions",
                value: "\(snapshot.sales.transactions)",
                detail: snapshot.sales.transactions == 0 ? "No sales recorded yet" : "Month-to-date closed",
                icon: "creditcard.fill",
                tint: AppColors.accent
            )

            dashboardMetricCard(
                label: "Average Ticket",
                value: currency(snapshot.sales.averageTicket),
                detail: "Per completed order",
                icon: "dollarsign.gauge.chart.leftthird.topthird.rightthird",
                tint: AppColors.secondary
            )

            dashboardMetricCard(
                label: "Upcoming Today",
                value: "\(snapshot.appointments.upcomingToday)",
                detail: snapshot.appointments.upcomingThisWeek == 0 ? "No further appointments this week" : "\(snapshot.appointments.upcomingThisWeek) this week",
                icon: "calendar.badge.clock",
                tint: AppColors.info
            )

            dashboardMetricCard(
                label: "Appointment Completion",
                value: percent(snapshot.appointments.completionRate),
                detail: "\(snapshot.appointments.completed) completed",
                icon: "checkmark.circle.fill",
                tint: snapshot.appointments.completionRate >= 0.7 ? AppColors.success : AppColors.warning
            )
        }
    }

    private func operationalSignals(_ snapshot: ManagerDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("OPERATIONAL SIGNALS")

            ForEach(snapshot.operationalSignals) { signal in
                dashboardCard(
                    content: {
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            Circle()
                                .fill(signalColor(signal.severity).opacity(0.16))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: signalIcon(signal.severity))
                                        .foregroundColor(signalColor(signal.severity))
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(signal.title)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)

                                Text(signal.detail)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }

                            Spacer()
                        }
                    },
                    glassConfig: .regular,
                    padding: AppSpacing.md
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func staffPerformanceSection(_ snapshot: ManagerDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                sectionTitle("STAFF PERFORMANCE")
                Spacer()
                Text("Ranked by revenue")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            if snapshot.staffRanking.isEmpty {
                dashboardCard(
                    content: {
                        Text("No staff performance data is available yet for this boutique.")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    },
                    glassConfig: .regular,
                    padding: AppSpacing.md
                )
            } else {
                let topRevenue = max(snapshot.staffRanking.first?.revenue ?? 0, 1)

                ForEach(Array(snapshot.staffRanking.prefix(5).enumerated()), id: \.element.id) { index, performer in
                    dashboardCard(
                        content: {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack(alignment: .center, spacing: AppSpacing.md) {
                                    Text("#\(index + 1)")
                                        .font(AppTypography.overline)
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: 34, height: 34)
                                        .background(AppColors.accent.opacity(0.1))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(performer.name)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.9)
                                        Text(performer.role)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(currency(performer.revenue))
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                        Text("\(performer.transactions) sales · \(percent(performer.conversionRate)) conv.")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(alignment: .trailing)
                                }

                                ProgressView(value: performer.revenue / topRevenue)
                                    .tint(AppColors.secondary)

                                Text("\(performer.appointmentsHandled) appointments handled")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        },
                        glassConfig: .regular,
                        padding: AppSpacing.md
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appointmentSection(_ snapshot: ManagerDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("APPOINTMENT STATISTICS")

            dashboardCard(
                content: {
                    ViewThatFits(in: .horizontal) {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack(alignment: .top, spacing: AppSpacing.md) {
                                compactMetric(label: "Booked", value: "\(snapshot.appointments.totalBooked)")
                                compactMetric(label: "Confirmed", value: "\(snapshot.appointments.confirmed)")
                                compactMetric(label: "Completed", value: "\(snapshot.appointments.completed)")
                            }

                            Divider()

                            HStack(alignment: .top, spacing: AppSpacing.md) {
                                compactMetric(label: "Cancelled", value: "\(snapshot.appointments.cancelled)")
                                compactMetric(label: "No Show", value: "\(snapshot.appointments.noShow)")
                                compactMetric(label: "This Week", value: "\(snapshot.appointments.upcomingThisWeek)")
                            }
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                compactMetric(label: "Booked", value: "\(snapshot.appointments.totalBooked)")
                                compactMetric(label: "Confirmed", value: "\(snapshot.appointments.confirmed)")
                                compactMetric(label: "Completed", value: "\(snapshot.appointments.completed)")
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                compactMetric(label: "Cancelled", value: "\(snapshot.appointments.cancelled)")
                                compactMetric(label: "No Show", value: "\(snapshot.appointments.noShow)")
                                compactMetric(label: "This Week", value: "\(snapshot.appointments.upcomingThisWeek)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                },
                glassConfig: .regular,
                padding: AppSpacing.md
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingState: some View {
        dashboardCard(
            content: {
                VStack(spacing: AppSpacing.md) {
                    ProgressView()
                        .tint(AppColors.accent)
                    Text("Loading boutique KPI data")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("Orders, appointments, and staff rankings are syncing now.")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            },
            glassConfig: .regular,
            padding: AppSpacing.md
        )
    }

    private var restrictedAccessView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(AppColors.warning)

            Text("Dashboard access is restricted")
                .font(AppTypography.heading2)
                .foregroundColor(AppColors.textPrimaryDark)

            Text("Only Boutique Managers can access boutique performance metrics.")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableStoreView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(AppColors.secondary)

            Text("No boutique is assigned")
                .font(AppTypography.heading2)
                .foregroundColor(AppColors.textPrimaryDark)

            Text("A store assignment is required before manager KPIs can be loaded.")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var managerInitials: String {
        let pieces = appState.currentUserName.split(separator: " ")
        if pieces.count >= 2 {
            return "\(pieces[0].prefix(1))\(pieces[1].prefix(1))".uppercased()
        }
        return String(appState.currentUserName.prefix(2)).uppercased()
    }

    private var managerFirstName: String {
        appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Manager"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Morning" : hour < 17 ? "Afternoon" : "Evening"
    }

    private var currentStoreName: String {
        guard let storeId = appState.currentStoreId else { return "Boutique" }
        return allStores.first(where: { $0.id == storeId })?.name ?? "Current Boutique"
    }

    private var headerSubtitle: String {
        if let snapshot {
            return "Last synchronization \(snapshot.syncedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "KPI metrics will appear as soon as the current boutique finishes syncing."
    }

    private var syncPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isShowingCachedData ? AppColors.warning : AppColors.success)
                .frame(width: 8, height: 8)

            Text(isShowingCachedData ? "Cached" : "Synced")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.backgroundTertiary)
        .clipShape(Capsule())
    }

    private var metricColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible(), spacing: AppSpacing.md)]
        }

        return [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible(), spacing: AppSpacing.md)]
    }

    private var heroMetricColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible(), spacing: AppSpacing.md)]
        }

        return [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible(), spacing: AppSpacing.md)]
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(1.6)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performanceBadge(progress: Double) -> some View {
        let color = progressColor(progress: progress)

        return Text(percent(progress))
            .font(AppTypography.caption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func labelPill(title: String, color: Color) -> some View {
        Text(title)
            .font(AppTypography.caption)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func compactMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashboardMetricCard(
        label: String,
        value: String,
        detail: String,
        icon: String,
        tint: Color
    ) -> some View {
        dashboardCard(
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .center, spacing: AppSpacing.sm) {
                        Text(label)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)

                        Spacer()

                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(tint)
                    }

                    Text(value)
                        .font(AppTypography.heading2)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .frame(minHeight: 124, alignment: .topLeading)
            },
            glassConfig: .thin,
            padding: AppSpacing.md
        )
    }

    private func dashboardCard<Content: View>(
        @ViewBuilder content: () -> Content,
        glassConfig: LiquidGlassConfig,
        padding: CGFloat
    ) -> some View {
        ModernCardView(
            content: content,
            backgroundColor: AppColors.backgroundSecondary,
            glassConfig: glassConfig,
            cornerRadius: AppSpacing.radiusMedium,
            padding: padding,
            showShadow: false,
            borderColor: AppColors.textPrimaryDark.opacity(0.12),
            borderWidth: 0.75
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 9)
    }

    private func statusBanner(message: String, isWarning: Bool) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: isWarning ? "wifi.slash" : "info.circle")
                .foregroundColor(isWarning ? AppColors.warning : AppColors.info)

            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)

            Spacer()
        }
        .padding(AppSpacing.md)
        .background((isWarning ? AppColors.warning : AppColors.info).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }

    private func signalColor(_ severity: ManagerDashboardSignalSeverity) -> Color {
        switch severity {
        case .positive:
            return AppColors.success
        case .attention:
            return AppColors.warning
        case .warning:
            return AppColors.error
        }
    }

    private func signalIcon(_ severity: ManagerDashboardSignalSeverity) -> String {
        switch severity {
        case .positive:
            return "arrow.up.right"
        case .attention:
            return "exclamationmark.circle"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    private func progressColor(progress: Double) -> Color {
        if progress >= 1 { return AppColors.success }
        if progress >= 0.85 { return AppColors.warning }
        return AppColors.error
    }

    private func monthLabel(from date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value >= 10_000 ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func loadDashboard(forceRefresh: Bool = false) async {
        guard let storeId = appState.currentStoreId, appState.currentUserRole == .boutiqueManager else {
            return
        }

        if !forceRefresh, snapshot == nil, let cached = service.cachedSnapshot(for: storeId) {
            snapshot = cached
            isShowingCachedData = true
            statusMessage = "Showing the last synced KPI snapshot while fresh data loads."
        }

        do {
            let fresh = try await service.refreshSnapshot(for: storeId)
            snapshot = fresh
            isShowingCachedData = false
            statusMessage = nil
        } catch {
            if snapshot != nil {
                isShowingCachedData = true
                statusMessage = "Live refresh failed. Displaying the last synced KPI snapshot."
            } else {
                statusMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    let appState = AppState()
    appState.currentUserName = "Avery Laurent"
    appState.currentUserEmail = "avery@example.com"
    appState.currentUserRole = .boutiqueManager
    appState.currentStoreId = UUID()

    return NavigationStack {
        ManagerDashboardView()
            .environment(appState)
    }
    .modelContainer(for: [StoreLocation.self], inMemory: true)
}
