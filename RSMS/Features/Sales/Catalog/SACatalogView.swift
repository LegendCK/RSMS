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
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary.opacity(0.55))
    }

    private func filterPill(_ label: String, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.accent)
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 6)
        .background(AppColors.accent.opacity(0.12))
        .clipShape(Capsule())
    }

    private func priceRangeLabel() -> String {
        switch (vm.minPriceText.isEmpty, vm.maxPriceText.isEmpty) {
        case (false, false):
            return "₹\(vm.minPriceText)-₹\(vm.maxPriceText)"
        case (false, true):
            return "Min ₹\(vm.minPriceText)"
        case (true, false):
            return "Up to ₹\(vm.maxPriceText)"
        case (true, true):
            return "Price"
        }
    }

    private var productList: some View {
        Group {
            if vm.isLoading && vm.filtered.isEmpty {
                ProgressView()
                    .tint(AppColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, AppSpacing.xxl)
            } else if let error = vm.errorMessage, vm.products.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(AppColors.warning)
                    Text("Could not load catalog")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.load() }
                    }
                    .foregroundColor(AppColors.accent)
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.filtered.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(AppColors.neutral500)
                    Text("No products match your filters")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Button("Clear Filters") {
                        vm.clearFilters()
                        vm.searchText = ""
                    }
                    .foregroundColor(AppColors.accent)
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(vm.filtered) { product in
                            Button {
                                selectedProduct = product
                            } label: {
                                productRow(product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
    }

    private func productRow(_ product: ProductDTO) -> some View {
        let stock = vm.stockInfo(for: product.id)

        return HStack(spacing: AppSpacing.md) {
            productArtwork(for: product)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)

                Text(product.brand ?? "Maison Luxe")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(product.formattedPrice)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                    Text(stock.label)
                        .font(AppTypography.micro)
                        .foregroundColor(stock.color)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.chevron)
                .foregroundColor(AppColors.neutral500)
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    @ViewBuilder
    private func productArtwork(for product: ProductDTO) -> some View {
        if let url = product.resolvedImageURLs.first {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholderArtwork
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            placeholderArtwork
                .frame(width: 64, height: 64)
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(AppColors.backgroundTertiary)
            .overlay(
                Image(systemName: "bag.fill")
                    .foregroundColor(AppColors.neutral500)
            )
    }
}

private struct SACatalogFilterSheet: View {
    let vm: SACatalogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var bindableVM = vm

        NavigationStack {
            Form {
                Section("Availability") {
                    Picker("Stock", selection: $bindableVM.availabilityFilter) {
                        ForEach(SACatalogViewModel.AvailabilityFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Price Range") {
                    TextField("Min price", text: $bindableVM.minPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Max price", text: $bindableVM.maxPriceText)
                        .keyboardType(.decimalPad)
                }

                Section("Sort") {
                    Picker("Sort By", selection: $bindableVM.sortOption) {
                        ForEach(SACatalogViewModel.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset") {
                        vm.clearFilters()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

#Preview {
    SACatalogView()
}
