//
//  ManagerProfileView.swift
//  infosys2
//
//  Boutique Manager profile — account info, store details, preferences, sign out.
//  Presented as a sheet from the Dashboard nav bar avatar.
//

import SwiftUI

struct ManagerProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation = false

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
                            infoRow(icon: "building.2", title: "Fifth Avenue", subtitle: "New York, NY")
                            infoRow(icon: "person.2", title: "4 Staff Members", subtitle: "2 Sales, 1 Inventory, 1 Service")
                            infoRow(icon: "clock", title: "Store Hours", subtitle: "10:00 AM – 8:00 PM")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider().padding(.horizontal, AppSpacing.screenHorizontal)

                        // Account
                        sectionHeader("ACCOUNT")
                        VStack(spacing: 0) {
                            navRow(icon: "person.text.rectangle", title: "Edit Profile", subtitle: "Name, email, phone")
                            navRow(icon: "key.fill", title: "Change Password", subtitle: "Update credentials")
                            navRow(icon: "faceid", title: "Biometric Login", subtitle: "Face ID / Touch ID")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider().padding(.horizontal, AppSpacing.screenHorizontal)

                        // Preferences
                        sectionHeader("PREFERENCES")
                        VStack(spacing: 0) {
                            navRow(icon: "bell.badge", title: "Notifications", subtitle: "Alerts & push settings")
                            navRow(icon: "globe", title: "Language", subtitle: "English")
                            navRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Contact headquarters")
                        }
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
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().stroke(AppColors.purple.opacity(0.2), lineWidth: 1).frame(width: 116, height: 116)
                Circle().fill(AppColors.backgroundTertiary).frame(width: 100, height: 100)
                Circle().stroke(AppColors.purple, lineWidth: 2).frame(width: 100, height: 100)
                Text(initials).font(AppTypography.displayMedium).foregroundColor(AppColors.purple)
            }
            VStack(spacing: AppSpacing.xxs) {
                Text(appState.currentUserName).font(AppTypography.heading1).foregroundColor(AppColors.textPrimaryDark)
                Text(appState.currentUserEmail).font(AppTypography.bodyMedium).foregroundColor(AppColors.textSecondaryDark)
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "building.2").font(AppTypography.storeIcon)
                    Text("BOUTIQUE MANAGER").font(AppTypography.overline).tracking(2)
                }
                .foregroundColor(AppColors.purple).padding(.top, AppSpacing.xxs)
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
                Image(systemName: icon).font(AppTypography.menuIcon).foregroundColor(AppColors.purple).frame(width: 28)
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
