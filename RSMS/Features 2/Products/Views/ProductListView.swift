//
//  ProductListView.swift
//  infosys2
//
//  Product listing grid filtered by category.
//

import SwiftUI
import SwiftData

struct ProductListView: View {
    let categoryFilter: String
    var productTypeFilter: String? = nil
    @Query private var allProducts: [Product]
    @Environment(\.modelContext) private var modelContext

    @State private var sortOption: SortOption = .featured

    enum SortOption: String, CaseIterable {
        case featured = "Featured"
        case priceLow = "Price: Low to High"
        case priceHigh = "Price: High to Low"
        case newest = "Newest"
    }

    private var filteredProducts: [Product] {
        var filtered = allProducts.filter { $0.categoryName == categoryFilter }
        if let typeFilter = productTypeFilter {
            filtered = filtered.filter { $0.productTypeName == typeFilter }
        }
        switch sortOption {
        case .featured:
            return filtered.sorted { $0.isFeatured && !$1.isFeatured }
        case .priceLow:
            return filtered.sorted { $0.price < $1.price }
        case .priceHigh:
            return filtered.sorted { $0.price > $1.price }
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Sort bar
                    HStack {
                        Text("\(filteredProducts.count) items")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)

                        Spacer()

                        Menu {
                            ForEach(SortOption.allCases, id: \.rawValue) { option in
                                Button(action: { sortOption = option }) {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Sort")
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.accent)
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(AppTypography.sortIcon)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Product grid
                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(filteredProducts) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                productTile(product)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .navigationTitle(productTypeFilter ?? categoryFilter)
        .navigationBarTitleDisplayMode(.large)
    }

    private func productTile(_ product: Product) -> some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                ZStack {
                    AppColors.backgroundSecondary
                        .frame(height: 180)

                    Image(systemName: product.imageName)
                        .font(AppTypography.iconProductMedium)
                        .foregroundColor(AppColors.neutral600)

                    // Wishlist heart
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                product.isWishlisted.toggle()
                                try? modelContext.save()
                            }) {
                                Image(systemName: product.isWishlisted ? "heart.fill" : "heart")
                                    .font(AppTypography.heartIconSmall)
                                    .foregroundColor(product.isWishlisted ? AppColors.error : AppColors.textPrimaryDark)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                    }
                    .padding(8)

                    // Limited edition badge
                    if product.isLimitedEdition {
                        VStack {
                            Spacer()
                            HStack {
                                Text("LIMITED")
                                    .font(AppTypography.overline)
                                    .tracking(1)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.accent)
                                    .cornerRadius(4)
                                Spacer()
                            }
                            .padding(8)
                        }
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: AppSpacing.radiusLarge,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: AppSpacing.radiusLarge
                    )
                )

                // Details
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(product.brand.uppercased())
                        .font(AppTypography.overline)
                        .tracking(1)
                        .foregroundColor(AppColors.accent)

                    Text(product.name)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)

                    Text(product.formattedPrice)
                        .font(AppTypography.priceSmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                .padding(AppSpacing.sm)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProductListView(categoryFilter: "Leather Goods")
    }
    .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
