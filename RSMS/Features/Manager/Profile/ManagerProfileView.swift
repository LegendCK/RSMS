//
//  ManagerProfileView.swift
//  infosys2
//
//  Boutique Manager profile — account info, store details, preferences, sign out.
//  Presented as a sheet from the Dashboard nav bar avatar.
//

import SwiftUI
@preconcurrency import Supabase

struct ManagerProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation = false

    // Live store data
    @State private var storeDTO: StoreDTO? = nil
    @State private var staffList: [UserDTO] = []
    @State private var boutiqueManager: UserDTO? = nil
    @State private var isLoadingStore = false
    @State private var boutiqueExpanded: Bool = false

    // MARK: - Computed store display values

    private var storeName: String { storeDTO?.name ?? "—" }
    private var storeLocation: String {
        return "—"
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

    private var managerDisplayName: String {
        boutiqueManager?.fullName ?? "—"
    }

    private func roleDisplayName(_ role: String) -> String {
        switch role.lowercased() {
        case "boutique_manager":     return "Boutique Manager"
        case "sales_associate":      return "Sales Associate"
        case "inventory_controller": return "Inventory Controller"
        case "service_technician":   return "Service Technician"
        case "aftersales_specialist": return "After-Sales Specialist"
        case "corporate_admin":      return "Corporate Admin"
        default:                     return role.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role.lowercased() {
        case "boutique_manager":     return AppColors.accent
        case "sales_associate":      return AppColors.info
        case "inventory_controller": return AppColors.warning
        case "service_technician", "aftersales_specialist": return .purple
        default:                     return AppColors.neutral500
        }
    }

    private func staffInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
    }

    var body: some View {
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

                                // Expandable staff row
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        boutiqueExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: AppSpacing.md) {
                                        Image(systemName: "person.2")
                                            .font(AppTypography.menuIcon)
                                            .foregroundColor(AppColors.accent)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(staffCountTitle)
                                                .font(AppTypography.label)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Text(staffBreakdownSubtitle)
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.textSecondaryDark)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(AppTypography.chevron)
                                            .foregroundColor(AppColors.neutral600)
                                            .rotationEffect(.degrees(boutiqueExpanded ? 90 : 0))
                                    }
                                    .padding(.vertical, AppSpacing.sm)
                                }
                                .buttonStyle(.plain)

                                if boutiqueExpanded && !staffList.isEmpty {
                                    VStack(spacing: 0) {
                                        GoldDivider().padding(.leading, 44)
                                        ForEach(Array(staffList.enumerated()), id: \.element.id) { index, member in
                                            HStack(spacing: AppSpacing.sm) {
                                                ZStack {
                                                    Circle()
                                                        .fill(roleColor(member.role).opacity(0.15))
                                                        .frame(width: 36, height: 36)
                                                    Text(staffInitials(member.fullName))
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(roleColor(member.role))
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(member.fullName)
                                                        .font(AppTypography.label)
                                                        .foregroundColor(AppColors.textPrimaryDark)
                                                    Text(roleDisplayName(member.role))
                                                        .font(AppTypography.caption)
                                                        .foregroundColor(AppColors.textSecondaryDark)
                                                }
                                                Spacer()
                                                Circle()
                                                    .fill(member.isActive ? AppColors.success : AppColors.neutral400)
                                                    .frame(width: 8, height: 8)
                                            }
                                            .padding(.vertical, AppSpacing.xs)
                                            .padding(.leading, 44)
                                            if index < staffList.count - 1 {
                                                GoldDivider().padding(.leading, 44)
                                            }
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                infoRow(icon: "person.badge.key", title: "Manager", subtitle: managerDisplayName)
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

    // MARK: - Data Fetching

    @MainActor
    private func loadStoreData() async {
        guard let storeId = appState.currentStoreId else { return }
        isLoadingStore = true
        defer { isLoadingStore = false }

        let client = SupabaseManager.shared.client
        do {
            let store: StoreDTO = try await client
                .from("stores")
                .select()
                .eq("id", value: storeId.uuidString.lowercased())
                .single()
                .execute()
                .value
            let staff: [UserDTO] = try await client
                .from("users")
                .select()
                .eq("store_id", value: storeId.uuidString.lowercased())
                .eq("is_active", value: true)
                .neq("role", value: "boutique_manager")
                .neq("role", value: "client")
                .execute()
                .value
            let managers: [UserDTO] = try await client
                .from("users")
                .select()
                .eq("store_id", value: storeId.uuidString.lowercased())
                .eq("role", value: "boutique_manager")
                .limit(1)
                .execute()
                .value
            storeDTO = store
            staffList = staff
            boutiqueManager = managers.first
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
