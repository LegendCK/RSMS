//
//  CategoriesView.swift
//  RSMS
//
//  Grid display of product categories — premium iOS native design.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Query(sort: \Category.displayOrder) private var categories: [Category]

    // Unified brand accent color for all cards
    private var cardAccent: Color { AppColors.accent }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BROWSE")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.accent)

                            Text("Collections")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color.primary)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(categories) { category in
                                NavigationLink(destination: CategoryDetailView(category: category)) {
                                    categoryCard(category, accent: cardAccent)
                                }
                                .buttonStyle(PlainButtonStyle())
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
                        .foregroundColor(Color.primary)
                }
            }
        }
    }

    private func categoryCard(_ category: Category, accent: Color) -> some View {
        VStack(spacing: 0) {
            // Tinted top band with icon
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(accent.opacity(0.10))
                    .frame(height: 110)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Circle()
                            .strokeBorder(accent.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 60, height: 60)
                        Image(systemName: category.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accent.opacity(0.6))
                }

                Text(category.categoryDescription)
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(accent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.1), radius: 10, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    CategoriesView()
        .modelContainer(for: [Category.self, Product.self], inMemory: true)
}
