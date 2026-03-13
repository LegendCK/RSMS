//
//  SalesDashboardView.swift
//  infosys2
//
//  Sales Associate dashboard — personal KPIs, appointments, client activity, quick actions.
//

import SwiftUI
import SwiftData

struct SalesDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var showingProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Greeting
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("SALES ADVISOR")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                            Text("Welcome, \(appState.currentUserName)")
                                .font(AppTypography.heading2)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Quick Stats
                        HStack(spacing: AppSpacing.md) {
                            salesStatCard(title: "Today's Sales", value: "$0", icon: "dollarsign.circle.fill")
                            salesStatCard(title: "Clients Served", value: "0", icon: "person.fill")
                            salesStatCard(title: "Appointments", value: "0", icon: "calendar")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Quick Actions
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("QUICK ACTIONS")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, AppSpacing.screenHorizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                                quickActionCard(title: "New Client", icon: "person.badge.plus", color: AppColors.accent)
                                quickActionCard(title: "Book Appointment", icon: "calendar.badge.plus", color: AppColors.purple)
                                quickActionCard(title: "Start Sale", icon: "bag.badge.plus", color: AppColors.success)
                                quickActionCard(title: "Create AST", icon: "wrench.and.screwdriver", color: AppColors.info)
                            }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // Placeholder for upcoming appointments
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("TODAY'S APPOINTMENTS")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            Text("No appointments scheduled for today")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.xl)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        Spacer(minLength: AppSpacing.xxxl)
                    }
                    .padding(.top, AppSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MAISON LUXE")
                        .font(AppTypography.overline)
                        .tracking(3)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingProfile = true } label: {
                        Image(systemName: "person.circle")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                SalesProfileView()
            }
        }
    }

    private func salesStatCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.accent)
            Text(value)
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func quickActionCard(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}
