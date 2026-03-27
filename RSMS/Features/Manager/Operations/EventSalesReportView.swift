import SwiftUI

struct EventSalesReportView: View {
    let event: EventDTO

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var summaries: [EventSalesSummaryDTO] = []
    @State private var taggedOrders: [OrderDTO] = []

    private var totalRevenue: Double {
        if !summaries.isEmpty {
            return summaries.reduce(0) { $0 + $1.totalRevenue }
        }
        return taggedOrders.reduce(0) { $0 + $1.grandTotal }
    }

    private var orderCount: Int {
        if !summaries.isEmpty {
            return summaries.reduce(0) { $0 + $1.orderCount }
        }
        return taggedOrders.count
    }

    private var avgOrderValue: Double {
        if !summaries.isEmpty {
            let weightedRevenue = summaries.reduce(0) { $0 + $1.totalRevenue }
            let weightedOrders = summaries.reduce(0) { $0 + $1.orderCount }
            return weightedOrders > 0 ? weightedRevenue / Double(weightedOrders) : 0
        }
        let count = taggedOrders.count
        return count > 0 ? totalRevenue / Double(count) : 0
    }

    private var latestCurrencyCode: String {
        summaries.first?.currency ?? taggedOrders.first?.currency ?? "INR"
    }

    private var channelRows: [(label: String, revenue: Double)] {
        var grouped: [String: Double] = [:]
        for order in taggedOrders {
            grouped[channelLabel(order.channel), default: 0] += order.grandTotal
        }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading report…")
                        .tint(AppColors.accent)
                } else if let loadError {
                    errorState(loadError)
                } else {
                    reportContent
                }
            }
            .navigationTitle("Sales Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadReport() }
        }
    }

    private var reportContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                eventHeaderCard
                kpiCard
                channelBreakdownCard
                topOrdersCard
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private var eventHeaderCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(event.eventName)
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("\(event.eventType) · \(event.status)")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Text(event.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    private var kpiCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("EVENT PERFORMANCE")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            HStack(spacing: AppSpacing.sm) {
                metric(label: "Revenue", value: currency(totalRevenue, code: latestCurrencyCode), color: AppColors.accent)
                metric(label: "Orders", value: "\(orderCount)", color: AppColors.secondary)
                metric(label: "Avg", value: currency(avgOrderValue, code: latestCurrencyCode), color: AppColors.success)
            }

            if let estimated = event.estimatedCost, estimated > 0 {
                let roi = ((totalRevenue - estimated) / estimated) * 100
                Text("ROI: \(Int(roi.rounded()))% (Estimated Cost: \(currency(estimated, code: event.currency)))")
                    .font(AppTypography.caption)
                    .foregroundColor(roi >= 0 ? AppColors.success : AppColors.warning)
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    private var channelBreakdownCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("REVENUE BY CHANNEL")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            if channelRows.isEmpty {
                Text("No tagged orders yet.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                ForEach(Array(channelRows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.label)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Spacer()
                        Text(currency(row.revenue, code: latestCurrencyCode))
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    private var topOrdersCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("TAGGED ORDERS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            if taggedOrders.isEmpty {
                Text("No orders are currently tagged to this event.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                ForEach(Array(taggedOrders.prefix(8).enumerated()), id: \.element.id) { index, order in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.orderNumber ?? "#\(order.id.uuidString.prefix(8))")
                                .font(AppTypography.monoID)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        Spacer()
                        Text(order.formattedTotal)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.accent)
                    }
                    if index < min(taggedOrders.count, 8) - 1 {
                        Divider().background(AppColors.border)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    private func metric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.label)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(AppColors.warning)
            Text("Failed to load event report")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(message)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            Button("Retry") {
                Task { await loadReport() }
            }
            .font(AppTypography.actionSmall)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppColors.accent)
            .clipShape(Capsule())
        }
    }

    private func loadReport() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            taggedOrders = try await EventSalesService.shared.fetchEventOrders(eventId: event.id)
        } catch {
            loadError = "Could not fetch tagged orders: \(error.localizedDescription)"
            return
        }

        do {
            summaries = try await EventSalesService.shared.fetchEventSummary(eventId: event.id)
        } catch {
            // Keep screen usable when summary view/RLS is unavailable.
            summaries = []
            print("[EventSalesReportView] Summary fetch failed, using tagged orders fallback: \(error)")
        }
    }

    private func channelLabel(_ raw: String) -> String {
        switch raw {
        case "bopis": return "BOPIS"
        case "ship_from_store": return "Ship from Store"
        case "in_store": return "In-Store"
        case "online": return "Online"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func currency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(Int(value))"
    }
}
