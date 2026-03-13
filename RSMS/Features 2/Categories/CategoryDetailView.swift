//
//  CategoryDetailView.swift
//  infosys2
//
//  Shows the product types (sub-categories) within a category as a grid.
//  Tapping a type navigates to ProductListView filtered by category + type.
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: Category

    private var productTypes: [String] {
        category.parsedProductTypes
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
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(category.name.uppercased())
                            .font(AppTypography.overline)
                            .tracking(3)
                            .foregroundColor(AppColors.accent)

                        Text(category.categoryDescription)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)

                    // "View All" link
                    NavigationLink(destination: ProductListView(categoryFilter: category.name)) {
                        HStack {
                            Text("View All \(category.name)")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AppTypography.chevron)
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Product types grid
                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(Array(productTypes.enumerated()), id: \.offset) { index, typeName in
                            NavigationLink(destination: ProductListView(categoryFilter: category.name, productTypeFilter: typeName)) {
                                productTypeCard(typeName, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private func productTypeCard(_ typeName: String, index: Int) -> some View {
        let icons = ["sparkles", "circle.hexagongrid.fill", "star.fill", "diamond.fill",
                     "seal.fill", "shield.fill", "crown.fill", "bolt.fill",
                     "leaf.fill", "wand.and.stars"]
        let icon = icons[index % icons.count]

        return LuxuryCardView {
            VStack(spacing: AppSpacing.sm) {
                Spacer().frame(height: AppSpacing.xs)

                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(AppTypography.toolbarIcon)
                        .foregroundColor(AppColors.accent)
                }

                Text(typeName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer().frame(height: AppSpacing.xs)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
        }
    }
}
