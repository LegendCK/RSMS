//
//  ManagerProfileView.swift
//  infosys2
//
//  Boutique Manager profile — account info, store details, preferences, sign out.
//  Presented as a sheet from the Dashboard nav bar avatar.
//

import SwiftUI
import Supabase

struct ManagerProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation = false

    // Live store data
    @State private var storeDTO: StoreDTO? = nil
    @State private var staffList: [UserDTO] = []
    @State private var isLoadingStore = false

    // MARK: - Computed store display values

    private var storeName: String { storeDTO?.name ?? "—" }
    private var storeLocation: String {
        let parts = [storeDTO?.city, storeDTO?.country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }
    private var staffCountTitle: String {
        let count = staffList.count
        return count == 0 ? "No Staff" : "\(count) Staff Member\(count == 1 ? "" : "s")"
    }
    private var staffBreakdownSubtitle: String {
        let sales     = staffList.filter { $0.role == "sales_associate" }.count
        let inventory = staffList.filter { $0.role == "inventory_controller" }.count
        let service   = staffList.filter { ["service_technician", "aftersales_specialist"].contains($0.role) }.count
        var parts: [String] = []
        if sales     > 0 { parts.append("\(sales) Sales") }
        if inventory > 0 { parts.append("\(inventory) Inventory") }
        if service   > 0 { parts.append("\(service) Service") }
        return parts.isEmpty ? "No role breakdown available" : parts.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        profileHeader

                        GoldDivider().padding(.horizontal, AppSpacing.screenHorizontal)

                        // Store Info
                        sectionHeader("MY BOUTIQUE")
                        VStack(spacing: 0) {
                            if isLoadingStore {
                                HStack {
                                    ProgressView()
                                        .tint(AppColors.accent)
                                    Text("Loading store info…")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                .padding(.vertical, AppSpacing.md)
                            } else {
                                infoRow(icon: "building.2", title: storeName, subtitle: storeLocation)
                                infoRow(icon: "person.2", title: staffCountTitle, subtitle: staffBreakdownSubtitle)
                                if let manager = storeDTO?.managerName, !manager.isEmpty {
                                    infoRow(icon: "person.badge.key", title: "Manager", subtitle: manager)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider().padding(.horizontal, AppSpacing.screenHorizontal)

                        // Account
                        sectionHeader("ACCOUNT")
                        VStack(spacing: 0) {
                            navRow(icon: "person.text.rectangle", title: "Edit Profile", subtitle: "Name, email, phone")
                            navRow(icon: "key.fill", title: "Change Password", subtitle: "Update credentials")
                            navRow(icon: "faceid", title: "Biometric Login", subtitle: "Face ID / Touch ID")
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider().padding(.horizontal, AppSpacing.screenHorizontal)

                        // Preferences
                        sectionHeader("PREFERENCES")
                        VStack(spacing: 0) {
                            navRow(icon: "bell.badge", title: "Notifications", subtitle: "Alerts & push settings")
                            navRow(icon: "globe", title: "Language", subtitle: "English")
                            navRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Contact headquarters")
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider().padding(.horizontal, AppSpacing.screenHorizontal)

                        // Sign Out
                        Button(action: { showLogoutConfirmation = true }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "rectangle.portrait.and.arrow.right").font(AppTypography.signOutIcon)
                                Text("Sign Out").font(AppTypography.buttonSecondary)
                            }
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity).frame(height: AppSpacing.touchTarget)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        Text("Maison Luxe RSMS v1.0.0 • Manager Console")
                            .font(AppTypography.caption).foregroundColor(AppColors.neutral600)
                            .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(AppTypography.closeButton).foregroundColor(AppColors.textPrimaryDark)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Profile").font(AppTypography.navTitle).foregroundColor(AppColors.textPrimaryDark)
                }
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) { appState.logout() }
            } message: {
                Text("You will be signed out of the manager console.")
            }
            .task { await loadStoreData() }
        }
    }

    // MARK: - Data Fetching

    @MainActor
    private func loadStoreData() async {
        guard let storeId = appState.currentStoreId else { return }
        isLoadingStore = true
        defer { isLoadingStore = false }

        let client = SupabaseManager.shared.client
        async let fetchedStore: StoreDTO = client
            .from("stores")
            .select()
            .eq("id", value: storeId.uuidString.lowercased())
            .single()
            .execute()
            .value
        async let fetchedStaff: [UserDTO] = client
            .from("users")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .eq("is_active", value: true)
            .neq("role", value: "boutique_manager")
            .execute()
            .value

        do {
            let (store, staff) = try await (fetchedStore, fetchedStaff)
            storeDTO = store
            staffList = staff
        } catch {
            print("[ManagerProfileView] Failed to load store data: \(error)")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().stroke(AppColors.secondary.opacity(0.2), lineWidth: 1).frame(width: 116, height: 116)
                Circle().fill(AppColors.backgroundTertiary).frame(width: 100, height: 100)
                Circle().stroke(AppColors.secondary, lineWidth: 2).frame(width: 100, height: 100)
                Text(initials).font(AppTypography.displayMedium).foregroundColor(AppColors.secondary)
            }
            VStack(spacing: AppSpacing.xxs) {
                Text(appState.currentUserName).font(AppTypography.heading1).foregroundColor(AppColors.textPrimaryDark)
                Text(appState.currentUserEmail).font(AppTypography.bodyMedium).foregroundColor(AppColors.textSecondaryDark)
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "building.2").font(AppTypography.storeIcon)
                    Text(appState.currentUserRole.rawValue.uppercased()).font(AppTypography.overline).tracking(2)
                }
                .foregroundColor(AppColors.secondary).padding(.top, AppSpacing.xxs)
            }
        }
        .padding(.top, AppSpacing.xxl)
    }

    private var initials: String {
        let p = appState.currentUserName.split(separator: " ")
        return p.count >= 2 ? "\(p[0].prefix(1))\(p[1].prefix(1))".uppercased() : String(appState.currentUserName.prefix(2)).uppercased()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func infoRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon).font(AppTypography.menuIcon).foregroundColor(AppColors.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Text(subtitle).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func navRow(icon: String, title: String, subtitle: String) -> some View {
        Button(action: {}) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon).font(AppTypography.menuIcon).foregroundColor(AppColors.secondary).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text(subtitle).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Image(systemName: "chevron.right").font(AppTypography.chevron).foregroundColor(AppColors.neutral600)
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }
}

#Preview {
    ManagerProfileView()
        .environment(AppState())
}
