//
//  HomeView.swift
//  infosys2
//
//  Home screen with hero banner, featured products, and category strip.
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

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xxl) {
                        // Hero banner
                        heroBanner

                        // Categories strip
                        categoriesSection

                        // Featured products
                        featuredSection

                        // New arrivals
                        newArrivalsSection
                    }
                    .padding(.bottom, AppSpacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("MAISON LUXE")
                            .font(AppTypography.navTitle)
                            .tracking(3)
                            .foregroundColor(AppColors.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "bell")
                            .font(AppTypography.bellIcon)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [AppColors.backgroundSecondary, AppColors.backgroundTertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)
            .overlay(
                // Gold accent line at top
                Rectangle()
                    .fill(AppColors.accent)
                    .frame(height: 2),
                alignment: .top
            )

            // Content
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("NEW COLLECTION")
                    .font(AppTypography.overline)
                    .tracking(3)
                    .foregroundColor(AppColors.accent)

                Text("Spring 2026")
                    .font(AppTypography.displayMedium)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text("Discover the essence of modern luxury")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)

                Spacer().frame(height: AppSpacing.xs)

                HStack(spacing: AppSpacing.xs) {
                    Text("Explore")
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "arrow.right")
                        .font(AppTypography.chevron)
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.lg)

            // Decorative diamond
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "diamond.fill")
                        .font(AppTypography.iconDecorative)
                        .foregroundColor(AppColors.accent.opacity(0.08))
                        .padding(.trailing, AppSpacing.xl)
                }
                .padding(.top, AppSpacing.xl)
                Spacer()
            }
            .frame(height: 220)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge))
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Categories Strip

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Categories", action: "See All")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(categories) { category in
                        NavigationLink(destination: CategoryDetailView(category: category)) {
                            categoryChip(category)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    private func categoryChip(_ category: Category) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle()
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 64, height: 64)

                Image(systemName: category.icon)
                    .font(AppTypography.categoryCircleIcon)
                    .foregroundColor(AppColors.accent)
            }

            Text(category.name)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
    }

    // MARK: - Featured Products

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Featured", action: "View All")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(featuredProducts) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            productCard(product)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    // MARK: - New Arrivals

    private var newArrivalsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "New Arrivals", action: "View All")

            VStack(spacing: AppSpacing.md) {
                ForEach(Array(allProducts.prefix(4))) { product in
                    NavigationLink(destination: ProductDetailView(product: product)) {
                        productRow(product)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, action: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.heading2)
                .foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            Button(action: {}) {
                HStack(spacing: 4) {
                    Text(action)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.right")
                        .font(AppTypography.iconCompact)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func productCard(_ product: Product) -> some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: 0) {
                // Image placeholder
                ZStack {
                    AppColors.backgroundSecondary
                        .frame(width: 180, height: 200)

                    Image(systemName: product.imageName)
                        .font(AppTypography.iconProductLarge)
                        .foregroundColor(AppColors.neutral600)

                    if product.isLimitedEdition {
                        VStack {
                            HStack {
                                Spacer()
                                Text("LIMITED")
                                    .font(AppTypography.overline)
                                    .tracking(1)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.accent)
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }

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
                .padding(AppSpacing.cardPadding)
            }
            .frame(width: 180)
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 80, height: 80)

                Image(systemName: product.imageName)
                    .font(AppTypography.iconProductSmall)
                    .foregroundColor(AppColors.neutral600)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(product.brand.uppercased())
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(AppColors.accent)

                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text(product.formattedPrice)
                    .font(AppTypography.priceSmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.chevron)
                .foregroundColor(AppColors.neutral600)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
