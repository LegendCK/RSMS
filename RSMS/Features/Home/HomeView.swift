////  HomeView.swift
//  RSMS
//
//  Home screen with hero banner, featured products, and category strip.
//  View All / See All buttons are wired to the correct destination views.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Query(filter: #Predicate<Product> { $0.isFeatured == true })
    private var featuredProducts: [Product]
    @Query(sort: \Category.displayOrder)
    private var categories: [Category]
    @Query private var allProducts: [Product]

    // Navigation state
    @State private var showAllCategories = false
    @State private var showAllFeatured = false
    @State private var showAllArrivals = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        heroBanner
                        categoriesSection
                        featuredSection
                        newArrivalsSection
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("MAISON LUXE")
                        .font(AppTypography.navTitle)
                        .tracking(3)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button(action: {}) {
                            Image(systemName: "bell")
                                .font(AppTypography.bellIcon)
                                .foregroundStyle(Color.primary)
                        }
                        CartShortcutButton()
                    }
                }
            }
            // Full-screen navigation destinations
            .navigationDestination(isPresented: $showAllCategories) {
                CategoriesView()
            }
            .navigationDestination(isPresented: $showAllFeatured) {
                ProductListView(categoryFilter: nil)
            }
            .navigationDestination(isPresented: $showAllArrivals) {
                ProductListView(categoryFilter: nil)
            }
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            // System material background — native iOS feel
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .frame(height: 210)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppColors.accent)
                        .frame(height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text("NEW COLLECTION")
                    .font(AppTypography.overline)
                    .tracking(3)
                    .foregroundColor(AppColors.accent)

                Text("Spring 2026")
                    .font(AppTypography.displayMedium)
                    .foregroundColor(Color.primary)

                Text("Discover the essence of modern luxury")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(Color.secondary)

                Spacer().frame(height: 4)

                HStack(spacing: 5) {
                    Text("Explore")
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(20)
            .padding(.bottom, 16)

            // Decorative diamond
            Image(systemName: "diamond.fill")
                .font(AppTypography.iconDecorative)
                .foregroundColor(AppColors.accent.opacity(0.07))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 24)
                .padding(.top, 20)
        }
        .frame(height: 210)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 4)
    }

    // MARK: - Categories Strip

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Categories") {
                showAllCategories = true
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(categories) { category in
                        NavigationLink(destination: ProductListView(categoryFilter: category.name)) {
                            categoryChip(category)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    private func categoryChip(_ category: Category) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .strokeBorder(AppColors.accent.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)

                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }

            Text(category.name)
                .font(AppTypography.caption)
                .foregroundColor(Color.secondary)
                .lineLimit(1)
        }
        .frame(width: 74)
    }

    // MARK: - Featured Products

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Featured") {
                showAllFeatured = true
            }

            if featuredProducts.isEmpty {
                emptyBanner(icon: "star", message: "No featured products yet")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(featuredProducts) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                productCard(product)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
        }
    }

    // MARK: - New Arrivals

    private var newArrivalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "New Arrivals") {
                showAllArrivals = true
            }

            if allProducts.isEmpty {
                emptyBanner(icon: "shippingbox", message: "No products available")
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(allProducts.prefix(4))) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            productRow(product)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.heading2)
                .foregroundColor(Color.primary)
            Spacer()
            Button(action: action) {
                HStack(spacing: 3) {
                    Text("View All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func productCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ProductArtworkView(
                    imageSource: product.imageName,
                    fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock.fill" : "bag.fill",
                    cornerRadius: 0
                )
                .frame(width: 175, height: 195)

                if product.isLimitedEdition {
                    Text("LIMITED")
                        .font(AppTypography.overline)
                        .tracking(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accent)
                        .cornerRadius(4)
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.brand.uppercased())
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(AppColors.accent)

                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(Color.primary)
                    .lineLimit(1)

                Text(product.formattedPrice)
                    .font(AppTypography.priceSmall)
                    .foregroundColor(Color.secondary)
            }
            .padding(12)
        }
        .frame(width: 175)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 3)
    }

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: 14) {
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock.fill" : "bag.fill",
                cornerRadius: AppSpacing.radiusMedium
            )
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brand.uppercased())
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(AppColors.accent)

                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(Color.primary)

                Text(product.formattedPrice)
                    .font(AppTypography.priceSmall)
                    .foregroundColor(Color.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func emptyBanner(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent.opacity(0.5))
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
