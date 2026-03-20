//
//  SalesAnalyticsSheet.swift
//  RSMS
//
//  Detailed sales analytics sheet for Boutique Managers.
//  Shows revenue ring, daily/cumulative charts, channel breakdown,
//  top revenue days, and staff leaderboard.
//

import SwiftUI
import Charts
import Supabase

// MARK: - SalesAnalyticsSheet

struct SalesAnalyticsSheet: View {
    let snapshot: ManagerDashboardSnapshot
    let storeId: UUID
    let storeName: String

    @Environment(\.dismiss) private var dismiss
    @State private var orders: [OrderDTO] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var selectedRange: AnalyticsRange = .thisMonth

    // MARK: - Analytics Range

    enum AnalyticsRange: String, CaseIterable {
        case thisMonth = "This Month"
        case last30    = "Last 30 Days"
        case last7     = "Last 7 Days"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = loadError {
                    errorView(message: error)
                } else {
                    analyticsContent
                }
            }
            .navigationTitle("Sales Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(storeName)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text(periodSubtitle)
                            .font(AppTypography.nano)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
            }
            .task {
                await loadOrders()
            }
            .onChange(of: selectedRange) { _, _ in
                Task { await loadOrders() }
            }
        }
    }

    // MARK: - Analytics Content

    private var analyticsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                periodSelector
                revenueRingSection
                dailyRevenueChartSection
                cumulativeProgressSection
                channelBreakdownSection
                topDaysSection
                staffLeaderboardSection
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.accent)
                .scaleEffect(1.2)
            Text("Loading analytics…")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppColors.warning)

            Text("Unable to Load Analytics")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)

            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button {
                Task { await loadOrders() }
            } label: {
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

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(AnalyticsRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(AppTypography.caption)
                        .foregroundColor(selectedRange == range ? .white : AppColors.textPrimaryDark)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            Group {
                                if selectedRange == range {
                                    AppColors.accent
                                } else {
                                    Color(.secondarySystemGroupedBackground)
                                }
                            }
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Revenue Ring Section

    private var revenueRingSection: some View {
        let actual = actualRevenue
        let target = targetRevenueForRange
        let progress = target > 0 ? min(actual / target, 1.0) : 0

        return analyticsCard {
            VStack(spacing: AppSpacing.lg) {
                sectionHeader("REVENUE VS TARGET")

                // Ring gauge
                ZStack {
                    // Background track
                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(AppColors.accent.opacity(0.12), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.accent, AppColors.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

                    // Center text
                    VStack(spacing: 4) {
                        Text(currency(actual))
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .foregroundColor(AppColors.textPrimaryDark)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("of \(currency(target))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(.horizontal, 30)
                }

                // Stat pills row
                HStack(spacing: AppSpacing.sm) {
                    statPill(
                        label: "Achieved",
                        value: "\(Int((progress * 100).rounded()))%",
                        color: progressColor(progress)
                    )
                    statPill(
                        label: "Transactions",
                        value: "\(filteredTransactions)",
                        color: AppColors.info
                    )
                    statPill(
                        label: "Avg Ticket",
                        value: currency(filteredAverageTicket),
                        color: AppColors.secondary
                    )
                }
            }
        }
    }

    // MARK: - Daily Revenue Chart Section

    private var dailyRevenueChartSection: some View {
        let data = dailyRevenueData
        let target = dailyTarget

        return analyticsCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionHeader("DAILY REVENUE")

                if data.isEmpty {
                    emptyChartPlaceholder("No revenue data for this period")
                } else {
                    Chart {
                        ForEach(data, id: \.day) { item in
                            BarMark(
                                x: .value("Day", item.label),
                                y: .value("Revenue", item.revenue)
                            )
                            .foregroundStyle(AppColors.accent)
                            .cornerRadius(4)
                        }

                        if target > 0 {
                            RuleMark(y: .value("Target", target))
                                .foregroundStyle(AppColors.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Target")
                                        .font(AppTypography.nano)
                                        .foregroundColor(AppColors.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(4)
                                }
                        }
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: min(data.count, 6))) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(AppColors.dividerLight)
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(AppTypography.nano)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(AppColors.dividerLight)
                            AxisValueLabel {
                                if let doubleVal = value.as(Double.self) {
                                    Text(abbreviatedCurrency(doubleVal))
                                        .font(AppTypography.nano)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.background(Color.clear)
                    }
                }
            }
        }
    }

    // MARK: - Cumulative Progress Section

    private var cumulativeProgressSection: some View {
        let data = cumulativeData

        return analyticsCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionHeader("CUMULATIVE PROGRESS")

                if data.isEmpty {
                    emptyChartPlaceholder("No data available for this period")
                } else {
                    Chart {
                        ForEach(data, id: \.day) { item in
                            AreaMark(
                                x: .value("Day", item.day),
                                y: .value("Revenue", item.cumulative)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.25), AppColors.accent.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.monotone)

                            LineMark(
                                x: .value("Day", item.day),
                                y: .value("Revenue", item.cumulative)
                            )
                            .foregroundStyle(AppColors.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                        }

                        ForEach(data, id: \.day) { item in
                            LineMark(
                                x: .value("Day", item.day),
                                y: .value("Ideal", item.idealTarget)
                            )
                            .foregroundStyle(AppColors.secondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(AppColors.dividerLight)
                            AxisValueLabel {
                                if let intVal = value.as(Int.self) {
                                    Text("Day \(intVal)")
                                        .font(AppTypography.nano)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(AppColors.dividerLight)
                            AxisValueLabel {
                                if let doubleVal = value.as(Double.self) {
                                    Text(abbreviatedCurrency(doubleVal))
                                        .font(AppTypography.nano)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.background(Color.clear)
                    }

                    // Legend
                    HStack(spacing: AppSpacing.md) {
                        legendDot(color: AppColors.accent, label: "Actual")
                        legendDot(color: AppColors.secondary.opacity(0.6), label: "Target pace", dashed: true)
                    }
                }
            }
        }
    }

    // MARK: - Channel Breakdown Section

    private var channelBreakdownSection: some View {
        let channels = channelData
        let totalRev = channels.reduce(0) { $0 + $1.revenue }

        return analyticsCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionHeader("REVENUE BY CHANNEL")

                if channels.allSatisfy({ $0.revenue == 0 }) {
                    emptyChartPlaceholder("No channel data for this period")
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(channels.filter { $0.revenue > 0 }, id: \.channel) { item in
                            channelRow(item: item, total: totalRev)
                        }
                    }
                }
            }
        }
    }

    private func channelRow(item: (channel: String, label: String, revenue: Double, color: Color), total: Double) -> some View {
        let fraction = total > 0 ? item.revenue / total : 0

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack {
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    Text(item.label)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currency(item.revenue))
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(AppTypography.nano)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(item.color.opacity(0.12))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(item.color)
                        .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Top Days Section

    private var topDaysSection: some View {
        let days = topDays

        return analyticsCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionHeader("TOP 5 REVENUE DAYS")

                if days.isEmpty {
                    emptyChartPlaceholder("No completed orders in this period")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                            topDayRow(rank: index + 1, date: day.date, revenue: day.revenue, txCount: day.txCount)

                            if index < days.count - 1 {
                                Divider()
                                    .background(AppColors.dividerLight)
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private func topDayRow(rank: Int, date: Date, revenue: Double, txCount: Int) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? AppColors.warning.opacity(0.15) : AppColors.backgroundTertiary)
                    .frame(width: 32, height: 32)

                if rank == 1 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.warning)
                } else {
                    Text("\(rank)")
                        .font(AppTypography.overline)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("\(txCount) transaction\(txCount == 1 ? "" : "s")")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()

            Text(currency(revenue))
                .font(AppTypography.label)
                .foregroundColor(rank == 1 ? AppColors.accent : AppColors.textPrimaryDark)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Staff Leaderboard Section

    private var staffLeaderboardSection: some View {
        let staff = Array(snapshot.staffRanking.prefix(5))
        let maxRevenue = max(staff.first?.revenue ?? 0, 1)
        let chartHeight = max(120, staff.count * 36)

        return analyticsCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionHeader("STAFF REVENUE CONTRIBUTION")

                if staff.isEmpty {
                    emptyChartPlaceholder("No staff performance data available")
                } else {
                    Chart {
                        ForEach(staff) { member in
                            BarMark(
                                x: .value("Revenue", member.revenue),
                                y: .value("Name", shortName(member.name))
                            )
                            .foregroundStyle(AppColors.secondary)
                            .cornerRadius(4)
                            .annotation(position: .trailing) {
                                Text(abbreviatedCurrency(member.revenue))
                                    .font(AppTypography.nano)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }
                    }
                    .frame(height: CGFloat(chartHeight))
                    .chartXAxis {
                        AxisMarks(position: .bottom) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(AppColors.dividerLight)
                            AxisValueLabel {
                                if let doubleVal = value.as(Double.self) {
                                    Text(abbreviatedCurrency(doubleVal))
                                        .font(AppTypography.nano)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let name = value.as(String.self) {
                                    Text(name)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                }
                            }
                        }
                    }
                    .chartXScale(domain: 0...(maxRevenue * 1.2))
                    .chartPlotStyle { plot in
                        plot.background(Color.clear)
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func analyticsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(AppSpacing.md)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(3)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(AppTypography.nano)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }

    private func emptyChartPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(AppColors.textSecondaryDark.opacity(0.5))
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, AppSpacing.xl)
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            if dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(color)
                            .frame(width: 5, height: 2)
                    }
                }
            } else {
                Capsule()
                    .fill(color)
                    .frame(width: 16, height: 2)
            }
            Text(label)
                .font(AppTypography.nano)
                .foregroundColor(AppColors.textSecondaryDark)
        }
    }

    // MARK: - Computed Properties

    var periodStart: Date {
        let cal = Calendar.current
        let now = Date()
        switch selectedRange {
        case .thisMonth:
            return cal.dateInterval(of: .month, for: now)?.start ?? now
        case .last30:
            return cal.date(byAdding: .day, value: -30, to: now) ?? now
        case .last7:
            return cal.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }

    var daysInPeriod: Int {
        switch selectedRange {
        case .thisMonth:
            let cal = Calendar.current
            let now = Date()
            if let interval = cal.dateInterval(of: .month, for: now) {
                return cal.dateComponents([.day], from: interval.start, to: interval.end).day ?? 30
            }
            return 30
        case .last30: return 30
        case .last7:  return 7
        }
    }

    var dailyTarget: Double {
        let target = targetRevenueForRange
        let days = max(daysInPeriod, 1)
        return target / Double(days)
    }

    var targetRevenueForRange: Double {
        switch selectedRange {
        case .thisMonth:
            return snapshot.sales.targetRevenue
        default:
            // Prorate monthly target
            let monthDays: Double = 30
            let daily = snapshot.sales.targetRevenue / monthDays
            return daily * Double(daysInPeriod)
        }
    }

    private var actualRevenue: Double {
        filteredOrders.reduce(0) { $0 + $1.grandTotal }
    }

    private var filteredOrders: [OrderDTO] {
        orders.filter { $0.createdAt >= periodStart }
    }

    private var filteredTransactions: Int {
        filteredOrders.count
    }

    private var filteredAverageTicket: Double {
        let count = filteredTransactions
        guard count > 0 else { return 0 }
        return actualRevenue / Double(count)
    }

    var dailyRevenueData: [(day: Int, label: String, revenue: Double, txCount: Int)] {
        let cal = Calendar.current
        let start = periodStart

        var grouped: [Int: (revenue: Double, txCount: Int)] = [:]

        for order in filteredOrders {
            let dayOffset = cal.dateComponents([.day], from: start, to: order.createdAt).day ?? 0
            let dayNum = dayOffset + 1
            guard dayNum >= 1 else { continue }
            let existing = grouped[dayNum] ?? (0, 0)
            grouped[dayNum] = (existing.revenue + order.grandTotal, existing.txCount + 1)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"

        return grouped.keys.sorted().map { dayNum in
            let date = cal.date(byAdding: .day, value: dayNum - 1, to: start) ?? start
            let label = formatter.string(from: date)
            let vals = grouped[dayNum] ?? (0, 0)
            return (day: dayNum, label: label, revenue: vals.revenue, txCount: vals.txCount)
        }
    }

    var cumulativeData: [(day: Int, cumulative: Double, idealTarget: Double)] {
        let daily = dailyRevenueData
        guard !daily.isEmpty else { return [] }

        let target = targetRevenueForRange
        let days = daysInPeriod

        var running: Double = 0
        return daily.map { item in
            running += item.revenue
            let ideal = target * (Double(item.day) / Double(days))
            return (day: item.day, cumulative: running, idealTarget: ideal)
        }
    }

    var channelData: [(channel: String, label: String, revenue: Double, color: Color)] {
        let channelDefs: [(channel: String, label: String, color: Color)] = [
            ("in_store",        "In Store",        AppColors.accent),
            ("online",          "Online",          AppColors.secondary),
            ("bopis",           "BOPIS",           AppColors.info),
            ("ship_from_store", "Ship from Store", AppColors.success)
        ]

        var totals: [String: Double] = [:]
        for order in filteredOrders {
            totals[order.channel, default: 0] += order.grandTotal
        }

        return channelDefs.map { def in
            (channel: def.channel, label: def.label, revenue: totals[def.channel] ?? 0, color: def.color)
        }
    }

    var topDays: [(date: Date, revenue: Double, txCount: Int)] {
        let cal = Calendar.current
        var dayMap: [DateComponents: (revenue: Double, txCount: Int)] = [:]

        for order in filteredOrders {
            let comps = cal.dateComponents([.year, .month, .day], from: order.createdAt)
            let existing = dayMap[comps] ?? (0, 0)
            dayMap[comps] = (existing.revenue + order.grandTotal, existing.txCount + 1)
        }

        return dayMap
            .sorted { $0.value.revenue > $1.value.revenue }
            .prefix(5)
            .compactMap { (comps, vals) -> (date: Date, revenue: Double, txCount: Int)? in
                guard let date = cal.date(from: comps) else { return nil }
                return (date: date, revenue: vals.revenue, txCount: vals.txCount)
            }
    }

    // MARK: - Formatting Helpers

    func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = value >= 1000 ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }

    private func abbreviatedCurrency(_ value: Double) -> String {
        if value >= 1_00_00_000 {
            return "₹\(String(format: "%.1f", value / 1_00_00_000))Cr"
        } else if value >= 1_00_000 {
            return "₹\(String(format: "%.1f", value / 1_00_000))L"
        } else if value >= 1_000 {
            return "₹\(String(format: "%.1f", value / 1_000))K"
        } else {
            return "₹\(Int(value))"
        }
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return AppColors.success }
        if progress >= 0.75 { return AppColors.warning }
        return AppColors.error
    }

    private var periodSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: periodStart)) – Today"
    }

    private func shortName(_ fullName: String) -> String {
        let parts = fullName.split(separator: " ")
        guard parts.count >= 2 else { return fullName }
        return "\(parts[0]) \(parts[1].prefix(1))."
    }

    // MARK: - Load Orders

    func loadOrders() async {
        isLoading = true
        loadError = nil

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateStr = formatter.string(from: periodStart)

        var lastError: Error?

        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            do {
                let fetched: [OrderDTO] = try await SupabaseManager.shared.client
                    .from("orders")
                    .select()
                    .eq("store_id", value: storeId.uuidString.lowercased())
                    .neq("status", value: "cancelled")
                    .gte("created_at", value: dateStr)
                    .order("created_at", ascending: true)
                    .execute()
                    .value

                orders = fetched
                isLoading = false
                return
            } catch {
                lastError = error

                // Retry with date-only format if fractional seconds cause an issue
                if attempt == 0 {
                    let fallbackFormatter = ISO8601DateFormatter()
                    fallbackFormatter.formatOptions = [.withFullDate]
                    let fallbackStr = fallbackFormatter.string(from: periodStart)

                    do {
                        let fetched: [OrderDTO] = try await SupabaseManager.shared.client
                            .from("orders")
                            .select()
                            .eq("store_id", value: storeId.uuidString.lowercased())
                            .neq("status", value: "cancelled")
                            .gte("created_at", value: fallbackStr)
                            .order("created_at", ascending: true)
                            .execute()
                            .value

                        orders = fetched
                        isLoading = false
                        return
                    } catch {
                        lastError = error
                    }
                }
            }
        }

        isLoading = false
        loadError = lastError?.localizedDescription ?? "Failed to load orders. Please try again."
    }
}

