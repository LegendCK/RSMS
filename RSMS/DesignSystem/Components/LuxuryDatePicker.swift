//
//  LuxuryDatePicker.swift
//  RSMS
//
//  Underline-style date picker — matches LuxuryTextField aesthetics exactly.
//  Always uses .compact DatePicker style (tappable pill that opens a calendar overlay).
//  Eliminates free-text date entry and the format errors it causes.
//

import SwiftUI

struct LuxuryDatePicker: View {
    let label: String
    @Binding var date: Date
    /// Pass a max date to restrict selection (e.g. `Date()` for DOB — no future dates).
    /// Pass `nil` to allow any date (e.g. anniversary events).
    var maximumDate: Date? = Date()
    var icon: String = "calendar"

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Label always visible — a date is always selected, unlike a text field
            Text(label.uppercased())
                .font(AppTypography.overline)
                .tracking(1.0)
                .foregroundColor(AppColors.textSecondaryDark)

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.neutral500)
                    .font(AppTypography.buttonPrimary)
                    .frame(width: 20)

                Group {
                    if let max = maximumDate {
                        DatePicker("", selection: $date, in: ...max, displayedComponents: .date)
                    } else {
                        DatePicker("", selection: $date, displayedComponents: .date)
                    }
                }
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(AppColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: AppSpacing.touchTarget)

            // Underline — mirrors LuxuryTextField resting state
            Rectangle()
                .fill(AppColors.neutral700)
                .frame(height: 1)
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 32) {
            LuxuryDatePicker(label: "Date of Birth", date: .constant(Date()))
            LuxuryDatePicker(label: "Anniversary Date", date: .constant(Date()), maximumDate: nil)
        }
        .padding()
    }
}
