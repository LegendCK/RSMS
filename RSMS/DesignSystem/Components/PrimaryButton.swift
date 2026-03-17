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
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.touchTarget + 8)
            .foregroundColor(.white)
            .background(AppColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
