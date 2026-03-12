//
//  PrimaryButton.swift
//  infosys2
//
//  Champagne gold filled CTA button with luxury styling.
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
                        .tint(AppColors.primary)
                        .scaleEffect(0.8)
                }
                Text(title.uppercased())
                    .font(AppTypography.buttonPrimary)
                    .tracking(1.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.touchTarget + 8)
            .foregroundColor(AppColors.primary)
            .background(AppColors.accent)
            .cornerRadius(AppSpacing.radiusMedium)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
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
