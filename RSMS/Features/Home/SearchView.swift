//
//  SearchView.swift
//  infosys2
//
//  Premium search interface for products and categories.
//  Presented via sheet from floating search button.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var searchText = ""
    @State private var searchResults: [Product] = []
    @State private var selectedCategory: Category?
    
    @Query private var allProducts: [Product]
    @Query private var allCategories: [Category]
    
    var filteredProducts: [Product] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return []
        }
        return allProducts.filter { product in
            product.name.localizedCaseInsensitiveContains(searchText) ||
            product.productDescription.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with search field
                    VStack(spacing: AppSpacing.md) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.textSecondaryDark)
                                .onTapGesture { dismiss() }

                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(AppColors.textSecondaryDark)

                                TextField("Search products...", text: $searchText)
                                    .font(AppTypography.bodyLarge)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(AppColors.textSecondaryDark)
                                    }
                                }
                            }
                            .padding(AppSpacing.sm)
                            .background(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .stroke(
                                        Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(AppSpacing.radiusMedium)

                            Spacer()

                            CartShortcutButton()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)
                    }
                    .padding(.bottom, AppSpacing.md)

                    // Content
                    if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Empty state — show categories
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                                Text("Browse Categories")
                                    .font(AppTypography.heading2)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .padding(.horizontal, AppSpacing.screenHorizontal)

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: AppSpacing.md),
                                        GridItem(.flexible(), spacing: AppSpacing.md)
                                    ],
                                    spacing: AppSpacing.md
                                ) {
                                    ForEach(allCategories, id: \.id) { category in
                                        NavigationLink(destination: CategoryDetailView(category: category)) {
                                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                                        Text(category.name)
                                                            .font(AppTypography.heading3)
                                                            .foregroundColor(AppColors.textPrimaryDark)

                                                        Text("\(category.parsedProductTypes.count) types")
                                                            .font(AppTypography.caption)
                                                            .foregroundColor(AppColors.textSecondaryDark)
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(AppColors.accent)
                                                }
                                                .padding(AppSpacing.md)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .frame(height: 100)
                                                .background(AppColors.backgroundWhite)
                                                .cornerRadius(AppSpacing.radiusMedium)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                            .padding(.vertical, AppSpacing.md)
                        }
                    } else if filteredProducts.isEmpty {
                        // No results
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.textSecondaryDark)

                            Text("No Results")
                                .font(AppTypography.heading2)
                                .foregroundColor(AppColors.textPrimaryDark)

                            Text("We couldn't find any products matching '\(searchText)'")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    } else {
                        // Search results
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: AppSpacing.md) {
                                Text("\(filteredProducts.count) Result\(filteredProducts.count != 1 ? "s" : "")")
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                    .padding(.horizontal, AppSpacing.screenHorizontal)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                LazyVStack(spacing: AppSpacing.md) {
                                    ForEach(filteredProducts, id: \.id) { product in
                                        NavigationLink(destination: ProductDetailView(product: product)) {
                                            HStack(spacing: AppSpacing.md) {
                                                ProductArtworkView(
                                                    imageSource: product.imageName,
                                                    fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock.fill" : "bag.fill",
                                                    cornerRadius: AppSpacing.radiusSmall
                                                )
                                                .frame(width: 60, height: 60)

                                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                                    Text(product.name)
                                                        .font(AppTypography.bodyMedium)
                                                        .foregroundColor(AppColors.textPrimaryDark)
                                                        .lineLimit(1)

                                                    Text(product.productDescription)
                                                        .font(AppTypography.caption)
                                                        .foregroundColor(AppColors.textSecondaryDark)
                                                        .lineLimit(1)

                                                    Text(product.formattedPrice)
                                                        .font(AppTypography.priceSmall)
                                                        .foregroundColor(AppColors.accent)
                                                }

                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(AppColors.textSecondaryDark)
                                            }
                                            .padding(AppSpacing.md)
                                            .background(AppColors.backgroundWhite)
                                            .cornerRadius(AppSpacing.radiusMedium)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                            .padding(.vertical, AppSpacing.md)
                        }
                    }

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SearchView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
