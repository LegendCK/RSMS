//
//  SACatalogFilterSheet.swift
//  RSMS
//
//  Filter sheet for the Sales Associate catalog.
//

import SwiftUI

struct SACatalogFilterSheet: View {
    let vm: SACatalogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // Availability
                        filterSection("AVAILABILITY") {
                            VStack(spacing: 0) {
                                ForEach(SACatalogViewModel.AvailabilityFilter.allCases) { option in
                                    Button {
                                        vm.availabilityFilter = option
                                    } label: {
                                        HStack {
                                            Text(option.rawValue)
                                                .font(AppTypography.bodyMedium)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Spacer()
                                            if vm.availabilityFilter == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(AppColors.accent)
                                            }
                                        }
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, AppSpacing.sm)
                                    }
                                    .buttonStyle(.plain)

                                    if option != SACatalogViewModel.AvailabilityFilter.allCases.last {
                                        Divider().padding(.leading, AppSpacing.md)
                                    }
                                }
                            }
                            .background(AppColors.backgroundSecondary)
                            .cornerRadius(AppSpacing.radiusMedium)
                        }

                        // Price Range
                        filterSection("PRICE RANGE") {
                            HStack(spacing: AppSpacing.md) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Min")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                    TextField("0", text: Binding(
                                        get: { vm.minPriceText },
                                        set: { vm.minPriceText = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .font(AppTypography.bodyMedium)
                                    .padding(AppSpacing.sm)
                                    .background(AppColors.backgroundSecondary)
                                    .cornerRadius(AppSpacing.radiusSmall)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Max")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                    TextField("∞", text: Binding(
                                        get: { vm.maxPriceText },
                                        set: { vm.maxPriceText = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .font(AppTypography.bodyMedium)
                                    .padding(AppSpacing.sm)
                                    .background(AppColors.backgroundSecondary)
                                    .cornerRadius(AppSpacing.radiusSmall)
                                }
                            }
                        }

                        // Sort
                        filterSection("SORT BY") {
                            VStack(spacing: 0) {
                                ForEach(SACatalogViewModel.SortOption.allCases) { option in
                                    Button {
                                        vm.sortOption = option
                                    } label: {
                                        HStack {
                                            Text(option.rawValue)
                                                .font(AppTypography.bodyMedium)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Spacer()
                                            if vm.sortOption == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(AppColors.accent)
                                            }
                                        }
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, AppSpacing.sm)
                                    }
                                    .buttonStyle(.plain)

                                    if option != SACatalogViewModel.SortOption.allCases.last {
                                        Divider().padding(.leading, AppSpacing.md)
                                    }
                                }
                            }
                            .background(AppColors.backgroundSecondary)
                            .cornerRadius(AppSpacing.radiusMedium)
                        }

                        // Clear All
                        if vm.activeFilterCount > 0 {
                            Button {
                                vm.clearFilters()
                                dismiss()
                            } label: {
                                Text("Clear All Filters")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.error)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(AppColors.error.opacity(0.08))
                                    .cornerRadius(AppSpacing.radiusMedium)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer().frame(height: AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FILTERS")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }

    @ViewBuilder
    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
            content()
        }
    }
}
