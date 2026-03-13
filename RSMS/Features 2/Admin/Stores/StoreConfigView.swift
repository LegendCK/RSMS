//
//  StoreConfigView.swift
//  infosys2
//
//  Corporate Admin store configuration — boutique locations, distribution centers.
//

import SwiftUI

struct StoreConfigView: View {
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segment picker
                    Picker("", selection: $selectedSegment) {
                        Text("Boutiques").tag(0)
                        Text("Distribution").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)

                    if selectedSegment == 0 {
                        boutiquesList
                    } else {
                        distributionList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Stores")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }

    // MARK: - Boutiques

    private var boutiquesList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                // Stats
                HStack(spacing: AppSpacing.md) {
                    miniStat(value: "4", label: "Active", color: AppColors.success)
                    miniStat(value: "1", label: "Planned", color: AppColors.info)
                    miniStat(value: "$2.4M", label: "Revenue", color: AppColors.accent)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)

                // Boutique cards
                boutiqueCard(
                    name: "Maison Luxe — Fifth Avenue",
                    location: "New York, NY",
                    manager: "James Beaumont",
                    status: "Operational",
                    revenue: "$890K",
                    staff: 12
                )
                boutiqueCard(
                    name: "Maison Luxe — Rodeo Drive",
                    location: "Beverly Hills, CA",
                    manager: "Sophia Laurent",
                    status: "Operational",
                    revenue: "$720K",
                    staff: 9
                )
                boutiqueCard(
                    name: "Maison Luxe — Champs-Élysées",
                    location: "Paris, France",
                    manager: "—",
                    status: "Operational",
                    revenue: "$540K",
                    staff: 8
                )
                boutiqueCard(
                    name: "Maison Luxe — Ginza",
                    location: "Tokyo, Japan",
                    manager: "—",
                    status: "Operational",
                    revenue: "$250K",
                    staff: 6
                )
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func boutiqueCard(name: String, location: String, manager: String, status: String, revenue: String, staff: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(location)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(status)
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(AppColors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.success.opacity(0.15))
                    .cornerRadius(4)
            }

            GoldDivider(opacity: 0.15)

            HStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Manager")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(manager)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revenue")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(revenue)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Staff")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("\(staff)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Distribution Centers

    private var distributionList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    miniStat(value: "2", label: "Active", color: AppColors.success)
                    miniStat(value: "48K", label: "Units", color: AppColors.accent)
                    miniStat(value: "99.2%", label: "Fulfillment", color: AppColors.info)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)

                distributionCard(
                    name: "East Coast Hub",
                    location: "Newark, NJ",
                    capacity: "25,000 units",
                    utilization: "72%"
                )
                distributionCard(
                    name: "European Hub",
                    location: "Milan, Italy",
                    capacity: "18,000 units",
                    utilization: "65%"
                )
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func distributionCard(name: String, location: String, capacity: String, utilization: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                    .fill(AppColors.info.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "building.2.fill")
                    .font(AppTypography.catalogIcon)
                    .foregroundColor(AppColors.info)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(location)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(capacity)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(utilization + " used")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Helper

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.heading2)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

#Preview {
    StoreConfigView()
}
