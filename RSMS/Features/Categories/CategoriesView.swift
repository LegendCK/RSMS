//
//  CategoriesView.swift
//  infosys2
//
//  Grid display of product categories.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Query(sort: \Category.displayOrder) private var categories: [Category]

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        // Header
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("BROWSE")
                                .font(AppTypography.overline)
                                .tracking(3)
                                .foregroundColor(AppColors.accent)

                            Text("Collections")
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)

                        // Category grid
                        LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                            ForEach(categories) { category in
                                NavigationLink(destination: CategoryDetailView(category: category)) {
                                    categoryCard(category)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                    .padding(.bottom, AppSpacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Categories")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }

    private func categoryCard(_ category: Category) -> some View {
        LuxuryCardView {
            VStack(spacing: AppSpacing.md) {
                Spacer()
                    .frame(height: AppSpacing.sm)

                // Icon
                ZStack {
                    Circle()
                        .stroke(AppColors.purple.opacity(0.15), lineWidth: 1)
                        .frame(width: 85, height: 85)

                    Circle()
                        .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                        .frame(width: 70, height: 70)

                    Image(systemName: category.icon)
                        .font(AppTypography.iconCategory)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accent, AppColors.accentLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: AppSpacing.xxs) {
                    Text(category.name)
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)

                    Text(category.categoryDescription)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, AppSpacing.sm)

                Spacer()
                    .frame(height: AppSpacing.sm)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
        }
    }
}

#Preview {
    CategoriesView()
        .modelContainer(for: [Category.self, Product.self], inMemory: true)
}
