//
//  AdminDashboardView.swift
//  RSMS
//
//  Corporate Admin enterprise command center.
//  KPI metrics, system health, alerts, quick actions, activity feed.
//  Profile/Settings accessible from nav bar avatar — not a separate tab.
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

    // Quick Action sheets
    @State private var showAddSKU = false
    @State private var showAddStaff = false
    @State private var showAddStore = false

    // Haptic feedback
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Computed Metrics

    private var staffCount: Int { allUsers.filter { $0.role != .customer }.count }
    private var lowStockCount: Int { allProducts.filter { $0.stockCount <= 3 }.count }
    private var outOfStockCount: Int { allProducts.filter { $0.stockCount == 0 }.count }
    private var limitedCount: Int { allProducts.filter { $0.isLimitedEdition }.count }
    private var totalInventoryUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
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
                    Text("Dashboard")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
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
            .sheet(isPresented: $showAddSKU) {
                CreateProductSheet(modelContext: modelContext, categories: allCategories)
            }
            .sheet(isPresented: $showAddStaff) {
                CreateUserSheet(modelContext: modelContext)
            }
            .sheet(isPresented: $showAddStore) {
                CreateStoreSheet()
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
            VStack(alignment: .leading, spacing: 4) {
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

    // MARK: - Metrics Grid (3x2)

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            sectionLabel("KEY METRICS")
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
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func metricCard(icon: String, iconColor: Color, value: String, label: String, badge: String, badgePositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
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
        .padding(14)
        .background(
            ZStack {
                // Frosted glass base
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                // Subtle top highlight
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.8), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }

    // MARK: - System Health

    private var systemHealthBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                healthPill(icon: "checkmark.circle.fill", text: "API", color: AppColors.success)
                healthPill(icon: "checkmark.circle.fill", text: "Database", color: AppColors.success)
                healthPill(icon: "checkmark.circle.fill", text: "Payments", color: AppColors.success)
                healthPill(icon: "exclamationmark.circle.fill", text: "Sync", color: AppColors.warning)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func healthPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(spacing: 12) {
            HStack {
                sectionLabel("ALERTS")
                Spacer()
                Text("3")
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textPrimaryLight)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.warning)
                    .cornerRadius(10)
                    .padding(.trailing, AppSpacing.screenHorizontal)
            }

            VStack(spacing: 10) {
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
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 44)

            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.65), Color.white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.8), color.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Quick Actions (3x2)

    private var quickActionsGrid: some View {
        VStack(spacing: 12) {
            sectionLabel("QUICK ACTIONS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 12) {
                actionTile(icon: "plus.square.fill", label: "Add SKU", color: AppColors.accent) {
                    impact.impactOccurred()
                    showAddSKU = true
                }
                actionTile(icon: "person.badge.plus", label: "Add Staff", color: AppColors.secondary) {
                    impact.impactOccurred()
                    showAddStaff = true
                }
                actionTile(icon: "building.2.fill", label: "Add Store", color: AppColors.info) {
                    impact.impactOccurred()
                    showAddStore = true
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
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func actionTile(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(AppTypography.actionLink)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.75),
                                    color.opacity(0.06),
                                    Color.white.opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: color.opacity(0.12), radius: 10, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(LiquidPressButtonStyle())
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        VStack(spacing: 12) {
            HStack {
                sectionLabel("ACTIVITY")
                Spacer()
                Button(action: {}) {
                    Text("View All")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                }
                .padding(.trailing, AppSpacing.screenHorizontal)
            }

            VStack(spacing: 0) {
                activityItem(action: "SKU Created", detail: "Artisan Timepiece — Limited Edition", by: "V. Sterling", time: "10m")
                Divider().background(AppColors.border.opacity(0.4)).padding(.horizontal, 14)
                activityItem(action: "Price Override", detail: "Diamond Pendant — $15,800 → $16,200", by: "V. Sterling", time: "1h")
                Divider().background(AppColors.border.opacity(0.4)).padding(.horizontal, 14)
                activityItem(action: "Staff Provisioned", detail: "Isabella Moreau → Sales Associate", by: "J. Beaumont", time: "3h")
                Divider().background(AppColors.border.opacity(0.4)).padding(.horizontal, 14)
                activityItem(action: "Stock Transfer", detail: "Classic Flap Bag — NYC → Paris (2 units)", by: "D. Park", time: "6h")
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), Color.white.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), Color.white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 5)
            .padding(.horizontal, AppSpacing.screenHorizontal)
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
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
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
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        // Header
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
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text("Register a boutique or distribution center")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, AppSpacing.xl)

                        // Type picker
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("STORE TYPE")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, AppSpacing.screenHorizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.xs) {
                                    ForEach(StoreType.allCases, id: \.self) { type in
                                        Button(action: { storeType = type }) {
                                            Text(type.rawValue)
                                                .font(AppTypography.caption)
                                                .foregroundColor(storeType == type ? AppColors.textPrimaryLight : AppColors.textSecondaryDark)
                                                .padding(.horizontal, AppSpacing.md)
                                                .padding(.vertical, AppSpacing.xs)
                                                .background(storeType == type ? AppColors.accent : AppColors.backgroundTertiary)
                                                .cornerRadius(AppSpacing.radiusSmall)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }

                        // Fields
                        VStack(spacing: AppSpacing.lg) {
                            LuxuryTextField(placeholder: "Store Name", text: $storeName, icon: "building.2")
                            LuxuryTextField(placeholder: "City", text: $storeCity, icon: "mappin")
                            LuxuryTextField(placeholder: "Country", text: $storeCountry, icon: "globe")
                            LuxuryTextField(placeholder: "Manager Name (optional)", text: $storeManager, icon: "person")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        PrimaryButton(title: "Create Store") {
                            createStore()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(AppTypography.closeButton)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Store Created!", isPresented: $isCreated) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(storeName) has been added to your store network.")
            }
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
