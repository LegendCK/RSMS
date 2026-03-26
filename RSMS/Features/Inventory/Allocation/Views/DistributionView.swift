//
//  DistributionView.swift
//  RSMS
//
//  Central allocation screen: shows all products with per-location
//  stock levels. Tap "Allocate" on any store row to create an allocation.
//

import SwiftUI

struct DistributionView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AllocationViewModel()
    @State private var selectedProduct: ProductDTO?
    @State private var selectedDestinationInventory: InventoryDTO?
    @State private var showAllocationSheet = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if viewModel.isLoading && viewModel.inventory.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                mainContent
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search SKU or product…")
        .task { await viewModel.loadData() }
        .refreshable { await viewModel.loadData() }
        .sheet(isPresented: $showAllocationSheet) {
            if let product = selectedProduct,
               let destInv = selectedDestinationInventory {
                AllocationCreationSheet(
                    product: product,
                    destinationInventory: destInv,
                    sourceOptions: viewModel.sourceLocations(for: product.id),
                    viewModel: viewModel,
                    userId: appState.currentUserProfile?.id
                )
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppSpacing.md, pinnedViews: .sectionHeaders) {
                if viewModel.uniqueProducts.isEmpty {
                    emptyState
                        .padding(.top, AppSpacing.xxl)
                } else {
                    statsStrip
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.sm)

                    ForEach(viewModel.uniqueProducts) { product in
                        productSection(product)
                    }
                }
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        let totalInventory = viewModel.inventory
        let lowStockCount = totalInventory.filter { max($0.quantity - $0.reservedQuantity, 0) > 0 && max($0.quantity - $0.reservedQuantity, 0) <= 3 }.count
        let outCount = totalInventory.filter { max($0.quantity - $0.reservedQuantity, 0) == 0 }.count

        return HStack(spacing: AppSpacing.sm) {
            statCard("PRODUCTS", value: "\(viewModel.uniqueProducts.count)", color: AppColors.accent)
            statCard("LOW STOCK", value: "\(lowStockCount)", color: AppColors.warning)
            statCard("OUT", value: "\(outCount)", color: AppColors.error)
        }
    }

    private func statCard(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Product Section

    private func productSection(_ product: ProductDTO) -> some View {
        let rows = viewModel.inventoryForProduct(product.id)

        return VStack(alignment: .leading, spacing: 0) {
            // Product header
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let brand = product.brand {
                            Text(brand)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondary)
                        }
                        Text("·")
                            .foregroundStyle(AppColors.neutral500)
                        Text(product.sku)
                            .font(AppTypography.monoID)
                            .foregroundStyle(AppColors.neutral500)
                    }
                }
                Spacer()
                Text(product.formattedPrice)
                    .font(AppTypography.statSmall)
                    .foregroundStyle(AppColors.accent)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.sm)

            // Location rows
            VStack(spacing: 1) {
                ForEach(rows) { inv in
                    locationRow(inv, product: product)
                }
            }
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func locationRow(_ inv: InventoryDTO, product: ProductDTO) -> some View {
        let avail = max(inv.quantity - inv.reservedQuantity, 0)
        let isLow = avail > 0 && avail <= 3
        let isOut = avail == 0

        return HStack(spacing: AppSpacing.sm) {
            // Stock indicator stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(isOut ? AppColors.error : isLow ? AppColors.warning : AppColors.success)
                .frame(width: 3, height: 36)

            // Location name
            VStack(alignment: .leading, spacing: 2) {
                Text(inv.stores?.name ?? viewModel.locationName(for: inv.locationId))
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textPrimaryDark)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("On hand: \(inv.quantity)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondaryDark)
                    if inv.reservedQuantity > 0 {
                        Text("· Reserved: \(inv.reservedQuantity)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                }
            }

            Spacer()

            // Available badge
            Text(isOut ? "OUT" : "\(avail)")
                .font(AppTypography.statSmall)
                .foregroundStyle(isOut ? AppColors.error : isLow ? AppColors.warning : AppColors.success)
                .frame(minWidth: 32)

            // Allocate button
            Button {
                selectedProduct = product
                selectedDestinationInventory = inv
                showAllocationSheet = true
            } label: {
                Text("Allocate")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accent)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - Empty / Loading / Error

    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.accent)
                .scaleEffect(1.2)
            Text("Loading inventory…")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppColors.error)
            Text("Failed to load inventory")
                .font(AppTypography.label)
                .foregroundStyle(AppColors.textPrimaryDark)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadData() }
            }
            .font(AppTypography.actionSmall)
            .foregroundStyle(AppColors.accent)
            .padding(.top, AppSpacing.xs)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColors.neutral500)
            Text("No inventory records")
                .font(AppTypography.label)
                .foregroundStyle(AppColors.textPrimaryDark)
            Text("Seed inventory data in Supabase or add stock via the Stock-In flow.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
