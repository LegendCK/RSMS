//
//  SearchView.swift
//  infosys2
//
//  Native iOS search experience for products and categories.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @State private var searchText = ""

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

    private var sortedCategories: [Category] {
        allCategories.sorted { $0.displayOrder < $1.displayOrder }
    }

    private var featuredSuggestions: [Product] {
        allProducts
            .filter { $0.isFeatured }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    List {
                        if !featuredSuggestions.isEmpty {
                            Section("Suggested") {
                                ForEach(featuredSuggestions, id: \.id) { product in
                                    NavigationLink(destination: ProductDetailView(product: product)) {
                                        productRow(product)
                                    }
                                }
                            }
                        }

                        Section("Browse Categories") {
                            ForEach(sortedCategories, id: \.id) { category in
                                NavigationLink(destination: CategoryDetailView(category: category)) {
                                    HStack(spacing: 12) {
                                        Image(systemName: category.icon)
                                            .foregroundColor(AppColors.accent)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(category.name)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Text("\(category.parsedProductTypes.count) types")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.textSecondaryDark)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                } else if filteredProducts.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No products found for \"\(searchText)\"")
                    )
                } else {
                    List {
                        Section("\(filteredProducts.count) Result\(filteredProducts.count == 1 ? "" : "s")") {
                            ForEach(filteredProducts, id: \.id) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    productRow(product)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search products")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CartShortcutButton()
                }
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: 12) {
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock.fill" : "bag.fill",
                cornerRadius: AppSpacing.radiusSmall
            )
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.formattedPrice)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SearchView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
