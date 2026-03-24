//
//  SACatalogView.swift
//  RSMS
//
//  Sales Associate catalog view — viewing products.
//

import SwiftUI

struct SACatalogView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    categoryChips
                    filterBar
                    Divider().background(AppColors.border)
                    productList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CATALOG")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppSpacing.md) {

                        // Cart button with item-count badge
                        Button { cart.showCart = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "cart")
                                    .font(AppTypography.toolbarIcon)
                                    .foregroundColor(AppColors.accent)
                                if cart.itemCount > 0 {
                                    Text("\(cart.itemCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(minWidth: 14, minHeight: 14)
                                        .padding(.horizontal, 2)
                                        .background(AppColors.accent)
                                        .clipShape(Capsule())
                                        .offset(x: 8, y: -6)
                                }
                            }
                        }

                        // Filter button with active-count badge
                        Button { vm.showFilters = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(AppTypography.toolbarIcon)
                                    .foregroundColor(AppColors.accent)
                                if vm.activeFilterCount > 0 {
                                    Text("\(vm.activeFilterCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 14, height: 14)
                                        .background(AppColors.accent)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $vm.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Name, SKU, barcode, brand…"
            )
            .sheet(isPresented: $vm.showFilters) {
                SACatalogFilterSheet(vm: vm)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedProduct) { product in
                SACatalogProductDetailSheet(product: product, vm: vm)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { cart.showCart },
                set: { cart.showCart = $0 }
            )) {
                SASaleCartView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                chip(label: "All", selected: vm.selectedCategoryId == nil) {
                    vm.selectedCategoryId = nil
                }
                ForEach(vm.categories) { cat in
                    chip(label: cat.name, selected: vm.selectedCategoryId == cat.id) {
                        vm.selectedCategoryId = (vm.selectedCategoryId == cat.id) ? nil : cat.id
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.sm)
        }
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(selected ? .semibold : .regular))
                .foregroundColor(selected ? AppColors.accent : AppColors.textPrimaryDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(selected
                              ? AppColors.accent.opacity(0.12)
                              : AppColors.backgroundSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(selected
                                ? AppColors.accent.opacity(0.4)
                                : AppColors.border,
                                lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    // MARK: - Filter Summary Bar

    private var filterBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Result count
            let count = vm.filtered.count
            Text("\(count) product\(count == 1 ? "" : "s")")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            Spacer()

            // Active filter pills
            if vm.availabilityFilter != .all {
                filterPill(vm.availabilityFilter.rawValue) {
                    vm.availabilityFilter = .all
                }
            }
            if !vm.minPriceText.isEmpty || !vm.maxPriceText.isEmpty {
                let label = priceRangeLabel()
                filterPill(label) {
                    vm.minPriceText = ""
                    vm.maxPriceText = ""
                }
            }
            if vm.sortOption != .nameAZ {
                filterPill(vm.sortOption.rawValue) {
                    vm.sortOption = .nameAZ
                }
            }
        }
    }
}

#Preview {
    SACatalogView()
}
