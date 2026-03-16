//
//  CategoryDetailView.swift
//  RSMS
//
//  Shows sub-categories within a category as a grid.
//  Tapping a type navigates to ProductListView filtered by category + type.
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: Category

    // Sub-type icons cycling array
    private let icons = [
        "sparkles", "circle.hexagongrid.fill", "star.fill", "diamond.fill",
        "seal.fill", "shield.fill", "crown.fill", "bolt.fill",
        "leaf.fill", "wand.and.stars"
    ]

    private var productTypes: [String] { category.parsedProductTypes }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Description header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.categoryDescription)
                            .font(.system(size: 15))
                            .foregroundColor(Color.secondary)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, 8)

                    // View All banner
                    NavigationLink(destination: ProductListView(categoryFilter: category.name)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.accent.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }

                            Text("View All \(category.name)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.accent)

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.accent.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.accent.opacity(0.06))
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(AppColors.accent.opacity(0.18), lineWidth: 1)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Product types grid
                    if !productTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SHOP BY TYPE")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, AppSpacing.screenHorizontal)

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(Array(productTypes.enumerated()), id: \.offset) { index, typeName in
                                    NavigationLink(destination: ProductListView(categoryFilter: category.name, productTypeFilter: typeName)) {
                                        productTypeCard(typeName, icon: icons[index % icons.count])
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }
                    }
                }
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartShortcutButton()
            }
        }
    }

    private func productTypeCard(_ typeName: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }

            Text(typeName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
