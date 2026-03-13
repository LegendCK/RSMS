//
//  AdminDashboardView.swift
//  infosys2
//
//  Corporate Admin enterprise command center.
//  KPI metrics, system health, alerts, quick actions, activity feed.
//  Profile/Settings accessible from nav bar avatar — not a separate tab.
//

import SwiftUI
import SwiftData

struct AdminDashboardView: View {
    @Environment(AppState.self) var appState
    @Query private var allProducts: [Product]
    @Query private var allUsers: [User]
    @Query private var allCategories: [Category]
    @State private var showProfile = false

    // MARK: - Computed Metrics

    private var staffCount: Int { allUsers.filter { $0.role != .customer }.count }
    private var lowStockCount: Int { allProducts.filter { $0.stockCount <= 3 }.count }
    private var outOfStockCount: Int { allProducts.filter { $0.stockCount == 0 }.count }
    private var limitedCount: Int { allProducts.filter { $0.isLimitedEdition }.count }
    private var totalInventoryUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xxl) {
                        welcomeHeader
                        metricsGrid
                        systemHealthBar
                        alertsSection
                        quickActionsGrid
                        activityFeed
                        Spacer().frame(height: AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("MAISON LUXE")
                            .font(AppTypography.overline)
                            .tracking(3)
                            .foregroundColor(AppColors.accent)
                        Text("Enterprise Console")
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
                                Circle()
                                    .fill(AppColors.backgroundTertiary)
                                    .frame(width: 30, height: 30)
                                Text(adminInitials)
                                    .font(AppTypography.avatarSmall)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                AdminProfileView()
            }
        }
    }

    private var adminInitials: String {
        let parts = appState.currentUserName.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(appState.currentUserName.prefix(2)).uppercased()
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Good \(greeting),")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                Text(appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Admin")
                    .font(AppTypography.displaySmall)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("CORPORATE ADMIN")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Text(Date(), style: .date)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.neutral500)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening"
    }

    // MARK: - Metrics Grid (2x3)

    private var metricsGrid: some View {
        VStack(spacing: AppSpacing.sm) {
            sectionLabel("KEY METRICS")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.sm),
                                GridItem(.flexible(), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                metricCard(icon: "chart.line.uptrend.xyaxis", iconColor: AppColors.accent,
                           value: "$2.4M", label: "Total Revenue", badge: "+12.5%", badgePositive: true)
                metricCard(icon: "shippingbox.fill", iconColor: AppColors.purple,
                           value: "\(allProducts.count)", label: "Active SKUs", badge: "\(allCategories.count) cat.", badgePositive: true)
                metricCard(icon: "person.2.fill", iconColor: AppColors.info,
                           value: "\(allUsers.count)", label: "Total Users", badge: "\(staffCount) staff", badgePositive: true)
                metricCard(icon: "building.2.fill", iconColor: AppColors.success,
                           value: "4", label: "Boutiques", badge: "All live", badgePositive: true)
                metricCard(icon: "exclamationmark.triangle.fill", iconColor: AppColors.warning,
                           value: "\(lowStockCount)", label: "Low Stock", badge: "\(outOfStockCount) out", badgePositive: false)
                metricCard(icon: "cube.box.fill", iconColor: AppColors.purpleLight,
                           value: "\(totalInventoryUnits)", label: "Total Units", badge: "\(limitedCount) limited", badgePositive: true)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func metricCard(icon: String, iconColor: Color, value: String, label: String, badge: String, badgePositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(iconColor)
                Spacer()
                Text(badge)
                    .font(AppTypography.micro)
                    .foregroundColor(badgePositive ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((badgePositive ? AppColors.success : AppColors.warning).opacity(0.12))
                    .cornerRadius(4)
            }
            Text(value)
                .font(AppTypography.heading1)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).stroke(AppColors.border, lineWidth: 0.5))
    }

    // MARK: - System Health

    private var systemHealthBar: some View {
        HStack(spacing: AppSpacing.sm) {
            healthPill(icon: "checkmark.circle.fill", text: "API", color: AppColors.success)
            healthPill(icon: "checkmark.circle.fill", text: "Database", color: AppColors.success)
            healthPill(icon: "checkmark.circle.fill", text: "Payments", color: AppColors.success)
            healthPill(icon: "exclamationmark.circle.fill", text: "Sync", color: AppColors.warning)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func healthPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppTypography.iconCompact)
                .foregroundColor(color)
            Text(text)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(20)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                sectionLabel("ALERTS")
                Spacer()
                Text("3")
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.warning)
                    .cornerRadius(10)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: AppSpacing.xs) {
                alertRow(icon: "exclamationmark.triangle.fill", color: AppColors.error,
                         title: "Critical: Heritage Bag", detail: "Stock at 1 unit — reorder required", time: "12m")
                alertRow(icon: "arrow.triangle.2.circlepath", color: AppColors.warning,
                         title: "Sync Delay", detail: "Paris boutique inventory 3h behind", time: "3h")
                alertRow(icon: "person.badge.plus", color: AppColors.info,
                         title: "Access Request", detail: "Sophia Laurent requests catalog edit", time: "5h")
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func alertRow(icon: String, color: Color, title: String, detail: String, time: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 40)

            Image(systemName: icon)
                .font(AppTypography.alertIcon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)
            }
            Spacer()
            Text(time)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.neutral500)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Quick Actions (2x3 grid)

    private var quickActionsGrid: some View {
        VStack(spacing: AppSpacing.sm) {
            sectionLabel("QUICK ACTIONS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppSpacing.sm) {
                actionTile(icon: "plus.square.fill", label: "Add SKU", color: AppColors.accent)
                actionTile(icon: "person.badge.plus", label: "Add Staff", color: AppColors.purple)
                actionTile(icon: "building.2.fill", label: "Add Store", color: AppColors.info)
                actionTile(icon: "arrow.left.arrow.right", label: "Transfer", color: AppColors.success)
                actionTile(icon: "percent", label: "Promotion", color: AppColors.warning)
                actionTile(icon: "doc.text.fill", label: "Report", color: AppColors.purpleLight)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func actionTile(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(AppTypography.iconAction)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.actionLink)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).stroke(AppColors.border, lineWidth: 0.5))
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                sectionLabel("ACTIVITY")
                Spacer()
                Button(action: {}) {
                    Text("View All")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: 0) {
                activityItem(action: "SKU Created", detail: "Artisan Timepiece — Limited Edition", by: "V. Sterling", time: "10m")
                Divider().background(AppColors.border)
                activityItem(action: "Price Override", detail: "Diamond Pendant — $15,800 → $16,200", by: "V. Sterling", time: "1h")
                Divider().background(AppColors.border)
                activityItem(action: "Staff Provisioned", detail: "Isabella Moreau → Sales Associate", by: "J. Beaumont", time: "3h")
                Divider().background(AppColors.border)
                activityItem(action: "Stock Transfer", detail: "Classic Flap Bag — NYC → Paris (2 units)", by: "D. Park", time: "6h")
            }
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func activityItem(action: String, detail: String, by: String, time: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 5, height: 5)

            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(action)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    Text(time)
                        .font(AppTypography.iconCompact)
                        .foregroundColor(AppColors.neutral500)
                }
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)
                Text(by)
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.purple)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs + 2)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    AdminDashboardView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
