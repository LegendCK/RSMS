//
//  InsightsView.swift
//  infosys2
//
//  Enterprise insights — analytics dashboards, reports, compliance & audit.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Analytics").tag(0)
                        Text("Reports").tag(1)
                        Text("Compliance").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: InsightsAnalyticsSubview()
                    case 1: InsightsReportsSubview()
                    case 2: InsightsComplianceSubview()
                    default: InsightsAnalyticsSubview()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Insights")
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
}

// MARK: - Analytics

struct InsightsAnalyticsSubview: View {
    @Query private var allProducts: [Product]
    @State private var selectedPeriod = "This Month"
    private let periods = ["Today", "This Week", "This Month", "This Quarter", "This Year"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xl) {
                // Period
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(periods, id: \.self) { p in
                            Button(action: { selectedPeriod = p }) {
                                Text(p).font(AppTypography.caption)
                                    .foregroundColor(selectedPeriod == p ? AppColors.primary : AppColors.textSecondaryDark)
                                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
                                    .background(selectedPeriod == p ? AppColors.accent : AppColors.backgroundTertiary)
                                    .cornerRadius(AppSpacing.radiusSmall)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Revenue hero
                VStack(spacing: AppSpacing.xs) {
                    Text("$2,412,500")
                        .font(AppTypography.displayLarge)
                        .foregroundColor(AppColors.textPrimaryDark)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right").font(AppTypography.trendArrow).foregroundColor(AppColors.success)
                        Text("+12.5% vs last period").font(AppTypography.caption).foregroundColor(AppColors.success)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusLarge)
                .padding(.horizontal, AppSpacing.screenHorizontal)

                // Revenue bars
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sLabel("REVENUE TREND")
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach([35, 42, 38, 55, 48, 62, 58, 72, 68, 52, 60, 65], id: \.self) { h in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.accent.opacity(h > 50 ? 1.0 : 0.5))
                                .frame(height: CGFloat(h))
                        }
                    }
                    .frame(height: 72)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    HStack {
                        Text("Online").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                        Text("$1.2M (49%)").font(AppTypography.caption).foregroundColor(AppColors.accent)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    HStack {
                        Text("In-Store").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                        Text("$980K (41%)").font(AppTypography.caption).foregroundColor(AppColors.purple)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    HStack {
                        Text("Private Sales").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                        Text("$232K (10%)").font(AppTypography.caption).foregroundColor(AppColors.info)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Category bars
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sLabel("CATEGORY PERFORMANCE")
                    catBar(name: "Watches", value: "$890K", pct: 0.37, color: AppColors.accent)
                    catBar(name: "Jewelry", value: "$680K", pct: 0.28, color: AppColors.purple)
                    catBar(name: "Handbags", value: "$520K", pct: 0.22, color: AppColors.info)
                    catBar(name: "Accessories", value: "$190K", pct: 0.08, color: AppColors.success)
                    catBar(name: "Limited Ed.", value: "$132K", pct: 0.05, color: AppColors.warning)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)

                // Top products
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sLabel("TOP SKUs BY REVENUE")
                    ForEach(Array(allProducts.sorted { $0.price > $1.price }.prefix(5).enumerated()), id: \.element.id) { idx, p in
                        HStack(spacing: AppSpacing.sm) {
                            Text("#\(idx + 1)").font(AppTypography.label).foregroundColor(AppColors.accent).frame(width: 24)
                            Text(p.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
                            Spacer()
                            Text(p.formattedPrice).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                        }
                        .padding(.vertical, AppSpacing.xxs)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func catBar(name: String, value: String, pct: CGFloat, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack { Text(name).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark); Spacer(); Text(value).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark) }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppColors.backgroundTertiary).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: g.size.width * pct, height: 6)
                }
            }.frame(height: 6)
        }
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
    }
}

// MARK: - Reports

struct InsightsReportsSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xs) {
                reportRow(icon: "chart.bar.doc.horizontal", title: "Sales Report", sub: "Transaction history & breakdowns", color: AppColors.accent)
                reportRow(icon: "person.2.fill", title: "Staff Performance", sub: "Employee sales metrics & rankings", color: AppColors.purple)
                reportRow(icon: "shippingbox.fill", title: "Inventory Report", sub: "Stock levels, turnover & aging", color: AppColors.success)
                reportRow(icon: "building.2.fill", title: "Boutique Comparison", sub: "Cross-location revenue & KPIs", color: AppColors.info)
                reportRow(icon: "creditcard.fill", title: "Financial Summary", sub: "Revenue, costs, margins", color: AppColors.accent)
                reportRow(icon: "chart.pie.fill", title: "Product Mix Analysis", sub: "Category contribution & trends", color: AppColors.warning)
                reportRow(icon: "person.crop.circle.fill", title: "Customer Analytics", sub: "Segments, lifetime value, retention", color: AppColors.purpleLight)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func reportRow(icon: String, title: String, sub: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall).fill(color.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).font(AppTypography.iconMedium).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Text(sub).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            Image(systemName: "chevron.right").font(AppTypography.chevron).foregroundColor(AppColors.neutral600)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

// MARK: - Compliance & Audit

struct InsightsComplianceSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                // Status
                VStack(spacing: AppSpacing.sm) {
                    Text("COMPLIANCE STATUS").font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: AppSpacing.md) {
                        complianceStat(value: "Passed", label: "Last Audit", color: AppColors.success)
                        complianceStat(value: "98.5%", label: "Score", color: AppColors.accent)
                        complianceStat(value: "Apr 15", label: "Next Audit", color: AppColors.info)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)

                // Checks
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("AUDIT CHECKS").font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    VStack(spacing: AppSpacing.xs) {
                        auditRow(check: "Access Control Verification", status: "Passed", color: AppColors.success)
                        auditRow(check: "Data Encryption Standards", status: "Passed", color: AppColors.success)
                        auditRow(check: "Password Policy Compliance", status: "Passed", color: AppColors.success)
                        auditRow(check: "Inventory Reconciliation", status: "Review", color: AppColors.warning)
                        auditRow(check: "Financial Reporting Accuracy", status: "Passed", color: AppColors.success)
                        auditRow(check: "PCI-DSS Compliance", status: "Passed", color: AppColors.success)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Access logs
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("RECENT ACCESS LOGS").font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    VStack(spacing: AppSpacing.xs) {
                        logRow(user: "Victoria Sterling", action: "Login", ip: "192.168.1.1", time: "2m ago")
                        logRow(user: "James Beaumont", action: "User Edit", ip: "192.168.1.45", time: "1h ago")
                        logRow(user: "Sophia Laurent", action: "Report Export", ip: "10.0.0.12", time: "3h ago")
                        logRow(user: "Daniel Park", action: "Inventory Update", ip: "192.168.2.10", time: "5h ago")
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func complianceStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(AppTypography.heading3).foregroundColor(color)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func auditRow(check: String, status: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: status == "Passed" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(AppTypography.complianceIcon).foregroundColor(color)
            Text(check).font(AppTypography.bodySmall).foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            Text(status.uppercased()).font(AppTypography.nano).foregroundColor(color)
                .padding(.horizontal, 8).padding(.vertical, 3).background(color.opacity(0.12)).cornerRadius(4)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func logRow(user: String, action: String, ip: String, time: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text(user).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                HStack(spacing: 4) {
                    Text(action).font(AppTypography.caption).foregroundColor(AppColors.purple)
                    Text("•").foregroundColor(AppColors.neutral600)
                    Text(ip).font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                }
            }
            Spacer()
            Text(time).font(AppTypography.iconCompact).foregroundColor(AppColors.neutral500)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
