//
//  AllocationTransfersView.swift
//  RSMS
//
//  Allocation tracking screen showing Pending / In Transit / Completed transfers.
//  "Mark as Received" completes the allocation via RPC and refreshes inventory.
//

import SwiftUI

struct AllocationTransfersView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AllocationTransferViewModel()
    @State private var selectedStatus: AllocationStatus? = nil

    private let statusTabs: [(label: String, value: AllocationStatus?)] = [
        ("All", nil),
        ("Pending", .pending),
        ("In Transit", .inTransit),
        ("Completed", .completed),
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Status filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(statusTabs, id: \.label) { tab in
                            filterChip(tab.label, isSelected: selectedStatus == tab.value) {
                                selectedStatus = tab.value
                                viewModel.selectedFilter = tab.value
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
                .padding(.vertical, AppSpacing.xs)

                if viewModel.isLoading && viewModel.allocations.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    allocationList
                }
            }
        }
        .task { await viewModel.loadData() }
        .refreshable { await viewModel.loadData() }
    }

    // MARK: - List

    private var allocationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppSpacing.sm) {
                let rows = viewModel.filteredAllocations
                if rows.isEmpty {
                    emptyState
                        .padding(.top, AppSpacing.xxl)
                } else {
                    // Error banners
                    if let err = viewModel.completionError {
                        errorBanner(err)
                    }
                    if let err = viewModel.dispatchError {
                        errorBanner(err)
                    }

                    ForEach(rows) { allocation in
                        allocationCard(allocation)
                    }
                }
            }
            .padding(.vertical, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    // MARK: - Card

    private func allocationCard(_ alloc: AllocationDTO) -> some View {
        let status = alloc.allocationStatus
        let isDispatching = viewModel.dispatchingId == alloc.id
        let isCompleting  = viewModel.completingId  == alloc.id
        let anyBusy = viewModel.dispatchingId != nil || viewModel.completingId != nil

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header row
            HStack {
                // Product name
                VStack(alignment: .leading, spacing: 2) {
                    Text(alloc.products?.name ?? "Unknown Product")
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    Text(alloc.products?.sku ?? "—")
                        .font(AppTypography.monoID)
                        .foregroundStyle(AppColors.neutral500)
                }
                Spacer()
                statusBadge(status)
            }

            Divider().background(AppColors.border)

            // From → To + Qty
            HStack(spacing: AppSpacing.md) {
                routeColumn("FROM", id: alloc.fromLocationId)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                routeColumn("TO", id: alloc.toLocationId)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(alloc.quantity)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimaryDark)
                    Text("units")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textSecondaryDark)
                }
            }

            // Date
            Text(alloc.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral500)

            // Status-driven action buttons
            switch status {
            case .pending:
                actionButton(
                    title: "Dispatch",
                    icon: "shippingbox.fill",
                    color: AppColors.accent,
                    isLoading: isDispatching,
                    isDisabled: anyBusy
                ) {
                    Task {
                        await viewModel.dispatchAllocation(
                            alloc,
                            performedBy: appState.currentUserProfile?.id
                        )
                    }
                }

            case .inTransit:
                actionButton(
                    title: "Mark as Received",
                    icon: "checkmark.circle.fill",
                    color: AppColors.success,
                    isLoading: isCompleting,
                    isDisabled: anyBusy
                ) {
                    Task {
                        await viewModel.completeAllocation(
                            alloc,
                            performedBy: appState.currentUserProfile?.id
                        )
                    }
                }

            default:
                EmptyView()
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func routeColumn(_ label: String, id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTypography.micro)
                .tracking(1)
                .foregroundStyle(AppColors.textSecondaryDark)
            Text(viewModel.locationName(for: id))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textPrimaryDark)
                .lineLimit(2)
        }
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: AllocationStatus) -> some View {
        let color: Color = {
            switch status {
            case .pending:   return AppColors.warning
            case .inTransit: return AppColors.info
            case .completed: return AppColors.success
            case .cancelled: return AppColors.error
            }
        }()

        return Text(status.displayName.uppercased())
            .font(AppTypography.nano)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    // MARK: - Filter Chip

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : AppColors.textPrimaryDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? AppColors.accent : Color(uiColor: .secondarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty / Loading / Error

    private var loadingView: some View {
        VStack(spacing: AppSpacing.sm) {
            ProgressView().tint(AppColors.accent)
            Text("Loading transfers…")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppColors.error)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.loadData() } }
                .font(AppTypography.actionSmall)
                .foregroundStyle(AppColors.accent)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColors.neutral500)
            Text("No transfers found")
                .font(AppTypography.label)
                .foregroundStyle(AppColors.textPrimaryDark)
            Text("Create allocations in the Distribution tab to see them here.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Shared Components

    private func actionButton(
        title: String,
        icon: String,
        color: Color,
        isLoading: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("Processing…")
                    }
                } else {
                    Label(title, systemImage: icon)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isDisabled && !isLoading ? color.opacity(0.5) : color)
            .cornerRadius(AppSpacing.radiusMedium)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.error)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.error)
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.error.opacity(0.1))
        .cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
