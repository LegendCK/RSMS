//
//  AdminProfileView.swift
//  infosys2
//
//  Corporate Admin profile — account info, system security, access logs, sign out.
//

import SwiftUI

struct AdminProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        // Profile header
                        profileHeader

                        GoldDivider()
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Account section
                        sectionHeader("ACCOUNT")
                        VStack(spacing: 0) {
                            profileRow(icon: "person.text.rectangle", title: "Admin Profile", subtitle: "Name, email, phone")
                            profileRow(icon: "key.fill", title: "Change Password", subtitle: "Update credentials")
                            profileRow(icon: "faceid", title: "Biometric Login", subtitle: "Face ID / Touch ID")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider()
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        // System Security
                        sectionHeader("SYSTEM SECURITY")
                        VStack(spacing: 0) {
                            profileRow(icon: "shield.checkered", title: "Role-Based Access Control", subtitle: "Manage permissions")
                            profileRow(icon: "clock.arrow.circlepath", title: "Access Logs", subtitle: "View login history")
                            profileRow(icon: "doc.text.magnifyingglass", title: "Audit Trail", subtitle: "System change log")
                            profileRow(icon: "lock.shield", title: "Security Policies", subtitle: "Password & session rules")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider()
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        // System
                        sectionHeader("SYSTEM")
                        VStack(spacing: 0) {
                            profileRow(icon: "gearshape.2", title: "System Configuration", subtitle: "App settings & preferences")
                            profileRow(icon: "bell.badge", title: "Notification Settings", subtitle: "Alerts & push notifications")
                            profileRow(icon: "questionmark.circle", title: "Help & Documentation", subtitle: "Admin guides")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider()
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Sign Out
                        Button(action: { showLogoutConfirmation = true }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(AppTypography.menuIcon)
                                Text("Sign Out")
                                    .font(AppTypography.buttonSecondary)
                            }
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSpacing.touchTarget)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        Text("Maison Luxe RSMS v1.0.0 • Admin Console")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.neutral600)
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
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("You will be signed out of the admin console.")
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .stroke(AppColors.purple.opacity(0.2), lineWidth: 1)
                    .frame(width: 116, height: 116)

                Circle()
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 100, height: 100)

                Circle()
                    .stroke(AppColors.accent, lineWidth: 2)
                    .frame(width: 100, height: 100)

                Text(initials)
                    .font(AppTypography.displayMedium)
                    .foregroundColor(AppColors.accent)
            }

            VStack(spacing: AppSpacing.xxs) {
                Text(appState.currentUserName)
                    .font(AppTypography.heading1)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text(appState.currentUserEmail)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "shield.checkered")
                        .font(AppTypography.storeIcon)
                    Text("CORPORATE ADMIN")
                        .font(AppTypography.overline)
                        .tracking(2)
                }
                .foregroundColor(AppColors.accent)
                .padding(.top, AppSpacing.xxs)
            }
        }
        .padding(.top, AppSpacing.xxl)
    }

    private var initials: String {
        let parts = appState.currentUserName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(appState.currentUserName.prefix(2)).uppercased()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func profileRow(icon: String, title: String, subtitle: String) -> some View {
        Button(action: {}) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(AppTypography.menuIcon)
                    .foregroundColor(AppColors.purple)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.chevron)
                    .foregroundColor(AppColors.neutral600)
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }
}

#Preview {
    AdminProfileView()
        .environment(AppState())
}
