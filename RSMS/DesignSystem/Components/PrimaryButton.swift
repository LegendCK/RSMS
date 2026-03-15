//
//  PrimaryButton.swift
//  RSMS
//
//  Maroon filled CTA button with professional styling.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.textPrimaryLight)
                        .scaleEffect(0.8)
                }
                Text(title.uppercased())
                    .font(AppTypography.buttonPrimary)
                    .tracking(1.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.touchTarget + 8)
            .foregroundColor(AppColors.textPrimaryLight)
            .background(AppColors.accent)
            .clipShape(Capsule())
            .liquidShadow(LiquidShadow.subtle)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
        .scaleEffect(isLoading ? 0.99 : 1.0)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            PrimaryButton(title: "Sign In") { }
            PrimaryButton(title: "Loading", isLoading: true) { }
        }
        .padding()
    }
}
