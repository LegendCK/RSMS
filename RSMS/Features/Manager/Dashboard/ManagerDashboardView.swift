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
    @State private var showSalesAnalytics = false
    @State private var isShowingCachedData = false
    @State private var statusMessage: String?
    @State private var upcomingAppointments: [AppointmentDTO] = []
    @State private var appointmentClientsById: [UUID: ClientDTO] = [:]

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
        .sheet(isPresented: $showSalesAnalytics) {
            if let snapshot, let storeId = appState.currentStoreId {
                SalesAnalyticsSheet(
                    snapshot: snapshot,
                    storeId: storeId,
                    storeName: currentStoreName
                )
            }
        }
        .task(id: appState.currentStoreId) {
            await loadDashboard()
        }
    }

    private var dashboardContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xl) {
                dashboardHeader
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                if let statusMessage {
                    statusBanner(message: statusMessage, isWarning: isShowingCachedData)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                if let snapshot {
                    heroMetrics(snapshot)
                    supportingMetrics(snapshot)
                    operationalSignals(snapshot)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    staffPerformanceSection(snapshot)
                    appointmentSection(snapshot)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    upcomingAppointmentsSection
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                } else {
                    loadingState
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("KEY METRICS")
                .padding(.horizontal, AppSpacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // Sales vs Target card
                    Button(action: { showSalesAnalytics = true }) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Text("SALES VS TARGET")
                                    .font(AppTypography.overline)
                                    .tracking(1.6)
                                    .foregroundColor(AppColors.accent)
                                Spacer()
                                performanceBadge(progress: snapshot.sales.targetProgress)
                            }

                            Text(currency(snapshot.sales.actualRevenue))
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)

                            ProgressView(value: min(max(snapshot.sales.targetProgress, 0), 1.25))
                                .tint(progressColor(progress: snapshot.sales.targetProgress))

                            HStack {
                                Text("Target: \(currency(snapshot.sales.targetRevenue))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                Spacer()
                                Text(snapshot.sales.revenueGap > 0 ? "Gap: \(currency(snapshot.sales.revenueGap))" : "Ahead \(currency(abs(snapshot.sales.revenueGap)))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(progressColor(progress: snapshot.sales.targetProgress))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 9, weight: .medium))
                                Text("Tap for analytics")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(AppColors.accent.opacity(0.5))
                        }
                        .padding(AppSpacing.md)
                        .frame(width: 280)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                    }
                    .buttonStyle(.plain)

                    // Conversion rate card
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text("CONVERSION")
                                .font(AppTypography.overline)
                                .tracking(1.6)
                                .foregroundColor(AppColors.accent)
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(AppColors.secondary)
                                .font(.system(size: 14))
                        }

                        Text(percent(snapshot.sales.conversionRate))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimaryDark)

                        Text("Closed from appointments")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)

                        HStack(spacing: AppSpacing.lg) {
                            compactMetric(label: "Transactions", value: "\(snapshot.sales.transactions)")
                            compactMetric(label: "Clients", value: "\(snapshot.sales.uniqueClients)")
                        }
                    }
                    .padding(AppSpacing.md)
                    .frame(width: 260)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    private func supportingMetrics(_ snapshot: ManagerDashboardSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                supportingMetricPill(
                    label: "Transactions",
                    value: "\(snapshot.sales.transactions)",
                    icon: "creditcard.fill",
                    tint: AppColors.accent
                )

                supportingMetricPill(
                    label: "Avg Ticket",
                    value: currency(snapshot.sales.averageTicket),
                    icon: "dollarsign.circle",
                    tint: AppColors.secondary
                )

                supportingMetricPill(
                    label: "Today",
                    value: "\(snapshot.appointments.upcomingToday)",
                    icon: "calendar.badge.clock",
                    tint: AppColors.info
                )

                supportingMetricPill(
                    label: "Completion",
                    value: percent(snapshot.appointments.completionRate),
                    icon: "checkmark.circle.fill",
                    tint: snapshot.appointments.completionRate >= 0.7 ? AppColors.success : AppColors.warning
                )
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func supportingMetricPill(label: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                sectionTitle("STAFF PERFORMANCE")
                Spacer()
                Text("Ranked by revenue")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

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
                .padding(.horizontal, AppSpacing.screenHorizontal)
            } else {
                let topRevenue = max(snapshot.staffRanking.first?.revenue ?? 0, 1)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(Array(snapshot.staffRanking.prefix(5).enumerated()), id: \.element.id) { index, performer in
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                // Rank badge + name
                                HStack(spacing: AppSpacing.sm) {
                                    Text("#\(index + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(index == 0 ? AppColors.accent : AppColors.accent.opacity(0.6))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(performer.name)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                            .lineLimit(1)
                                        Text(performer.role)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                            .lineLimit(1)
                                    }
                                }

                                // Revenue
                                Text(currency(performer.revenue))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.textPrimaryDark)

                                // Progress bar
                                ProgressView(value: performer.revenue / topRevenue)
                                    .tint(index == 0 ? AppColors.accent : AppColors.secondary)

                                // Stats
                                HStack(spacing: AppSpacing.md) {
                                    Label("\(performer.transactions)", systemImage: "bag")
                                    Label(percent(performer.conversionRate), systemImage: "arrow.up.right")
                                }
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)

                                Text("\(performer.appointmentsHandled) appts")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            .padding(AppSpacing.md)
                            .frame(width: 200)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
        }
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

    private var upcomingAppointmentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("UPCOMING APPOINTMENTS")

            if upcomingAppointments.isEmpty {
                dashboardCard(
                    content: {
                        Text("No upcoming appointments scheduled for this boutique.")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    },
                    glassConfig: .regular,
                    padding: AppSpacing.md
                )
            } else {
                ForEach(upcomingAppointments.prefix(8)) { appointment in
                    dashboardCard(
                        content: {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack(spacing: AppSpacing.sm) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let client = appointmentClientsById[appointment.clientId] {
                                            Text(client.fullName)
                                                .font(AppTypography.label)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Text(client.email)
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.textSecondaryDark)
                                        } else {
                                            Text("Customer #\(appointment.clientId.uuidString.prefix(8))")
                                                .font(AppTypography.label)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                        }
                                    }
                                    Spacer()
                                    Text(appointment.status.replacingOccurrences(of: "_", with: " ").uppercased())
                                        .font(AppTypography.nano)
                                        .foregroundColor(AppColors.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppColors.accent.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                Text(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textSecondaryDark)

                                if let notes = appointment.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                        .lineLimit(2)
                                }
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
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = value >= 10_000 ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(value)"
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
            await loadUpcomingAppointments(for: storeId)
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

    private func loadUpcomingAppointments(for storeId: UUID) async {
        do {
            let all = try await AppointmentService.shared.fetchAppointments(forStoreId: storeId)
            let now = Date()
            let statuses = Set(["requested", "scheduled", "confirmed", "in_progress"])
            let filtered = all
                .filter { $0.scheduledAt >= now && statuses.contains($0.status) }
                .sorted { $0.scheduledAt < $1.scheduledAt }

            upcomingAppointments = filtered

            let clientIds = filtered.map(\.clientId)
            if clientIds.isEmpty {
                appointmentClientsById = [:]
            } else {
                let clients = try await ClientService.shared.fetchClients(ids: clientIds)
                appointmentClientsById = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
            }
        } catch {
            upcomingAppointments = []
            appointmentClientsById = [:]
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
