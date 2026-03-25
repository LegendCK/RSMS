//
//  ProductListView.swift
//  RSMS
//
//  Minimal editorial product grid — luxury retail aesthetic.
//

import SwiftUI
import SwiftData

struct ProductListView: View {
    let categoryFilter: String?
    var productTypeFilter: String? = nil
    @Query private var allProducts: [Product]
    @Environment(\.modelContext) private var modelContext

    @State private var sortOption: SortOption = .featured
    @State private var selectedGender: GenderFilter = .all

    enum SortOption: String, CaseIterable {
        case featured = "Featured"
        case priceLow = "Price ↑"
        case priceHigh = "Price ↓"
        case newest = "Newest"
    }

    private var filteredProducts: [Product] {
        var filtered: [Product]
        if let cat = categoryFilter {
            filtered = allProducts.filter { $0.categoryName == cat }
        } else {
            filtered = allProducts
        }
        if let typeFilter = productTypeFilter {
            filtered = filtered.filter { $0.productTypeName == typeFilter }
        }
        if selectedGender != .all {
            filtered = filtered.filter { selectedGender.matches($0) }
        }
        switch sortOption {
        case .featured: return filtered.sorted { $0.isFeatured && !$1.isFeatured }
        case .priceLow: return filtered.sorted { $0.price < $1.price }
        case .priceHigh: return filtered.sorted { $0.price > $1.price }
        case .newest: return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Minimal sort bar
                    HStack {
                        Text("\(filteredProducts.count) items")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(.black.opacity(0.5))

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
                                Text("SORT")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(2)
                                    .foregroundColor(.black)
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    Rectangle()
                        .fill(Color.black.opacity(0.07))
                        .frame(height: 1)

                    // Gender filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(GenderFilter.allCases, id: \.self) { gender in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedGender = gender
                                    }
                                } label: {
                                    Text(gender.rawValue.uppercased())
                                        .font(.system(size: 10, weight: selectedGender == gender ? .bold : .medium))
                                        .tracking(1.5)
                                        .foregroundColor(selectedGender == gender ? .white : .black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(selectedGender == gender ? Color.black : Color.clear)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().strokeBorder(
                                                selectedGender == gender ? Color.clear : Color(.systemGray4),
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 10)

                    // 2-column grid with 1pt gap (Zara-style)
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(filteredProducts) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                productTile(product)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    Spacer().frame(height: 48)
                }
            }
        }
        .navigationTitle(productTypeFilter ?? categoryFilter ?? "All Products")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartShortcutButton()
            }
        }
    }

    private func productTile(_ product: Product) -> some View {
        let isOutOfStock = product.stockCount == 0
        return VStack(alignment: .leading, spacing: 0) {
            // Fixed 3:4 aspect ratio image area — uniform across all tiles
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    ProductArtworkView(
                        imageSource: product.imageName,
                        fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock" : "bag",
                        cornerRadius: 0
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .background(Color(.systemGray6))
                    .overlay {
                        if isOutOfStock {
                            Color.white.opacity(0.55)
                        }
                    }

                    // Limited badge at bottom-left
                    if product.isLimitedEdition {
                        HStack {
                            Text("LIMITED")
                                .font(.system(size: 7, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AppColors.accent)
                            Spacer()
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isOutOfStock {
                        Text("OUT OF STOCK")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(3)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // Wishlist button — top-right
                    Button(action: {
                        product.isWishlisted.toggle()
                        try? modelContext.save()
                    }) {
                        Image(systemName: product.isWishlisted ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(product.isWishlisted ? AppColors.accent : .black)
                            .padding(9)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            }
            .aspectRatio(3/4, contentMode: .fit)   // ← fixed ratio: all tiles identical

            // Info block — fixed height so text rows align across columns
            VStack(alignment: .leading, spacing: 3) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(isOutOfStock ? .secondary : AppColors.accent)
                Text(product.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isOutOfStock ? .secondary : .black)
                    .lineLimit(1)
                Text(product.formattedPrice)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.black.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
        }
        .background(Color.white)
    }
}

#Preview {
    NavigationStack {
        ProductListView(categoryFilter: "Leather Goods")
    }
    .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
