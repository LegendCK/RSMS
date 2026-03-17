//
//  SecondaryButton.swift
//  RSMS
//
//  iOS 26 outlined button with Liquid Glass optional background.
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var useGlass: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .semibold))
                .tracking(2)
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.touchTarget + 4)
                .foregroundColor(AppColors.accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppColors.accent, lineWidth: 1.5)
                )
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            SecondaryButton(title: "Create Account", action: { })
            SecondaryButton(title: "Glass Less", action: { }, useGlass: false)
        }
        .padding()
    }
}
