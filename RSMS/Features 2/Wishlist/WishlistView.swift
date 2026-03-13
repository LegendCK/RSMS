//
//  WishlistView.swift
//  infosys2
//
//  Displays products the user has wishlisted.
//

import SwiftUI
import SwiftData

struct WishlistView: View {
    @Query(filter: #Predicate<Product> { $0.isWishlisted == true })
    private var wishlistProducts: [Product]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                if wishlistProducts.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.md) {
                            // Header
                            HStack {
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text("YOUR WISHLIST")
                                        .font(AppTypography.overline)
                                        .tracking(3)
                                        .foregroundColor(AppColors.accent)

                                    Text("\(wishlistProducts.count) \(wishlistProducts.count == 1 ? "item" : "items")")
                                        .font(AppTypography.bodySmall)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .padding(.top, AppSpacing.md)

                            // Wishlist items
                            ForEach(wishlistProducts) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    wishlistRow(product)
                                }
                            }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Wishlist")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .stroke(AppColors.purple.opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)

                Image(systemName: "heart")
                    .font(AppTypography.emptyStateIcon)
                    .foregroundColor(AppColors.accent.opacity(0.5))
            }

            VStack(spacing: AppSpacing.xs) {
                Text("Your Wishlist is Empty")
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text("Save pieces you love to revisit them later")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Wishlist Row

    private func wishlistRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Image
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 90, height: 90)

                Image(systemName: product.imageName)
                    .font(AppTypography.iconCategory)
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

                // Stock status
                HStack(spacing: 4) {
                    Circle()
                        .fill(product.stockCount > 0 ? AppColors.success : AppColors.error)
                        .frame(width: 5, height: 5)
                    Text(product.stockCount > 0 ? "In Stock" : "Out of Stock")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            Spacer()

            // Remove from wishlist
            Button(action: {
                withAnimation {
                    product.isWishlisted = false
                    try? modelContext.save()
                }
            }) {
                Image(systemName: "heart.fill")
                    .font(AppTypography.heartIcon)
                    .foregroundColor(AppColors.error)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

#Preview {
    WishlistView()
        .modelContainer(for: Product.self, inMemory: true)
}
