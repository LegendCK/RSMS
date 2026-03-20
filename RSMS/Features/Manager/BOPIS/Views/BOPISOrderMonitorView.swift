//
//  BOPISOrderMonitorView.swift
//  RSMS
//
//  Boutique Manager — BOPIS & Ship-from-Store SLA Monitor.
//  Fulfils user story: "As a Boutique Manager, I want to monitor BOPIS and
//  ship-from-store orders so that pickups meet SLA timelines."
//
//  Acceptance criteria covered:
//    ✅ Manager can view a list of BOPIS orders
//    ✅ Each order displays a pickup deadline
//    ✅ System generates alerts for delayed pickups
//    ✅ Orders remain viewable offline using cached data
//

import SwiftUI

// MARK: - Main Monitor View

struct BOPISOrderMonitorView: View {
    @Environment(AppState.self) private var appState

    @State private var viewModel = BOPISOrderViewModel()

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Offline Banner
                if viewModel.isOffline {
                    offlineBanner
                }

                // Alert Summary Strip
                if viewModel.totalAlerts > 0 && !viewModel.isLoading {
                    alertStrip
                }

                // Channel Filter Chips
                channelFilterBar

                // Search
                searchBar

                // Order List
                if viewModel.isLoading {
                    loadingSkeleton
                } else if viewModel.filteredOrders.isEmpty {
                    emptyState
                } else {
                    orderList
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            await viewModel.onAppear(storeId: storeId)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .refreshable {
            await viewModel.pullToRefresh(storeId: storeId)
        }
    }

    // MARK: - Store ID

    private var storeId: UUID? {
        appState.currentStoreId
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text("OMNICHANNEL ORDERS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("BOPIS & SHIP-FROM-STORE")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: AppSpacing.xs) {
                if viewModel.totalAlerts > 0 {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.accent)
                        Circle()
                            .fill(AppColors.error)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Text("\(min(viewModel.totalAlerts, 99))")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 6, y: -6)
                    }
                }

                Button {
                    Task { await viewModel.pullToRefresh(storeId: storeId) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.accent)
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
            Text("Offline — showing cached data")
                .font(AppTypography.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.warning)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Alert Strip

    private var alertStrip: some View {
        HStack(spacing: AppSpacing.sm) {
            if viewModel.breachedCount > 0 {
                alertPill(
                    count: viewModel.breachedCount,
                    label: "Overdue",
                    color: AppColors.error,
                    icon: "exclamationmark.triangle.fill"
                )
            }
            if viewModel.atRiskCount > 0 {
                alertPill(
                    count: viewModel.atRiskCount,
                    label: "At Risk",
                    color: AppColors.warning,
                    icon: "clock.badge.exclamationmark.fill"
                )
            }
            Spacer()
            Text("\(viewModel.activeCount) active")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.backgroundSecondary)
    }

    private func alertPill(count: Int, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text("\(count) \(label)")
                .font(AppTypography.micro)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Channel Filter Bar

    private var channelFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(BOPISOrderViewModel.ChannelFilter.allCases) { filter in
                    filterChip(
                        label: filter.rawValue,
                        isSelected: viewModel.selectedChannel == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedChannel = filter
                        }
                    }
                }

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, AppSpacing.xxs)

                ForEach(BOPISOrderViewModel.SLAFilter.allCases) { filter in
                    filterChip(
                        label: filter.rawValue,
                        isSelected: viewModel.selectedSLA == filter,
                        isAlert: filter == .breached && viewModel.breachedCount > 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedSLA = filter
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.xs)
        }
        .background(AppColors.backgroundPrimary)
    }

    private func filterChip(
        label: String,
        isSelected: Bool,
        isAlert: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : (isAlert ? AppColors.error : AppColors.textSecondaryDark))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? (isAlert ? AppColors.error : AppColors.accent)
                        : (isAlert ? AppColors.error.opacity(0.1) : AppColors.backgroundSecondary)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : (isAlert ? AppColors.error.opacity(0.4) : AppColors.divider),
                            lineWidth: 0.75
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondaryDark)
            TextField("Search order or email…", text: $viewModel.searchText)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                .stroke(AppColors.divider, lineWidth: 0.75)
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - Order List

    private var orderList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.filteredOrders) { order in
                    BOPISOrderCard(order: order)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xxxl)
            .animation(.easeInOut(duration: 0.25), value: viewModel.filteredOrders.map(\.id))
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .padding(.top, AppSpacing.xs)
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                RoundedRectangle(cornerRadius: 4).fill(AppColors.backgroundTertiary).frame(width: 100, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4).fill(AppColors.backgroundTertiary).frame(width: 60, height: 14)
            }
            RoundedRectangle(cornerRadius: 4).fill(AppColors.backgroundTertiary).frame(height: 10).frame(maxWidth: 180)
            RoundedRectangle(cornerRadius: 4).fill(AppColors.backgroundTertiary).frame(height: 10).frame(maxWidth: 240)
        }
        .padding(AppSpacing.md)
        .managerCardSurface()
        .redacted(reason: .placeholder)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "shippingbox")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(AppColors.accent.opacity(0.5))
            Text("No Active Orders")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(viewModel.searchText.isEmpty
                ? "All BOPIS and ship-from-store orders are up to date."
                : "No orders match your search.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
        }
    }
}

