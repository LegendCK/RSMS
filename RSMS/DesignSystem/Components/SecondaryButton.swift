//
//  SecondaryButton.swift
//  infosys2
//
//  Outlined variant button with champagne gold border.
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(AppTypography.buttonSecondary)
                .tracking(1.2)
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.touchTarget + 4)
                .foregroundColor(AppColors.accent)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.accent, lineWidth: 1.5)
                )
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        SecondaryButton(title: "Create Account") { }
            .padding()
    }
}
