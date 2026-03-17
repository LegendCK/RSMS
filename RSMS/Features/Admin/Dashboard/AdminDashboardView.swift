//
//  AdminDashboardView.swift
//  RSMS
//
//  Corporate Admin enterprise command center.
//  Maroon gradient header, KPI metrics, system health, alerts, quick actions, activity feed.
//

import SwiftUI
import SwiftData

// MARK: - Main Dashboard View

struct AdminDashboardView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allProducts: [Product]
    @Query private var allUsers: [User]
    @Query private var allCategories: [Category]
    @State private var showProfile = false

    @State private var showAddSKU = false
    @State private var showAddStaff = false
    @State private var showAddStore = false

    private let impact = UIImpactFeedbackGenerator(style: .medium)

    private var staffCount: Int { allUsers.filter { $0.role != .customer }.count }
    private var lowStockCount: Int { allProducts.filter { $0.stockCount <= 3 }.count }
    private var outOfStockCount: Int { allProducts.filter { $0.stockCount == 0 }.count }
    private var limitedCount: Int { allProducts.filter { $0.isLimitedEdition }.count }
    private var totalInventoryUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }

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
                        welcomeHeader
                        metricsGrid
                        systemHealthBar
                        alertsSection
                        quickActionsGrid
                        activityFeed
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
                                Text(adminInitials)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) { AdminProfileView() }
            .sheet(isPresented: $showAddSKU) { CreateProductSheet(modelContext: modelContext, categories: allCategories) }
            .sheet(isPresented: $showAddStaff) { CreateUserSheet(modelContext: modelContext) }
            .sheet(isPresented: $showAddStore) { CreateStoreSheet() }
        }
    }

    private var adminInitials: String {
        let parts = appState.currentUserName.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(appState.currentUserName.prefix(2)).uppercased()
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GOOD \(greeting.uppercased())")
                .font(.system(size: 9, weight: .semibold))
                .tracking(3)
                .foregroundColor(AppColors.accent)
            Text(appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Admin")
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

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            sectionHeader("KEY METRICS")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                metricCard(icon: "chart.line.uptrend.xyaxis", iconColor: AppColors.accent,
                           value: "$2.4M", label: "Total Revenue", badge: "+12.5%", badgePositive: true)
                metricCard(icon: "shippingbox.fill", iconColor: AppColors.secondary,
                           value: "\(allProducts.count)", label: "Active SKUs", badge: "\(allCategories.count) cat.", badgePositive: true)
                metricCard(icon: "person.2.fill", iconColor: AppColors.info,
                           value: "\(allUsers.count)", label: "Total Users", badge: "\(staffCount) staff", badgePositive: true)
                metricCard(icon: "building.2.fill", iconColor: AppColors.success,
                           value: "4", label: "Boutiques", badge: "All live", badgePositive: true)
                metricCard(icon: "exclamationmark.triangle.fill", iconColor: AppColors.warning,
                           value: "\(lowStockCount)", label: "Low Stock", badge: "\(outOfStockCount) out", badgePositive: false)
                metricCard(icon: "cube.box.fill", iconColor: AppColors.secondaryLight,
                           value: "\(totalInventoryUnits)", label: "Total Units", badge: "\(limitedCount) limited", badgePositive: true)
            }
            .padding(.horizontal, 20)
        }
    }

    private func metricCard(icon: String, iconColor: Color, value: String, label: String, badge: String, badgePositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .ultraLight))
                    .foregroundColor(iconColor)
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(badgePositive ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((badgePositive ? AppColors.success : AppColors.warning).opacity(0.1))
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

    // MARK: - System Health

    private var systemHealthBar: some View {
        VStack(spacing: 10) {
            sectionHeader("SYSTEM HEALTH")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    healthPill(icon: "checkmark.circle.fill", text: "API", color: AppColors.success)
                    healthPill(icon: "checkmark.circle.fill", text: "Database", color: AppColors.success)
                    healthPill(icon: "checkmark.circle.fill", text: "Payments", color: AppColors.success)
                    healthPill(icon: "exclamationmark.circle.fill", text: "Sync", color: AppColors.warning)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func healthPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: 12) {
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
                         title: "Critical: Heritage Bag", detail: "Stock at 1 unit — reorder required", time: "12m")
                alertRow(icon: "arrow.triangle.2.circlepath", color: AppColors.warning,
                         title: "Sync Delay", detail: "Paris boutique inventory 3h behind", time: "3h")
                alertRow(icon: "person.badge.plus", color: AppColors.info,
                         title: "Access Request", detail: "Sophia Laurent requests catalog edit", time: "5h")
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

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        VStack(spacing: 12) {
            sectionHeader("QUICK ACTIONS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 12) {
                actionTile(icon: "plus.square.fill", label: "Add SKU", color: AppColors.accent) {
                    impact.impactOccurred(); showAddSKU = true
                }
                actionTile(icon: "person.badge.plus", label: "Add Staff", color: AppColors.secondary) {
                    impact.impactOccurred(); showAddStaff = true
                }
                actionTile(icon: "building.2.fill", label: "Add Store", color: AppColors.info) {
                    impact.impactOccurred(); showAddStore = true
                }
                actionTile(icon: "arrow.left.arrow.right", label: "Transfer", color: AppColors.success) {
                    impact.impactOccurred()
                }
                actionTile(icon: "percent", label: "Promotion", color: AppColors.warning) {
                    impact.impactOccurred()
                }
                actionTile(icon: "doc.text.fill", label: "Report", color: AppColors.secondaryLight) {
                    impact.impactOccurred()
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func actionTile(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .buttonStyle(LiquidPressButtonStyle())
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        VStack(spacing: 12) {
            HStack {
                sectionHeader("ACTIVITY")
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

            VStack(spacing: 0) {
                activityItem(action: "SKU Created", detail: "Artisan Timepiece — Limited Edition", by: "V. Sterling", time: "10m")
                Divider().padding(.horizontal, 14)
                activityItem(action: "Price Override", detail: "Diamond Pendant — $15,800 → $16,200", by: "V. Sterling", time: "1h")
                Divider().padding(.horizontal, 14)
                activityItem(action: "Staff Provisioned", detail: "Isabella Moreau → Sales Associate", by: "J. Beaumont", time: "3h")
                Divider().padding(.horizontal, 14)
                activityItem(action: "Stock Transfer", detail: "Classic Flap Bag — NYC → Paris (2 units)", by: "D. Park", time: "6h")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            .padding(.horizontal, 20)
        }
    }

    private func activityItem(action: String, detail: String, by: String, time: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 5, height: 5)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(action)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(time)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.secondary)
                }
                Text(detail)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("by \(by)")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(AppColors.accent.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
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

// MARK: - Liquid Press Button Style

struct LiquidPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Create Store Sheet

struct CreateStoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var storeName = ""
    @State private var storeCity = ""
    @State private var storeCountry = ""
    @State private var storeManager = ""
    @State private var storeType: StoreType = .boutique
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreated = false

    enum StoreType: String, CaseIterable {
        case boutique = "Boutique"
        case distribution = "Distribution Center"
        case popup = "Pop-up"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.info.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(AppColors.info)
                            }
                            Text("Add New Store")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.primary)
                            Text("Register a boutique or distribution center")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("STORE TYPE")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(StoreType.allCases, id: \.self) { type in
                                        Button(action: { storeType = type }) {
                                            Text(type.rawValue)
                                                .font(.system(size: 13, weight: storeType == type ? .semibold : .regular))
                                                .foregroundColor(storeType == type ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 9)
                                                .background(storeType == type ? AppColors.accent : Color(.secondarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(storeType == type ? Color.clear : Color(.systemGray4), lineWidth: 1))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        VStack(spacing: 16) {
                            LuxuryTextField(placeholder: "Store Name", text: $storeName, icon: "building.2")
                            LuxuryTextField(placeholder: "City", text: $storeCity, icon: "mappin")
                            LuxuryTextField(placeholder: "Country", text: $storeCountry, icon: "globe")
                            LuxuryTextField(placeholder: "Manager Name (optional)", text: $storeManager, icon: "person")
                        }
                        .padding(.horizontal, 20)

                        PrimaryButton(title: "Create Store") { createStore() }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage) }
            .alert("Store Created!", isPresented: $isCreated) {
                Button("Done") { dismiss() }
            } message: { Text("\(storeName) has been added to your store network.") }
        }
    }

    private func createStore() {
        guard !storeName.trimmingCharacters(in: .whitespaces).isEmpty,
              !storeCity.trimmingCharacters(in: .whitespaces).isEmpty,
              !storeCountry.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please fill in the store name, city, and country."
            showError = true
            return
        }
        isCreated = true
    }
}

#Preview {
    AdminDashboardView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
