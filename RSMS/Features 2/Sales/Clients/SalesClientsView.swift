//
//  SalesClientsView.swift
//  infosys2
//
//  Sales Associate clienteling — manage client profiles, preferences, history.
//

import SwiftUI
import SwiftData

struct SalesClientsView: View {
    @State private var selectedSection = 0
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("My Clients").tag(0)
                        Text("All Clients").tag(1)
                        Text("VIP").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)

                    // Search bar placeholder
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondaryDark)
                        TextField("Search clients...", text: $searchText)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusSmall)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    Spacer()

                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "person.2.fill")
                            .font(AppTypography.emptyStateIcon)
                            .foregroundColor(AppColors.accent.opacity(0.5))
                        Text("Client profiles will appear here")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text("Create client profiles to build lasting relationships")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark.opacity(0.7))
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CLIENTELING")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}
