//
//  SACatalogView.swift
//  RSMS
//
//  Sales Associate catalog view — viewing products.
//

import SwiftUI

struct SACatalogView: View {
    @State private var vm = SACatalogViewModel()
    @Environment(SACartViewModel.self) private var cart
    @State private var selectedProduct: ProductDTO?

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
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Product List

    private var productList: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .tint(AppColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, AppSpacing.xxxl)
            } else if vm.filtered.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(AppColors.neutral300)
                    Text("No products found")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, AppSpacing.xxxl)
            } else {
                List(vm.filtered) { product in
                    Button { selectedProduct = product } label: {
                        HStack(spacing: AppSpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .lineLimit(1)
                                if let brand = product.brand {
                                    Text(brand)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                Text(product.sku)
                                    .font(AppTypography.micro)
                                    .foregroundColor(AppColors.neutral300)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("₹\(product.price, specifier: "%.0f")")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                let (label, color) = vm.stockInfo(for: product.id)
                                Text(label)
                                    .font(AppTypography.micro)
                                    .foregroundColor(color)
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppColors.backgroundPrimary)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Filter Pill Helper

    private func filterPill(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.accent)
            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.accent.opacity(0.1))
        .clipShape(Capsule())
    }

    private func priceRangeLabel() -> String {
        let min = vm.minPriceText.isEmpty ? nil : vm.minPriceText
        let max = vm.maxPriceText.isEmpty ? nil : vm.maxPriceText
        switch (min, max) {
        case let (lo?, hi?): return "₹\(lo)–₹\(hi)"
        case let (lo?, nil): return "₹\(lo)+"
        case let (nil, hi?): return "Up to ₹\(hi)"
        default:             return "Price"
        }
    }
}

#Preview {
    SACatalogView()
}
