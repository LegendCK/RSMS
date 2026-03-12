//
//  ManagerInsightsView.swift
//  infosys2
//
//  Boutique Manager insights — store analytics, product performance, staff productivity, revenue trends.
//  Store-scoped: data for this boutique only.
//

import SwiftUI
import SwiftData

struct ManagerInsightsView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Revenue").tag(0)
                        Text("Products").tag(1)
                        Text("Staff").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: MgrRevenueSubview()
                    case 1: MgrProductInsightsSubview()
                    case 2: MgrStaffInsightsSubview()
                    default: MgrRevenueSubview()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Insights").font(AppTypography.navTitle).foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up").font(AppTypography.bellIcon).foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Revenue

struct MgrRevenueSubview: View {
    @State private var period = "This Month"
    private let periods = ["Today", "This Week", "This Month"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xl) {
                // Period
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(periods, id: \.self) { p in
                            Button(action: { period = p }) {
                                Text(p).font(AppTypography.caption)
                                    .foregroundColor(period == p ? AppColors.primary : AppColors.textSecondaryDark)
                                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
                                    .background(period == p ? AppColors.accent : AppColors.backgroundTertiary)
                                    .cornerRadius(AppSpacing.radiusSmall)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Revenue hero
                VStack(spacing: AppSpacing.xs) {
                    Text("$248,600")
                        .font(AppTypography.displayLarge).foregroundColor(AppColors.textPrimaryDark)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right").font(AppTypography.trendArrow).foregroundColor(AppColors.success)
                        Text("+8.2% vs last month").font(AppTypography.caption).foregroundColor(AppColors.success)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.lg)
                .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusLarge)
                .padding(.horizontal, AppSpacing.screenHorizontal)

                // Daily bars
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sLabel("DAILY TREND")
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach([28, 35, 42, 38, 55, 48, 62, 44, 50, 43], id: \.self) { h in
                            RoundedRectangle(cornerRadius: 2).fill(AppColors.accent.opacity(h > 45 ? 1.0 : 0.5))
                                .frame(height: CGFloat(h))
                        }
                    }
                    .frame(height: 62).padding(.horizontal, AppSpacing.screenHorizontal)

                    HStack {
                        Text("Mar 1").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                        Spacer()
                        Text("Mar 10").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Targets
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sLabel("TARGETS")
                    targetRow(label: "Monthly Target", current: "$248K", target: "$300K", pct: 0.83)
                    targetRow(label: "Avg. Ticket Goal", current: "$6,114", target: "$7,000", pct: 0.87)
                    targetRow(label: "Transactions Goal", current: "38", target: "50", pct: 0.76)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func targetRow(label: String, current: String, target: String, pct: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text("\(current) / \(target)").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppColors.backgroundTertiary).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(pct >= 0.8 ? AppColors.success : AppColors.warning)
                        .frame(width: g.size.width * pct, height: 6)
                }
            }.frame(height: 6)
        }
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Product Insights

struct MgrProductInsightsSubview: View {
    @Query(sort: \Product.price, order: .reverse) private var allProducts: [Product]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                sLabel("TOP SELLERS")

                ForEach(Array(allProducts.prefix(5).enumerated()), id: \.element.id) { idx, p in
                    HStack(spacing: AppSpacing.sm) {
                        Text("#\(idx + 1)").font(AppTypography.label).foregroundColor(AppColors.accent).frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
                            Text(p.categoryName).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                        }
                        Spacer()
                        Text(p.formattedPrice).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                sLabel("CATEGORY MIX")

                catBar(name: "Watches", pct: 0.34, color: AppColors.accent)
                catBar(name: "Jewelry", pct: 0.26, color: AppColors.purple)
                catBar(name: "Handbags", pct: 0.22, color: AppColors.info)
                catBar(name: "Accessories", pct: 0.12, color: AppColors.success)
                catBar(name: "Limited Ed.", pct: 0.06, color: AppColors.warning)

                sLabel("SLOW MOVERS")
                ForEach(Array(allProducts.sorted { $0.stockCount > $1.stockCount }.prefix(3)), id: \.id) { p in
                    HStack(spacing: AppSpacing.sm) {
                        Text(p.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
                        Spacer()
                        Text("\(p.stockCount) units").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                        Text("Low demand").font(AppTypography.demandBadge).foregroundColor(AppColors.warning)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(AppColors.warning.opacity(0.12)).cornerRadius(4)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func catBar(name: String, pct: CGFloat, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text("\(Int(pct * 100))%").font(AppTypography.caption).foregroundColor(color)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppColors.backgroundTertiary).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: g.size.width * pct, height: 6)
                }
            }.frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Staff Productivity Insights

struct MgrStaffInsightsSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                sLabel("SALES LEADERBOARD")

                leaderRow(rank: 1, name: "Alexander Chase", metric: "$86,400", sub: "14 transactions", pct: 0.55)
                leaderRow(rank: 2, name: "Isabella Moreau", metric: "$72,100", sub: "11 transactions", pct: 0.45)

                sLabel("CONVERSION RATES")

                convRow(name: "Alexander Chase", rate: "42%", trend: "+3%", positive: true)
                convRow(name: "Isabella Moreau", rate: "38%", trend: "+1%", positive: true)

                sLabel("ATTENDANCE THIS MONTH")

                attendRow(name: "Alexander Chase", present: 8, total: 10, late: 0)
                attendRow(name: "Isabella Moreau", present: 7, total: 10, late: 1)
                attendRow(name: "Daniel Park", present: 9, total: 10, late: 0)
                attendRow(name: "Marcus Webb", present: 5, total: 6, late: 0)
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func leaderRow(rank: Int, name: String, metric: String, sub: String, pct: CGFloat) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text("#\(rank)").font(AppTypography.heading2).foregroundColor(AppColors.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Text(sub).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            Text(metric).font(AppTypography.heading3).foregroundColor(AppColors.accent)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func convRow(name: String, rate: String, trend: String, positive: Bool) -> some View {
        HStack {
            Text(name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            Text(rate).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
            Text(trend).font(AppTypography.trendBadge).foregroundColor(positive ? AppColors.success : AppColors.error)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background((positive ? AppColors.success : AppColors.error).opacity(0.12)).cornerRadius(4)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func attendRow(name: String, present: Int, total: Int, late: Int) -> some View {
        HStack {
            Text(name).font(AppTypography.bodySmall).foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            Text("\(present)/\(total) days").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            if late > 0 {
                Text("\(late) late").font(AppTypography.demandBadge).foregroundColor(AppColors.warning)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(AppColors.warning.opacity(0.12)).cornerRadius(4)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    ManagerInsightsView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
