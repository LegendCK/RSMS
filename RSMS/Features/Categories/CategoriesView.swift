//
//  CategoriesView.swift
//  RSMS
//
//  Editorial luxury category browser — minimal black/maroon/white aesthetic.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
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
        ZStack {
            Color.white.ignoresSafeArea()

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
                                .foregroundColor(.black)
                        }
                        Spacer()
                        Text("\(categories.count) categories")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(.black.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 28)

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
                    .padding(.bottom, 14)

                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 1)

                    // Category list — editorial style
                    VStack(spacing: 0) {
                        ForEach(filteredCategories) { category in
                            NavigationLink(destination: ProductListView(categoryFilter: category.name)) {
                                categoryRow(category)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, 20)
                        }
                    }

                    Spacer().frame(height: 60)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("CATEGORIES")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(3)
                    .foregroundColor(.black)
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
                Rectangle()
                    .fill(AppColors.accent.opacity(0.06))
                    .frame(width: 52, height: 52)
                Image(systemName: category.icon)
                    .font(.system(size: 20, weight: .ultraLight))
                    .foregroundColor(AppColors.accent)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(category.categoryDescription)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.black.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .ultraLight))
                .foregroundColor(.black.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.white)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(for: [Category.self, Product.self], inMemory: true)
}
