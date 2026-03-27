//
//  CategoriesView.swift
//  RSMS
//
//  Editorial luxury category browser — minimal black/maroon/white aesthetic.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(AppState.self) private var appState
    var showsTabBar: Bool = true
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @State private var selectedGender: GenderFilter = .all

    private var filteredCategories: [Category] {
        guard selectedGender != .all else { return categories }
        return categories.filter { cat in
            let name = cat.name.lowercased()
            return selectedGender.keywords.contains(where: { name.contains($0) })
        }
    }

    var body: some View {
        @Bindable var state = appState

        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Editorial header
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BROWSE")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(4)
                                .foregroundColor(AppColors.accent)
                            Text("Collections")
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        Spacer()
                        Text("\(categories.count) categories")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(AppColors.textSecondaryDark.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Browse Collections, \(categories.count) categories")
                    .accessibilityAddTraits(.isHeader)

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
                                        .foregroundColor(
                                            selectedGender == gender
                                                ? AppColors.textPrimaryLight
                                                : AppColors.textPrimaryDark
                                        )
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            selectedGender == gender
                                                ? AppColors.accent
                                                : AppColors.backgroundSecondary
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().strokeBorder(
                                                selectedGender == gender
                                                    ? AppColors.accent
                                                    : AppColors.border.opacity(0.6),
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("\(gender.rawValue) filter\(selectedGender == gender ? ", selected" : "")")
                                .accessibilityAddTraits(selectedGender == gender ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 14)

                    Rectangle()
                        .fill(AppColors.dividerLight)
                        .frame(height: 1)

                    // Category list — editorial style
                    VStack(spacing: 0) {
                        ForEach(filteredCategories) { category in
                            NavigationLink(destination: ProductListView(categoryFilter: category.name)) {
                                categoryRow(category)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Rectangle()
                                .fill(AppColors.dividerLight)
                                .frame(height: 1)
                                .padding(.leading, 20)
                        }
                    }

                    Spacer().frame(height: 60)
                }
            }
        }
        .toolbar(showsTabBar ? .visible : .hidden, for: .tabBar)
        .navigationDestination(isPresented: $state.showCart) {
            CartView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("CATEGORIES")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(3)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                CartShortcutButton()
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 16) {
            // Icon block
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .fill(AppColors.accent.opacity(0.06))
                    .frame(width: 52, height: 52)
                Image(systemName: sfSymbol(for: category))
                    .font(.system(size: 20, weight: .ultraLight))
                    .foregroundColor(AppColors.accent)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(category.categoryDescription)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .ultraLight))
                .foregroundColor(AppColors.textSecondaryDark.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(AppColors.backgroundPrimary)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name). \(category.categoryDescription)")
        .accessibilityHint("Double tap to browse \(category.name) products")
    }

    private func sfSymbol(for category: Category) -> String {
        let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch name {
        case "accessories":
            return "briefcase.fill"
        case "clothing":
            return "hanger"
        case "handbags":
            return "handbag.fill"
        case "limited edition":
            return "dollarsign.circle.fill"
        case "watches":
            return "applewatch.watchface"
        case "jewelry", "jewellery":
            return "sparkles"
        default:
            return category.icon
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(for: [Category.self, Product.self], inMemory: true)
}
