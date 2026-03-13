//
//  CatalogView.swift
//  infosys2
//
//  Enterprise catalog management — SKU management, categories, pricing rules, promotions.
//

import SwiftUI
import SwiftData

struct CatalogView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Products").tag(0)
                        Text("Categories").tag(1)
                        Text("Pricing").tag(2)
                        Text("Promos").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: CatalogProductsSubview()
                    case 1: CatalogCategoriesSubview()
                    case 2: CatalogPricingSubview()
                    case 3: CatalogPromotionsSubview()
                    default: CatalogProductsSubview()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Catalog")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Products Sub-view (SKU Management)

struct CatalogProductsSubview: View {
    @Query(sort: \Product.createdAt, order: .reverse) private var allProducts: [Product]
    @Query(sort: \Category.displayOrder) private var allCategories: [Category]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil

    private var filtered: [Product] {
        var list = allProducts
        if let c = selectedCategory { list = list.filter { $0.categoryName == c } }
        if !searchText.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.brand.localizedCaseInsensitiveContains(searchText) } }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.neutral500)
                TextField("Search SKUs...", text: $searchText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)

            // Category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    chipButton(label: "All", selected: selectedCategory == nil) { selectedCategory = nil }
                    ForEach(allCategories) { cat in
                        chipButton(label: cat.name, selected: selectedCategory == cat.name) { selectedCategory = cat.name }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.vertical, AppSpacing.xs)

            // Count
            HStack {
                Text("\(filtered.count) products")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xs)

            // List
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(filtered) { product in
                        productRow(product)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(AppColors.backgroundTertiary).frame(width: 44, height: 44)
                Image(systemName: product.imageName).font(AppTypography.productRowIcon).foregroundColor(AppColors.neutral600)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(product.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
                    if product.isLimitedEdition {
                        Text("LTD").font(AppTypography.pico).foregroundColor(AppColors.accent)
                            .padding(.horizontal, 4).padding(.vertical, 1).background(AppColors.accent.opacity(0.15)).cornerRadius(3)
                    }
                }
                Text(product.categoryName).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(product.formattedPrice).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                stockLabel(product.stockCount)
            }

            Menu {
                Button(action: {}) { Label("Edit", systemImage: "pencil") }
                Button(action: {}) { Label("Price", systemImage: "dollarsign.circle") }
                Button(action: {}) { Label("Stock", systemImage: "shippingbox") }
                Divider()
                Button(role: .destructive, action: { modelContext.delete(product); try? modelContext.save() }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis").font(AppTypography.iconSmall).foregroundColor(AppColors.neutral500)
                    .frame(width: 28, height: AppSpacing.touchTarget)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func stockLabel(_ count: Int) -> some View {
        let color = count > 5 ? AppColors.success : count > 0 ? AppColors.warning : AppColors.error
        return HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(count)").font(AppTypography.caption).foregroundColor(color)
        }
    }

    private func chipButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(AppTypography.caption)
                .foregroundColor(selected ? AppColors.primary : AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
                .background(selected ? AppColors.accent : AppColors.backgroundTertiary)
                .cornerRadius(AppSpacing.radiusSmall)
        }
    }
}

// MARK: - Categories Sub-view

struct CatalogCategoriesSubview: View {
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @Query private var allProducts: [Product]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(categories) { cat in
                    let count = allProducts.filter { $0.categoryName == cat.name }.count
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle().fill(AppColors.accent.opacity(0.12)).frame(width: 44, height: 44)
                            Image(systemName: cat.icon).font(AppTypography.catalogIcon).foregroundColor(AppColors.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                            Text(cat.categoryDescription).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark).lineLimit(1)
                        }
                        Spacer()
                        Text("\(count) SKUs").font(AppTypography.caption).foregroundColor(AppColors.accent)
                        Image(systemName: "chevron.right").font(AppTypography.chevron).foregroundColor(AppColors.neutral600)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusMedium)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }
}

// MARK: - Pricing Sub-view

struct CatalogPricingSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                pricingCard(title: "Tax Configuration", subtitle: "Regional tax rates and exemptions",
                            icon: "percent", items: ["US Federal — 0%", "New York — 8.875%", "California — 7.25%", "EU VAT — 20%", "Japan — 10%"])

                pricingCard(title: "Currency Settings", subtitle: "Multi-currency pricing",
                            icon: "dollarsign.circle", items: ["USD — Primary", "EUR — Auto-convert", "GBP — Auto-convert", "JPY — Auto-convert"])

                pricingCard(title: "Discount Rules", subtitle: "Automated discount tiers",
                            icon: "tag", items: ["VIP Gold — 5% off", "VIP Platinum — 10% off", "Employee — 15% off", "Loyalty 1000+ pts — $50 credit"])
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func pricingCard(title: String, subtitle: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon).font(AppTypography.iconMedium).foregroundColor(AppColors.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text(subtitle).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Button(action: {}) {
                    Text("Edit").font(AppTypography.editLink).foregroundColor(AppColors.accent)
                }
            }
            Divider().background(AppColors.border)
            ForEach(items, id: \.self) { item in
                Text(item).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
                    .padding(.leading, AppSpacing.xl)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }
}

// MARK: - Promotions Sub-view

struct CatalogPromotionsSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                promoCard(name: "Spring 2026 Collection", status: "Active", discount: "10% off select handbags",
                          start: "Mar 1", end: "Apr 15", color: AppColors.success)
                promoCard(name: "VIP Private Sale", status: "Scheduled", discount: "15% off all categories",
                          start: "Apr 1", end: "Apr 7", color: AppColors.info)
                promoCard(name: "Holiday 2025 Clearance", status: "Ended", discount: "20% off accessories",
                          start: "Dec 26", end: "Jan 15", color: AppColors.neutral500)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func promoCard(name: String, status: String, discount: String, start: String, end: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text(status.uppercased()).font(AppTypography.nano).foregroundColor(color)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(color.opacity(0.12)).cornerRadius(4)
            }
            Text(discount).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
            HStack(spacing: AppSpacing.md) {
                Label(start, systemImage: "calendar").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                Image(systemName: "arrow.right").font(AppTypography.arrowInline).foregroundColor(AppColors.neutral600)
                Label(end, systemImage: "calendar").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }
}

#Preview {
    CatalogView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
