//
//  AssistedSellingView.swift
//  infosys2
//
//  Sales Associate assisted selling — product search, curated carts, AI recommendations, POS.
//

import SwiftUI
import SwiftData

struct AssistedSellingView: View {
    @State private var searchText = ""
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Products").tag(0)
                        Text("Sale Basket").tag(1)
                        Text("Look Builder").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondaryDark)
                        TextField("Search by name, SKU, or serial...", text: $searchText)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(AppColors.accent)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusSmall)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    Spacer()

                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "bag.fill")
                            .font(AppTypography.emptyStateIcon)
                            .foregroundColor(AppColors.accent.opacity(0.5))
                        Text("Search products to start a sale")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text("Use AI recommendations to cross-sell and up-sell")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark.opacity(0.7))
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ASSISTED SELLING")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}
