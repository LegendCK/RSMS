//
//  SalesProfileView.swift
//  infosys2
//
//  Sales Associate profile and settings.
//

import SwiftUI

struct SalesProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Avatar
                        Circle()
                            .fill(AppColors.accent.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(appState.currentUserName.prefix(1)))
                                    .font(AppTypography.heading2)
                                    .foregroundColor(AppColors.accent)
                            )
                            .padding(.top, AppSpacing.lg)

                        VStack(spacing: AppSpacing.xs) {
                            Text(appState.currentUserName)
                                .font(AppTypography.heading3)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text(appState.currentUserEmail)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                            Text("Sales Associate & After-Sales Specialist")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.accent)
                        }

                        GoldDivider()
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Settings rows
                        VStack(spacing: 0) {
                            profileRow(icon: "chart.bar.fill", title: "My Performance")
                            profileRow(icon: "bell.fill", title: "Notifications")
                            profileRow(icon: "gearshape.fill", title: "Settings")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Logout
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                appState.logout()
                            }
                        } label: {
                            Text("Sign Out")
                                .font(AppTypography.buttonPrimary)
                                .foregroundColor(AppColors.error)
                                .frame(maxWidth: .infinity)
                                .padding(AppSpacing.md)
                                .background(AppColors.error.opacity(0.1))
                                .cornerRadius(AppSpacing.radiusMedium)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PROFILE")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
            }
        }
    }

    private func profileRow(icon: String, title: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text(title)
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(.vertical, AppSpacing.md)
    }
}
