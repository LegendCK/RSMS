//
//  SACatalogView.swift
//  RSMS
//
//  Sales Associate catalog view — modern card layout with luxurious feel.
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
                    productList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CATALOG")
                        .font(.system(size: 11, weight: .black))
                        .tracking(4)
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Cart button with item-count badge
                        Button { cart.showCart = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "cart")
                                    .font(.system(size: 17, weight: .light))
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
                                    .font(.system(size: 17, weight: .light))
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
            HStack(spacing: 8) {
                chip(label: "All", selected: vm.selectedCategoryId == nil) {
                    vm.selectedCategoryId = nil
                }
                ForEach(vm.categories) { cat in
                    chip(label: cat.name, selected: vm.selectedCategoryId == cat.id) {
                        vm.selectedCategoryId = (vm.selectedCategoryId == cat.id) ? nil : cat.id
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(AppColors.backgroundPrimary)
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? AppColors.accent : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(selected
                              ? AppColors.accent.opacity(0.10)
                              : AppColors.backgroundSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(selected
                                ? AppColors.accent.opacity(0.35)
                                : AppColors.border,
                                lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    // MARK: - Filter Summary Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            let count = vm.filtered.count
            Text("\(count) product\(count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)

            Spacer()

            if vm.availabilityFilter != .all {
                filterPill(vm.availabilityFilter.rawValue) {
                    vm.availabilityFilter = .all
                }
            }
            if !vm.minPriceText.isEmpty || !vm.maxPriceText.isEmpty {
                filterPill(priceRangeLabel()) {
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
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Product List

    private var productList: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .tint(AppColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 80)
            } else if vm.filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No products found")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.filtered) { product in
                            productCard(product)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func productCard(_ product: ProductDTO) -> some View {
        Button { selectedProduct = product } label: {
            HStack(spacing: 14) {

                // Thumbnail
                Group {
                    if let url = product.resolvedImageURLs.first {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                ZStack {
                                    AppColors.backgroundTertiary
                                    ProgressView().scaleEffect(0.6).tint(AppColors.accent)
                                }
                            }
                        }
                    } else {
                        ZStack {
                            AppColors.backgroundTertiary
                            Image(systemName: "bag.fill")
                                .font(.system(size: 20, weight: .ultraLight))
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Text content
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let brand = product.brand {
                        Text(brand.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(AppColors.accent.opacity(0.8))
                    }

                    Text(product.sku)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.6))
                }

                Spacer(minLength: 0)

                // Price + stock
                VStack(alignment: .trailing, spacing: 6) {
                    Text("₹\(product.price, specifier: "%.0f")")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)

                    let (label, color) = vm.stockInfo(for: product.id)
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.10))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Pill Helper

    private func filterPill(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.accent)
            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.accent.opacity(0.10))
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
