//
//  SalesAfterSalesView.swift
//  infosys2
//
//  After-sales service management — repair tickets, warranty, authentication, returns.
//

import SwiftUI
import SwiftData

struct SalesAfterSalesView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Active").tag(0)
                        Text("Repairs").tag(1)
                        Text("Returns").tag(2)
                        Text("History").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)

                    Spacer()

                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(AppTypography.emptyStateIcon)
                            .foregroundColor(AppColors.accent.opacity(0.5))
                        Text("No active service tickets")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text("Create tickets for repairs, warranty claims, and authentication")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AFTER-SALES")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}
