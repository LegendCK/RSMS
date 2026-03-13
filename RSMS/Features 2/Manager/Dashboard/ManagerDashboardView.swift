//
//  ManagerDashboardView.swift
//  infosys2
//
//  Boutique Manager store command center.
//  Store KPIs, daily sales, top products, staff on duty, alerts, quick actions.
//  Profile/Settings via nav bar avatar (sheet).
//

import SwiftUI
import SwiftData

struct ManagerDashboardView: View {
    @Environment(AppState.self) var appState
    @Query private var allProducts: [Product]
    @Query private var allUsers: [User]
    @State private var showProfile = false

    // Store-scoped metrics (simulated — in production these would filter by store)
    private var storeStaff: [User] {
        allUsers.filter { $0.role == .salesAssociate || $0.role == .inventoryController }
    }
    private var lowStockCount: Int { allProducts.filter { $0.stockCount <= 3 && $0.stockCount > 0 }.count }
    private var outOfStockCount: Int { allProducts.filter { $0.stockCount == 0 }.count }
    private var totalStoreUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xxl) {
                        storeHeader
                        dailySalesStrip
                        kpiGrid
                        alertsSection
                        topProductsSection
                        staffOnDutySection
                        quickActionsGrid
                        Spacer().frame(height: AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("MAISON LUXE")
                            .font(AppTypography.overline).tracking(3)
                            .foregroundColor(AppColors.accent)
                        Text("Fifth Avenue Boutique")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppSpacing.sm) {
                        Button(action: {}) {
                            Image(systemName: "bell.badge")
                                .font(AppTypography.bellIcon)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        Button(action: { showProfile = true }) {
                            ZStack {
                                Circle().fill(AppColors.backgroundTertiary).frame(width: 30, height: 30)
                                Text(managerInitials).font(AppTypography.avatarSmall).foregroundColor(AppColors.purple)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ManagerProfileView()
            }
        }
    }

    private var managerInitials: String {
        let p = appState.currentUserName.split(separator: " ")
        return p.count >= 2 ? "\(p[0].prefix(1))\(p[1].prefix(1))".uppercased() : String(appState.currentUserName.prefix(2)).uppercased()
    }

    // MARK: - Store Header

    private var storeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Good \(greeting),")
                    .font(AppTypography.bodyMedium).foregroundColor(AppColors.textSecondaryDark)
                Text(appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Manager")
                    .font(AppTypography.displaySmall).foregroundColor(AppColors.textPrimaryDark)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("BOUTIQUE MANAGER")
                    .font(AppTypography.overline).tracking(2).foregroundColor(AppColors.purple)
                Text(Date(), style: .date)
                    .font(AppTypography.caption).foregroundColor(AppColors.neutral500)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening"
    }

    // MARK: - Daily Sales Strip

    private var dailySalesStrip: some View {
        VStack(spacing: AppSpacing.sm) {
            sectionLabel("TODAY'S PERFORMANCE")

            HStack(spacing: 0) {
                salesPill(value: "$42,800", label: "Today", icon: "dollarsign.circle.fill", color: AppColors.accent)
                vertDivider
                salesPill(value: "7", label: "Transactions", icon: "creditcard.fill", color: AppColors.purple)
                vertDivider
                salesPill(value: "$6,114", label: "Avg. Ticket", icon: "chart.line.uptrend.xyaxis", color: AppColors.success)
            }
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusLarge)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.accent.opacity(0.2), lineWidth: 0.5))
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func salesPill(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(AppTypography.alertIcon).foregroundColor(color)
            Text(value).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
    }

    private var vertDivider: some View {
        Rectangle().fill(AppColors.border).frame(width: 0.5, height: 40)
    }

    // MARK: - KPI Grid

    private var kpiGrid: some View {
        VStack(spacing: AppSpacing.sm) {
            sectionLabel("STORE OVERVIEW")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.sm),
                                GridItem(.flexible(), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                kpiCard(icon: "chart.bar.fill", iconColor: AppColors.accent,
                        value: "$248K", label: "MTD Revenue", badge: "+8.2%", positive: true)
                kpiCard(icon: "person.2.fill", iconColor: AppColors.purple,
                        value: "\(storeStaff.count)", label: "Staff On Duty", badge: "of \(storeStaff.count + 1)", positive: true)
                kpiCard(icon: "shippingbox.fill", iconColor: AppColors.info,
                        value: "\(totalStoreUnits)", label: "Store Units", badge: "\(allProducts.count) SKUs", positive: true)
                kpiCard(icon: "exclamationmark.triangle.fill", iconColor: AppColors.warning,
                        value: "\(lowStockCount)", label: "Low Stock", badge: "\(outOfStockCount) out", positive: false)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func kpiCard(icon: String, iconColor: Color, value: String, label: String, badge: String, positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: icon).font(AppTypography.iconSmall).foregroundColor(iconColor)
                Spacer()
                Text(badge).font(AppTypography.micro)
                    .foregroundColor(positive ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((positive ? AppColors.success : AppColors.warning).opacity(0.12))
                    .cornerRadius(4)
            }
            Text(value).font(AppTypography.heading1).foregroundColor(AppColors.textPrimaryDark)
            Text(label).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).stroke(AppColors.border, lineWidth: 0.5))
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                sectionLabel("ALERTS")
                Spacer()
                Text("3").font(AppTypography.trendBadge).foregroundColor(AppColors.primary)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(AppColors.warning).cornerRadius(10)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: AppSpacing.xs) {
                alertRow(icon: "exclamationmark.triangle.fill", color: AppColors.error,
                         title: "Heritage Bag — 1 unit", detail: "Reorder or request transfer", time: "15m")
                alertRow(icon: "doc.text.fill", color: AppColors.warning,
                         title: "Inventory Discrepancy", detail: "Pearl Earrings: system 6, counted 5", time: "2h")
                alertRow(icon: "calendar.badge.clock", color: AppColors.info,
                         title: "VIP Appointment", detail: "Mrs. Chen — 3:00 PM private viewing", time: "in 2h")
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func alertRow(icon: String, color: Color, title: String, detail: String, time: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3, height: 40)
            Image(systemName: icon).font(AppTypography.alertIcon).foregroundColor(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
                Text(detail).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark).lineLimit(1)
            }
            Spacer()
            Text(time).font(AppTypography.micro).foregroundColor(AppColors.neutral500)
        }
        .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Top Products

    private var topProductsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                sectionLabel("TOP SELLERS TODAY")
                Spacer()
                Button(action: {}) {
                    Text("View All").font(AppTypography.caption).foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Array(allProducts.sorted { $0.price > $1.price }.prefix(5)), id: \.id) { product in
                        topProductCard(product)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    private func topProductCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).fill(AppColors.backgroundTertiary)
                    .frame(width: 120, height: 90)
                Image(systemName: product.imageName).font(AppTypography.topProductIcon).foregroundColor(AppColors.neutral600)
            }
            Text(product.name).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
            Text(product.formattedPrice).font(AppTypography.avatarSmall).foregroundColor(AppColors.accent)
        }
        .frame(width: 120)
    }

    // MARK: - Staff On Duty

    private var staffOnDutySection: some View {
        VStack(spacing: AppSpacing.sm) {
            sectionLabel("STAFF ON DUTY")

            HStack(spacing: AppSpacing.sm) {
                ForEach(storeStaff.prefix(4)) { user in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(staffColor(user.role).opacity(0.15)).frame(width: 44, height: 44)
                            Text(staffInitials(user.name)).font(AppTypography.avatarMedium).foregroundColor(staffColor(user.role))
                        }
                        Text(user.name.split(separator: " ").first.map(String.init) ?? "").font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
                        Text(user.role == .salesAssociate ? "Sales" : "Inv.")
                            .font(AppTypography.nano).foregroundColor(staffColor(user.role))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func staffColor(_ role: UserRole) -> Color {
        switch role {
        case .salesAssociate: return AppColors.info
        case .inventoryController: return AppColors.success
        default: return AppColors.neutral400
        }
    }

    private func staffInitials(_ name: String) -> String {
        let p = name.split(separator: " ")
        return p.count >= 2 ? "\(p[0].prefix(1))\(p[1].prefix(1))".uppercased() : String(name.prefix(2)).uppercased()
    }

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        VStack(spacing: AppSpacing.sm) {
            sectionLabel("QUICK ACTIONS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                actionTile(icon: "checkmark.circle.fill", label: "Approve", color: AppColors.success)
                actionTile(icon: "arrow.left.arrow.right", label: "Transfer", color: AppColors.info)
                actionTile(icon: "calendar.badge.plus", label: "VIP Event", color: AppColors.purple)
                actionTile(icon: "person.badge.clock", label: "Shift", color: AppColors.accent)
                actionTile(icon: "doc.text.fill", label: "Report", color: AppColors.warning)
                actionTile(icon: "exclamationmark.bubble.fill", label: "Flag Item", color: AppColors.error)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func actionTile(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon).font(AppTypography.iconAction).foregroundColor(color)
            Text(label).font(AppTypography.actionLink).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity).frame(height: 72)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).stroke(AppColors.border, lineWidth: 0.5))
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    ManagerDashboardView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
