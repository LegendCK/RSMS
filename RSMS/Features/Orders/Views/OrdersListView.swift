//
//  OrdersListView.swift
//  infosys2
//
//  Customer order history with segmented filtering.
//

import SwiftUI
import SwiftData

struct OrdersListView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Order.createdAt, order: .reverse) private var allOrders: [Order]

    @State private var selectedFilter: OrderFilter = .all

    enum OrderFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case delivered = "Delivered"
    }

    private var customerOrders: [Order] {
        allOrders.filter { $0.customerEmail == appState.currentUserEmail }
    }

    private var filteredOrders: [Order] {
        switch selectedFilter {
        case .all:
            return customerOrders
        case .active:
            return customerOrders.filter {
                [.pending, .confirmed, .processing, .shipped, .readyForPickup].contains($0.status)
            }
        case .delivered:
            return customerOrders.filter {
                [.delivered, .completed].contains($0.status)
            }
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Segmented filter
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(OrderFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)

                if filteredOrders.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(filteredOrders) { order in
                                NavigationLink(destination: OrderDetailView(order: order)) {
                                    orderRow(order)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
        }
        .navigationTitle("My Orders")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.backgroundSecondary)
                    .frame(width: 100, height: 100)

                Image(systemName: "bag")
                    .font(AppTypography.emptyStateIcon)
                    .foregroundColor(AppColors.neutral600)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("No Orders Yet")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text("Your order history will appear here")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Order Row

    private func orderRow(_ order: Order) -> some View {
        LuxuryCardView {
            VStack(spacing: AppSpacing.sm) {
                // Top: Order number + status badge
                HStack {
                    Text(order.orderNumber)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)

                    Spacer()

                    statusBadge(order.status)
                }

                GoldDivider()

                // Middle: Items + date
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(orderItemsSummary(order))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .lineLimit(1)

                        Text(formattedDate(order.createdAt))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.neutral600)
                    }

                    Spacer()

                    Text(order.formattedTotal)
                        .font(AppTypography.priceSmall)
                        .foregroundColor(AppColors.accent)
                }

                // Fulfillment info
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: order.fulfillmentType == .bopis ? "building.2" : "shippingbox")
                        .font(AppTypography.sortIcon)
                        .foregroundColor(AppColors.neutral600)

                    Text(order.fulfillmentType.rawValue)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral600)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(AppTypography.chevron)
                        .foregroundColor(AppColors.neutral600)
                }
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: OrderStatus) -> some View {
        Text(status.rawValue)
            .font(AppTypography.caption)
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
            .cornerRadius(AppSpacing.radiusSmall)
    }

    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .pending: return AppColors.neutral600
        case .confirmed, .processing: return AppColors.accent
        case .shipped, .readyForPickup: return AppColors.purple
        case .delivered, .completed: return AppColors.success
        case .cancelled: return AppColors.error
        }
    }

    private func orderItemsSummary(_ order: Order) -> String {
        guard let data = order.orderItems.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return "Order items"
        }
        let names = items.compactMap { $0["name"] as? String }
        if names.count <= 2 {
            return names.joined(separator: ", ")
        } else {
            return "\(names[0]), \(names[1]) + \(names.count - 2) more"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
