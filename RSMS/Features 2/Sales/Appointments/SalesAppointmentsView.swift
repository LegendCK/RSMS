//
//  SalesAppointmentsView.swift
//  infosys2
//
//  Sales Associate appointment management — booking, reminders, schedule.
//

import SwiftUI
import SwiftData

struct SalesAppointmentsView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Today").tag(0)
                        Text("Upcoming").tag(1)
                        Text("Past").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)

                    Spacer()

                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "calendar.badge.clock")
                            .font(AppTypography.emptyStateIcon)
                            .foregroundColor(AppColors.accent.opacity(0.5))
                        Text("No appointments scheduled")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text("Book appointments to provide personalized experiences")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark.opacity(0.7))
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("APPOINTMENTS")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { } label: {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}
