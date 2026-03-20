//
//  SACatalogView.swift
//  RSMS
//
//  Sales Associate guided catalog — keyword search, category chips,
//  price / availability / sort filters, real-time inventory badges.
//

import SwiftUI

// MARK: - Main Catalog View

struct SACatalogView: View {

    @State private var vm = SACatalogViewModel()
    @State private var selectedProduct: ProductDTO? = nil

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
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
        .padding(.vertical, 8)
    }

    private func filterPill(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.accent)
            Button(action: onRemove) {
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
        let min = vm.minPriceText.isEmpty ? "0" : "$\(vm.minPriceText)"
        let max = vm.maxPriceText.isEmpty ? "Any" : "$\(vm.maxPriceText)"
        return "\(min) – \(max)"
    }

    // MARK: - Product List

    @ViewBuilder
    private var productList: some View {
        if vm.isLoading && vm.products.isEmpty {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.accent)
            Spacer()
        } else if vm.filtered.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 1) {
                    ForEach(vm.filtered) { product in
                        Button { selectedProduct = product } label: {
                            productRow(product)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading, 72)
                    }
                }
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    // MARK: - Product Row

    private func productRow(_ product: ProductDTO) -> some View {
        HStack(spacing: AppSpacing.md) {

            // Thumbnail
            productThumbnail(product)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Text("·")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral500)
                    Text(product.sku)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral500)
                }
                if let cat = vm.categoryName(for: product.categoryId) {
                    Text(cat)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(AppColors.accent.opacity(0.8))
                }
            }

            Spacer(minLength: 0)

            // Price + Stock badge (right-aligned column)
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.formattedPrice)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)

                let info = vm.stockInfo(for: product.id)
                Text(info.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(info.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(info.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(AppTypography.chevron)
                .foregroundColor(AppColors.neutral600)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func productThumbnail(_ product: ProductDTO) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.backgroundTertiary)
                .frame(width: 48, height: 48)

            if let url = product.resolvedImageURLs.first {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    default:
                        Image(systemName: "bag.fill")
                            .font(.system(size: 18, weight: .ultraLight))
                            .foregroundColor(AppColors.neutral600)
                    }
                }
            } else {
                Image(systemName: "bag.fill")
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundColor(AppColors.neutral600)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: vm.searchText.isEmpty ? "tag.slash" : "magnifyingglass")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(AppColors.accent.opacity(0.4))
            Text(vm.searchText.isEmpty ? "No products match your filters" : "No results for \"\(vm.searchText)\"")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
            if vm.activeFilterCount > 0 || !vm.searchText.isEmpty {
                Button("Clear Filters") {
                    vm.clearFilters()
                    vm.searchText = ""
                }
                .font(AppTypography.label)
                .foregroundColor(AppColors.accent)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }
}

// MARK: - Filter Sheet

struct SACatalogFilterSheet: View {

    @Bindable var vm: SACatalogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // Sort By
                        filterSection("SORT BY") {
                            VStack(spacing: 0) {
                                ForEach(SACatalogViewModel.SortOption.allCases) { option in
                                    Button {
                                        vm.sortOption = option
                                    } label: {
                                        HStack {
                                            Text(option.rawValue)
                                                .font(AppTypography.bodyMedium)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Spacer()
                                            if vm.sortOption == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(AppColors.accent)
                                            }
                                        }
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, 13)
                                    }
                                    .buttonStyle(.plain)
                                    if option != SACatalogViewModel.SortOption.allCases.last {
                                        Divider().padding(.leading, AppSpacing.md)
                                    }
                                }
                            }
                            .background(AppColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                        }

                        // Availability
                        filterSection("AVAILABILITY") {
                            VStack(spacing: 0) {
                                ForEach(SACatalogViewModel.AvailabilityFilter.allCases) { option in
                                    Button {
                                        vm.availabilityFilter = option
                                    } label: {
                                        HStack {
                                            Circle()
                                                .fill(availabilityColor(option))
                                                .frame(width: 8, height: 8)
                                            Text(option.rawValue)
                                                .font(AppTypography.bodyMedium)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Spacer()
                                            if vm.availabilityFilter == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(AppColors.accent)
                                            }
                                        }
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, 13)
                                    }
                                    .buttonStyle(.plain)
                                    if option != SACatalogViewModel.AvailabilityFilter.allCases.last {
                                        Divider().padding(.leading, AppSpacing.md)
                                    }
                                }
                            }
                            .background(AppColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                        }

                        // Price Range
                        filterSection("PRICE RANGE") {
                            HStack(spacing: AppSpacing.md) {
                                priceField("Min $", text: $vm.minPriceText)
                                Text("–")
                                    .foregroundColor(AppColors.textSecondaryDark)
                                priceField("Max $", text: $vm.maxPriceText)
                            }
                        }

                        // Clear button
                        Button {
                            vm.clearFilters()
                        } label: {
                            Text("Clear All Filters")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.error)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.error.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .opacity(vm.activeFilterCount > 0 ? 1 : 0.4)
                        .disabled(vm.activeFilterCount == 0)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FILTERS")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
            content()
        }
    }

    private func priceField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.textPrimaryDark)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
    }

    private func availabilityColor(_ option: SACatalogViewModel.AvailabilityFilter) -> Color {
        switch option {
        case .all:        return AppColors.neutral500
        case .inStock:    return AppColors.success
        case .lowStock:   return AppColors.warning
        case .outOfStock: return AppColors.error
        }
    }
}
