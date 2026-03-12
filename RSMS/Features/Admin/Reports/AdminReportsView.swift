//
//  AdminReportsView.swift
//  infosys2
//
//  Corporate Admin reports & analytics — sales, compliance, business intelligence.
//

import SwiftUI
import SwiftData

struct AdminReportsView: View {
    @Query private var allProducts: [Product]
    @State private var selectedPeriod = "This Month"

    private let periods = ["Today", "This Week", "This Month", "This Quarter", "This Year"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        // Period selector
                        periodSelector

                        // Revenue overview
                        revenueSection

                        // Top Products
                        topProductsSection

                        // Category performance
                        categoryPerformanceSection

                        // Quick reports
                        quickReportsSection

                        Spacer().frame(height: AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Reports")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                            .font(AppTypography.iconMedium)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(periods, id: \.self) { period in
                    Button(action: { selectedPeriod = period }) {
                        Text(period)
                            .font(AppTypography.caption)
                            .foregroundColor(selectedPeriod == period ? AppColors.primary : AppColors.textSecondaryDark)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(selectedPeriod == period ? AppColors.accent : AppColors.backgroundTertiary)
                            .cornerRadius(AppSpacing.radiusSmall)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Revenue

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("REVENUE")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: AppSpacing.md) {
                // Main revenue number
                VStack(spacing: AppSpacing.xxs) {
                    Text("$2,412,500")
                        .font(AppTypography.displayLarge)
                        .foregroundColor(AppColors.textPrimaryDark)
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "arrow.up.right")
                            .font(AppTypography.trendArrow)
                            .foregroundColor(AppColors.success)
                        Text("+12.5% vs last period")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.success)
                    }
                }

                // Revenue bar (visual placeholder)
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < 9 ? AppColors.accent : AppColors.accent.opacity(0.3))
                            .frame(height: CGFloat([35, 42, 38, 55, 48, 62, 58, 72, 68, 45, 50, 55][i]))
                    }
                }
                .frame(height: 72)

                // Breakdown
                HStack(spacing: AppSpacing.md) {
                    revenueBreakdown(label: "Online", value: "$1.2M", percent: "49%")
                    revenueBreakdown(label: "In-Store", value: "$980K", percent: "41%")
                    revenueBreakdown(label: "Private", value: "$232K", percent: "10%")
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusLarge)
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func revenueBreakdown(label: String, value: String, percent: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Text(percent)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Products

    private var topProductsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("TOP PERFORMING PRODUCTS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: AppSpacing.xs) {
                ForEach(Array(allProducts.sorted { $0.price > $1.price }.prefix(5).enumerated()), id: \.element.id) { index, product in
                    HStack(spacing: AppSpacing.md) {
                        Text("#\(index + 1)")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .lineLimit(1)
                            Text(product.categoryName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }

                        Spacer()

                        Text(product.formattedPrice)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusMedium)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    // MARK: - Category Performance

    private var categoryPerformanceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("CATEGORY PERFORMANCE")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: AppSpacing.xs) {
                categoryBar(name: "Watches", value: "$890K", percent: 0.37, color: AppColors.accent)
                categoryBar(name: "Jewelry", value: "$680K", percent: 0.28, color: AppColors.purple)
                categoryBar(name: "Handbags", value: "$520K", percent: 0.22, color: AppColors.info)
                categoryBar(name: "Accessories", value: "$190K", percent: 0.08, color: AppColors.success)
                categoryBar(name: "Limited Ed.", value: "$132K", percent: 0.05, color: AppColors.warning)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func categoryBar(name: String, value: String, percent: CGFloat, color: Color) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            HStack {
                Text(name)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text(value)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.backgroundTertiary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * percent, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    // MARK: - Quick Reports

    private var quickReportsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("QUICK REPORTS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: AppSpacing.xs) {
                reportLink(icon: "chart.bar.doc.horizontal", title: "Sales Report", subtitle: "Detailed transaction history")
                reportLink(icon: "checkmark.shield", title: "Compliance Report", subtitle: "Regulatory & audit status")
                reportLink(icon: "person.2.fill", title: "Staff Performance", subtitle: "Employee sales metrics")
                reportLink(icon: "shippingbox.fill", title: "Inventory Report", subtitle: "Stock levels & turnover")
                reportLink(icon: "building.2.fill", title: "Boutique Comparison", subtitle: "Cross-location analytics")
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func reportLink(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                    .fill(AppColors.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(AppTypography.iconMedium)
                    .foregroundColor(AppColors.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.chevron)
                .foregroundColor(AppColors.neutral600)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

#Preview {
    AdminReportsView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