// MARK: - Preview

#Preview {
    let sales = ManagerDashboardSalesMetrics(
        actualRevenue: 2_45_000,
        targetRevenue: 3_00_000,
        transactions: 38,
        averageTicket: 6447,
        conversionRate: 0.72,
        uniqueClients: 29
    )

    let staff: [ManagerDashboardStaffPerformance] = [
        ManagerDashboardStaffPerformance(id: UUID(), name: "Priya Sharma", role: "sales_associate", revenue: 95000, transactions: 14, appointmentsHandled: 18, conversionRate: 0.78),
        ManagerDashboardStaffPerformance(id: UUID(), name: "Rohan Mehta", role: "sales_associate", revenue: 82000, transactions: 12, appointmentsHandled: 15, conversionRate: 0.8),
        ManagerDashboardStaffPerformance(id: UUID(), name: "Ananya Singh", role: "service_technician", revenue: 68000, transactions: 10, appointmentsHandled: 13, conversionRate: 0.77),
    ]

    let snapshot = ManagerDashboardSnapshot(
        storeId: UUID(),
        syncedAt: Date(),
        periodStart: Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date(),
        sales: sales,
        appointments: ManagerDashboardAppointmentMetrics(
            totalBooked: 52, confirmed: 18, completed: 37,
            cancelled: 5, noShow: 3, upcomingToday: 4, upcomingThisWeek: 11,
            completionRate: 0.71
        ),
        staffRanking: staff,
        operationalSignals: []
    )

    SalesAnalyticsSheet(
        snapshot: snapshot,
        storeId: UUID(),
        storeName: "Maison Luxe — Khan Market"
    )
}
