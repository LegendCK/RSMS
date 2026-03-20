//
//  EventSalesReportView.swift
//  RSMS
//
//  Full event ROI report for Boutique Managers.
//  Shows KPI cards, multi-currency revenue breakdown, and a per-order list.
//

import SwiftUI

struct EventSalesReportView: View {
    let event: EventDTO

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var summaries: [EventSalesSummaryDTO] = []
    @State private var orders:    [OrderDTO]             = []
    @State private var isLoading  = true
    @State private var errorMsg   = ""
    @State private var showError  = false

    // Aggregate across all currencies for display
    private var totalOrders: Int { summaries.reduce(0) { $0 + $1.orderCount } }

    // Group orders by currency for the table
    private var currencyRows: [EventSalesSummaryDTO] { summaries }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading report…")
                        .foregroundColor(AppColors.textSecondaryDark)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.md) {

                            // ── Event Header ──────────────────────────────
                            eventHeader

                            if summaries.isEmpty {
                                emptyState
                            } else {
                                // ── KPI Cards ─────────────────────────────
                                kpiSection

                                // ── Multi-Currency Breakdown ───────────────
                                if currencyRows.count > 1 {
                                    currencyBreakdown
                                }

                                // ── ROI ───────────────────────────────────
                                if let roi = summaries.first?.roiPercent {
                                    roiCard(roi)
                                }

                                // ── Orders List ───────────────────────────
                                ordersSection
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                    .refreshable { await loadData() }
                }
            }
            .navigationTitle("Event Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMsg)
            }
            .task { await loadData() }
        }
    }

    // MARK: - Event Header

    private var eventHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.eventName)
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(event.eventType)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                }
                Spacer()
                statusPill(event.status)
            }

            HStack(spacing: AppSpacing.md) {
                Label(event.scheduledDate.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
                if !event.relatedCategory.isEmpty {
                    Label(event.relatedCategory, systemImage: "tag")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            if let cost = event.estimatedCost {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(AppColors.neutral500)
                        .font(.system(size: 11))
                    Text("Est. cost: \(formatAmount(cost, currency: event.currency))")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.neutral500)
                }
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    // MARK: - KPI Section

    private var kpiSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sLabel("KEY METRICS")

            // Top row: Revenue per currency
            ForEach(summaries) { row in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Revenue")
                            .font(AppTypography.overline)
                            .tracking(1)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text(row.formattedRevenue)
                            .font(AppTypography.heading2)
                            .foregroundColor(AppColors.accent)
                    }
                    Spacer()
                    currencyBadge(row.currency)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.accent.opacity(0.06))
                .cornerRadius(AppSpacing.radiusSmall)
            }

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                kpiCard(label: "Orders", value: "\(totalOrders)", icon: "bag.fill", color: AppColors.secondary)
                kpiCard(label: "Attendees", value: "\(event.capacity)", icon: "person.2.fill", color: AppColors.info)
                if let first = summaries.first {
                    kpiCard(label: "Avg Order", value: first.formattedAvg, icon: "chart.bar.fill", color: AppColors.success)
                    let convRate = event.capacity > 0
                        ? Double(totalOrders) / Double(event.capacity) * 100 : 0
                    kpiCard(label: "Conversion", value: String(format: "%.1f%%", convRate),
                            icon: "arrow.up.right", color: AppColors.warning)
                }
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    // MARK: - Multi-Currency Breakdown

    private var currencyBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sLabel("REVENUE BY CURRENCY")

            // Header
            HStack {
                Text("Currency").font(AppTypography.nano).foregroundColor(AppColors.neutral500)
                Spacer()
                Text("Orders").font(AppTypography.nano).foregroundColor(AppColors.neutral500)
                    .frame(width: 54, alignment: .trailing)
                Text("Revenue").font(AppTypography.nano).foregroundColor(AppColors.neutral500)
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.horizontal, AppSpacing.xs)

            Divider().background(AppColors.border)

            ForEach(currencyRows) { row in
                HStack {
                    HStack(spacing: 6) {
                        currencyBadge(row.currency)
                        Text(row.currency)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    Spacer()
                    Text("\(row.orderCount)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .frame(width: 54, alignment: .trailing)
                    Text(row.formattedRevenue)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.accent)
                        .frame(width: 90, alignment: .trailing)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, AppSpacing.xs)

                if row.id != currencyRows.last?.id {
                    Divider().background(AppColors.border)
                }
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    // MARK: - ROI Card

    private func roiCard(_ roi: Double) -> some View {
        let isPositive = roi >= 0
        let color = isPositive ? AppColors.success : AppColors.error
        let icon  = isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"

        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Return on Investment")
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(AppColors.textSecondaryDark)
                Text(String(format: "%+.1f%%", roi))
                    .font(AppTypography.heading2)
                    .foregroundColor(color)
                if let cost = event.estimatedCost {
                    Text("Based on \(formatAmount(cost, currency: event.currency)) event cost")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.neutral500)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(color.opacity(0.08))
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Orders Section

    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sLabel("TAGGED ORDERS (\(orders.count))")

            if orders.isEmpty {
                Text("No orders have been tagged to this event yet.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .padding(.vertical, AppSpacing.sm)
            } else {
                ForEach(orders) { order in
                    orderRow(order)
                }
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    private func orderRow(_ order: OrderDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(order.orderNumber ?? "Order")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.neutral500)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(order.formattedTotal)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.accent)
                Text(order.channel.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(AppColors.neutral500)
            Text("No Sales Recorded")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Tag in-store transactions to this event during the sale to see ROI data here.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let s = EventSalesService.shared.fetchEventSummary(eventId: event.id)
            async let o = EventSalesService.shared.fetchEventOrders(eventId: event.id)
            (summaries, orders) = try await (s, o)
        } catch {
            errorMsg = error.localizedDescription
            showError = true
        }
    }

    private func sLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
    }

    private func statusPill(_ status: String) -> some View {
        let color: Color = {
            switch status {
            case "Completed":   return AppColors.success
            case "Cancelled":   return AppColors.error
            case "In Progress": return AppColors.info
            case "Confirmed":   return AppColors.secondary
            default:            return AppColors.neutral500
            }
        }()
        return Text(status.uppercased())
            .font(AppTypography.nano)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func currencyBadge(_ code: String) -> some View {
        Text(code)
            .font(AppTypography.nano)
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.accent.opacity(0.1))
            .cornerRadius(4)
    }

    private func kpiCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Text(value)
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(color.opacity(0.07))
        .cornerRadius(AppSpacing.radiusSmall)
    }

    private func formatAmount(_ amount: Double, currency: String) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currency
        return fmt.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}