// MARK: - Order Card

struct BOPISOrderCard: View {
    let order: BOPISOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row — order number + SLA badge
            HStack(alignment: .center, spacing: AppSpacing.xs) {
                // Channel icon
                ZStack {
                    Circle()
                        .fill(channelColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: order.channel.systemIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(channelColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(order.orderNumber)
                        .font(AppTypography.label)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(order.channel.displayName)
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .tracking(0.5)
                }

                Spacer()

                slaBadge
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)

            Divider()
                .background(AppColors.dividerLight)
                .padding(.horizontal, AppSpacing.md)

            // Detail rows
            VStack(spacing: AppSpacing.xs) {
                detailRow(icon: "person.fill", label: "Client", value: order.clientEmail)
                detailRow(icon: "clock.fill", label: "Deadline", value: order.formattedDeadline, valueColor: deadlineColor)
                detailRow(icon: "indianrupeesign.circle.fill", label: "Total", value: order.formattedTotal)
                detailRow(icon: "tag.fill", label: "Status", value: order.status.capitalized)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            // Time remaining footer
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: timeRemainingIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(slaColor)
                Text(order.timeRemainingLabel)
                    .font(AppTypography.micro)
                    .fontWeight(.semibold)
                    .foregroundColor(slaColor)
                Spacer()
                Text("SLA: \(Int(order.channel.slaHours))h")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(slaColor.opacity(0.07))
        }
        .managerCardSurface()
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                .stroke(slaColor.opacity(order.slaStatus == .onTime ? 0 : 0.5), lineWidth: 1)
        )
    }

    // MARK: - Sub-views

    private var slaBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(slaColor)
                .frame(width: 6, height: 6)
            Text(order.slaStatus.label)
                .font(AppTypography.micro)
                .fontWeight(.semibold)
                .foregroundColor(slaColor)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 4)
        .background(slaColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private func detailRow(icon: String, label: String, value: String, valueColor: Color = AppColors.textPrimaryDark) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 14)
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(AppTypography.caption)
                .foregroundColor(valueColor)
                .lineLimit(1)
            Spacer()
        }
    }

    // MARK: - Computed Colors

    private var slaColor: Color {
        switch order.slaStatus {
        case .breached: return AppColors.error
        case .atRisk:   return AppColors.warning
        case .onTime:   return AppColors.success
        }
    }

    private var channelColor: Color {
        switch order.channel {
        case .bopis:        return AppColors.accent
        case .shipFromStore: return AppColors.info
        }
    }

    private var deadlineColor: Color {
        switch order.slaStatus {
        case .breached: return AppColors.error
        case .atRisk:   return AppColors.warning
        case .onTime:   return AppColors.textPrimaryDark
        }
    }

    private var timeRemainingIcon: String {
        switch order.slaStatus {
        case .breached: return "exclamationmark.triangle.fill"
        case .atRisk:   return "clock.badge.exclamationmark"
        case .onTime:   return "checkmark.circle.fill"
        }
    }
}
