//
//  LuxuryCardView.swift
//  infosys2
//
//  Elevated card component with subtle shadow for product/category display.
//

import SwiftUI

struct LuxuryCardView<Content: View>: View {
    var backgroundColor: Color = AppColors.backgroundTertiary
    var cornerRadius: CGFloat = AppSpacing.radiusLarge
    var shadowOpacity: Double = 0.15
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        LuxuryCardView {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(AppColors.neutral700)
                    .frame(height: 180)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Luxury Handbag")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("$2,450")
                        .font(AppTypography.priceSmall)
                        .foregroundColor(AppColors.accent)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
            }
        }
        .frame(width: 200)
        .padding()
    }
}
