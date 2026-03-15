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
    @State private var searchText = ""

    @Query private var allProducts: [Product]
    @Query(sort: \Category.displayOrder) private var allCategories: [Category]

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
            List {
                if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section("Browse Categories") {
                        ForEach(allCategories, id: \.id) { category in
                            NavigationLink(destination: CategoryDetailView(category: category)) {
                                categoryRow(category)
                            }
                        }
                    }
                    Section("Discover") {
                        Text("Use Search to quickly find products by name, collection, or style.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    }
                } else if filteredProducts.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("No products match \"\(searchText)\".")
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("\(filteredProducts.count) Result\(filteredProducts.count == 1 ? "" : "s")") {
                        ForEach(filteredProducts, id: \.id) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                resultRow(product)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.automatic)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search products")
            .searchSuggestions {
                ForEach(allCategories.prefix(4), id: \.id) { category in
                    Text(category.name).searchCompletion(category.name)
                }
                ForEach(allProducts.prefix(4), id: \.id) { product in
                    Text(product.name).searchCompletion(product.name)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .tint(AppColors.accent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CartShortcutButton()
                }
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: 36, height: 36)
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(category.parsedProductTypes.count) types")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func resultRow(_ product: Product) -> some View {
        HStack(spacing: 12) {
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock.fill" : "bag.fill",
                cornerRadius: 10
            )
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brand.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .lineLimit(1)
                Text(product.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(product.productDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Text(product.formattedPrice)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.accent)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SearchView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
