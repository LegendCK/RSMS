//
//  ProfileView.swift
//  infosys2
//
//  User profile screen with account info and logout.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) var appState
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        // Profile header
                        VStack(spacing: AppSpacing.md) {
                            // Avatar
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
                                Text(appState.currentUserName.isEmpty ? "Guest" : appState.currentUserName)
                                    .font(AppTypography.heading1)
                                    .foregroundColor(AppColors.textPrimaryDark)

                                Text(appState.currentUserEmail)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textSecondaryDark)

                                Text(appState.currentUserRole.rawValue.uppercased())
                                    .font(AppTypography.overline)
                                    .tracking(2)
                                    .foregroundColor(AppColors.accent)
                                    .padding(.top, AppSpacing.xxs)
                            }
                        }
                        .padding(.top, AppSpacing.xxl)

                        GoldDivider()
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Menu items
                        VStack(spacing: 0) {
                            NavigationLink(destination: OrdersListView()) {
                                profileRowContent(icon: "bag", title: "My Orders", subtitle: "Track your orders")
                            }
                            profileRow(icon: "calendar", title: "Appointments", subtitle: "Book a boutique visit")
                            profileRow(icon: "bell", title: "Notifications", subtitle: "Manage preferences")
                            profileRow(icon: "creditcard", title: "Payment Methods", subtitle: "Manage cards")
                            profileRow(icon: "mappin.and.ellipse", title: "Addresses", subtitle: "Delivery addresses")
                            profileRow(icon: "shield", title: "Privacy & Security", subtitle: "Account settings")
                            profileRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Contact us")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        GoldDivider()
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Logout
                        Button(action: { showLogoutConfirmation = true }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(AppTypography.signOutIcon)
                                Text("Sign Out")
                                    .font(AppTypography.buttonSecondary)
                            }
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSpacing.touchTarget)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // App version
                        Text("Version 1.0.0")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.neutral600)
                            .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(AppTypography.gearIcon)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("Are you sure you want to sign out of your account?")
            }
        }
    }

    private var initials: String {
        let components = appState.currentUserName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "G"
    }

    private func profileRow(icon: String, title: String, subtitle: String) -> some View {
        Button(action: {}) {
            profileRowContent(icon: icon, title: title, subtitle: subtitle)
        }
    }

    private func profileRowContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(AppTypography.menuIconLarge)
                .foregroundColor(AppColors.accent)
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

#Preview {
    ProfileView()
        .environment(AppState())
}
