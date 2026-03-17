//
//  ManagerDashboardView.swift
//  RSMS
//
//  Boutique Manager store command center.
//  Maroon gradient header, KPIs, alerts, top sellers, staff, quick actions.
//

import SwiftUI
import SwiftData

struct ManagerDashboardView: View {
    @Environment(AppState.self) var appState
    @Query private var allProducts: [Product]
    @Query private var allUsers: [User]
    @State private var showProfile = false

    private var storeStaff: [User] {
        allUsers.filter { $0.role == .salesAssociate || $0.role == .inventoryController }
    }
    private var lowStockCount: Int { allProducts.filter { $0.stockCount <= 3 && $0.stockCount > 0 }.count }
    private var outOfStockCount: Int { allProducts.filter { $0.stockCount == 0 }.count }
    private var totalStoreUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                // Maroon top glow
                LinearGradient(
                    colors: [AppColors.accent.opacity(0.13), Color.clear],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.22)
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        storeHeader
                        dailySalesStrip
                        kpiGrid
                        alertsSection
                        topProductsSection
                        staffOnDutySection
                        quickActionsGrid
                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MAISON LUXE")
                        .font(.system(size: 12, weight: .black))
                        .tracking(4)
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button(action: {}) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.primary)
                        }
                        Button(action: { showProfile = true }) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.accent.opacity(0.12))
                                    .frame(width: 30, height: 30)
                                Text(managerInitials)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) { ManagerProfileView() }
        }
    }

    private var managerInitials: String {
        let p = appState.currentUserName.split(separator: " ")
        return p.count >= 2 ? "\(p[0].prefix(1))\(p[1].prefix(1))".uppercased() : String(appState.currentUserName.prefix(2)).uppercased()
    }

    // MARK: - Store Header

    private var storeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GOOD \(greeting.uppercased())")
                .font(.system(size: 9, weight: .semibold))
                .tracking(3)
                .foregroundColor(AppColors.accent)
            Text(appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Manager")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.primary)
            Text(Date(), style: .date)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening"
    }

    // MARK: - Daily Sales Strip

    private var dailySalesStrip: some View {
        VStack(spacing: 10) {
            sectionHeader("TODAY'S PERFORMANCE")

            HStack(spacing: 0) {
                salesPill(value: "$42,800", label: "Today", icon: "dollarsign.circle.fill", color: AppColors.accent)
                Rectangle().fill(Color(.systemGray5)).frame(width: 1, height: 40)
                salesPill(value: "7", label: "Transactions", icon: "creditcard.fill", color: AppColors.secondary)
                Rectangle().fill(Color(.systemGray5)).frame(width: 1, height: 40)
                salesPill(value: "$6,114", label: "Avg. Ticket", icon: "chart.line.uptrend.xyaxis", color: AppColors.success)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            .padding(.horizontal, 20)
        }
    }

    private func salesPill(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - KPI Grid

    private var kpiGrid: some View {
        VStack(spacing: 10) {
            sectionHeader("STORE OVERVIEW")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                kpiCard(icon: "chart.bar.fill", iconColor: AppColors.accent,
                        value: "$248K", label: "MTD Revenue", badge: "+8.2%", positive: true)
                kpiCard(icon: "person.2.fill", iconColor: AppColors.secondary,
                        value: "\(storeStaff.count)", label: "Staff On Duty", badge: "of \(storeStaff.count + 1)", positive: true)
                kpiCard(icon: "shippingbox.fill", iconColor: AppColors.info,
                        value: "\(totalStoreUnits)", label: "Store Units", badge: "\(allProducts.count) SKUs", positive: true)
                kpiCard(icon: "exclamationmark.triangle.fill", iconColor: AppColors.warning,
                        value: "\(lowStockCount)", label: "Low Stock", badge: "\(outOfStockCount) out", positive: false)
            }
            .padding(.horizontal, 20)
        }
    }

    private func kpiCard(icon: String, iconColor: Color, value: String, label: String, badge: String, positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .ultraLight))
                    .foregroundColor(iconColor)
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(positive ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((positive ? AppColors.success : AppColors.warning).opacity(0.1))
                    .clipShape(Capsule())
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: 10) {
            HStack {
                sectionHeader("ALERTS")
                Spacer()
                Text("3")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.warning)
                    .clipShape(Capsule())
                    .padding(.trailing, 20)
            }

            VStack(spacing: 10) {
                alertRow(icon: "exclamationmark.triangle.fill", color: AppColors.error,
                         title: "Heritage Bag — 1 unit", detail: "Reorder or request transfer", time: "15m")
                alertRow(icon: "doc.text.fill", color: AppColors.warning,
                         title: "Inventory Discrepancy", detail: "Pearl Earrings: system 6, counted 5", time: "2h")
                alertRow(icon: "calendar.badge.clock", color: AppColors.info,
                         title: "VIP Appointment", detail: "Mrs. Chen — 3:00 PM private viewing", time: "in 2h")
            }
            .padding(.horizontal, 20)
        }
    }

    private func alertRow(icon: String, color: Color, title: String, detail: String, time: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 40)
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(time)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Top Products

    private var topProductsSection: some View {
        VStack(spacing: 10) {
            HStack {
                sectionHeader("TOP SELLERS TODAY")
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 3) {
                        Text("View All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.accent)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.trailing, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(allProducts.sorted { $0.price > $1.price }.prefix(5)), id: \.id) { product in
                        topProductCard(product)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func topProductCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: "bag",
                cornerRadius: 10
            )
            .frame(width: 120, height: 90)
            .clipped()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(product.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(product.formattedPrice)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.accent)
        }
        .frame(width: 120)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Staff On Duty

    private var staffOnDutySection: some View {
        VStack(spacing: 10) {
            sectionHeader("STAFF ON DUTY")

            HStack(spacing: 12) {
                ForEach(storeStaff.prefix(4)) { user in
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(staffColor(user.role).opacity(0.12))
                                .frame(width: 44, height: 44)
                            Text(staffInitials(user.name))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(staffColor(user.role))
                        }
                        Text(user.name.split(separator: " ").first.map(String.init) ?? "")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                        Text(user.role == .salesAssociate ? "Sales" : "Inv.")
                            .font(.system(size: 9, weight: .light))
                            .foregroundColor(staffColor(user.role))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            .padding(.horizontal, 20)
        }
    }

    private func staffColor(_ role: UserRole) -> Color {
        switch role {
        case .salesAssociate: return AppColors.info
        case .inventoryController: return AppColors.success
        default: return .secondary
        }
    }

    private func staffInitials(_ name: String) -> String {
        let p = name.split(separator: " ")
        return p.count >= 2 ? "\(p[0].prefix(1))\(p[1].prefix(1))".uppercased() : String(name.prefix(2)).uppercased()
    }

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        VStack(spacing: 10) {
            sectionHeader("QUICK ACTIONS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                actionTile(icon: "checkmark.circle.fill", label: "Approve", color: AppColors.success)
                actionTile(icon: "arrow.left.arrow.right", label: "Transfer", color: AppColors.info)
                actionTile(icon: "calendar.badge.plus", label: "VIP Event", color: AppColors.secondary)
                actionTile(icon: "person.badge.clock", label: "Shift", color: AppColors.accent)
                actionTile(icon: "doc.text.fill", label: "Report", color: AppColors.warning)
                actionTile(icon: "exclamationmark.bubble.fill", label: "Flag Item", color: AppColors.error)
            }
            .padding(.horizontal, 20)
        }
    }

    private func actionTile(icon: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(3)
            .foregroundColor(.primary.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}

#Preview {
    ManagerDashboardView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
