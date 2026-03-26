//
//  InventoryOverviewView.swift
//  RSMS
//
//  Cross-store / cross-warehouse inventory visibility for Sales Associates.
//  Read-only view — groups products by store location with quantity and low-stock indicators.
//

import SwiftUI
import SwiftData

struct InventoryOverviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allInventory: [InventoryByLocation]
    @Query private var stores: [StoreLocation]

    @State private var searchText = ""
    @State private var selectedStoreId: UUID? = nil
    @State private var isRefreshing = false

    // All unique store IDs present in inventory
    private var storeIds: [UUID] {
        let ids = Set(allInventory.map(\.locationId))
        return Array(ids).sorted { a, b in
            let nameA = stores.first(where: { $0.id == a })?.name ?? ""
            let nameB = stores.first(where: { $0.id == b })?.name ?? ""
            return nameA < nameB
        }
    }

    private var filteredInventory: [InventoryByLocation] {
        var items = allInventory

        // Store filter
        if let sid = selectedStoreId {
            items = items.filter { $0.locationId == sid }
        }

        // Search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.productName.lowercased().contains(q) ||
                $0.sku.lowercased().contains(q) ||
                $0.categoryName.lowercased().contains(q)
            }
        }

        return items.sorted { $0.productName < $1.productName }
    }

    // Aggregate stats
    private var totalSKUs: Int { filteredInventory.count }
    private var totalUnits: Int { filteredInventory.reduce(0) { $0 + $1.quantity } }
    private var outOfStock: Int { filteredInventory.filter { $0.quantity == 0 }.count }
    private var lowStock: Int { filteredInventory.filter { $0.quantity > 0 && $0.quantity <= $0.reorderPoint }.count }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Store filter pills
                storeFilterRow
                    .padding(.vertical, AppSpacing.sm)

                // Stats row
                statsRow
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.sm)

                if filteredInventory.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.xs) {
                            ForEach(filteredInventory, id: \.productId) { item in
                                inventoryRow(item)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search products, SKUs…")
        .refreshable { await refreshInventory() }
        .task { await refreshInventory() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Inventory")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isRefreshing {
                    ProgressView()
                        .tint(AppColors.accent)
                        .scaleEffect(0.85)
                }
            }
        }
    }

    // MARK: - Store Filter Row

    private var storeFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                filterPill("All Stores", isSelected: selectedStoreId == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedStoreId = nil }
                }

                ForEach(storeIds, id: \.self) { sid in
                    let storeName = stores.first(where: { $0.id == sid })?.name ?? "Store"
                    filterPill(storeName, isSelected: selectedStoreId == sid) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedStoreId = sid }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func filterPill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? AppColors.textPrimaryLight : AppColors.textSecondaryDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? AppColors.accent : AppColors.backgroundSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            statBadge("\(totalSKUs)", label: "SKUs", color: AppColors.info)
            statBadge("\(totalUnits)", label: "Units", color: AppColors.accent)
            statBadge("\(lowStock)", label: "Low", color: AppColors.warning)
            statBadge("\(outOfStock)", label: "Out", color: AppColors.error)
        }
    }

    private func statBadge(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTypography.heading3)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.pico)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Inventory Row

    private func inventoryRow(_ item: InventoryByLocation) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Stock indicator dot
            Circle()
                .fill(stockColor(item))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                HStack(spacing: AppSpacing.sm) {
                    Text(item.sku)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    if let storeName = stores.first(where: { $0.id == item.locationId })?.name {
                        Text("· \(storeName)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.neutral600)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.quantity)")
                    .font(AppTypography.label)
                    .foregroundColor(stockColor(item))
                Text("of \(item.reorderPoint) min")
                    .font(AppTypography.pico)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.backgroundSecondary)
                    .frame(width: 100, height: 100)
                Image(systemName: "shippingbox")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundColor(AppColors.neutral600)
            }
            VStack(spacing: AppSpacing.xs) {
                Text("No Inventory Data")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Inventory data will sync from all stores")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func stockColor(_ item: InventoryByLocation) -> Color {
        if item.quantity == 0 { return AppColors.error }
        if item.quantity <= item.reorderPoint { return AppColors.warning }
        return AppColors.success
    }

    @MainActor
    private func refreshInventory() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await InventorySyncService.shared.syncInventory(modelContext: modelContext)
        } catch {
            print("[InventoryOverviewView] Sync failed: \(error.localizedDescription)")
        }
    }
}
