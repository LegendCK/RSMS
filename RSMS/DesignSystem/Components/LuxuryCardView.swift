//
//  LuxuryCardView.swift
//  RSMS
//
//  iOS 26 card component with Liquid Glass effect for product/category display.
//

import SwiftUI

struct LuxuryCardView<Content: View>: View {
    var useGlass: Bool = true
    var glassConfig: LiquidGlassConfig = .regular
    var backgroundColor: Color = AppColors.backgroundSecondary
    var cornerRadius: CGFloat = AppSpacing.radiusLarge
    @ViewBuilder let content: () -> Content

    var body: some View {
        if useGlass {
            content()
                .liquidGlass(
                    config: glassConfig,
                    backgroundColor: backgroundColor,
                    cornerRadius: cornerRadius
                )
                .liquidShadow(LiquidShadow.subtle)
        } else {
            content()
                .padding(AppSpacing.md)
                .background(backgroundColor)
                .cornerRadius(cornerRadius)
                .liquidShadow(LiquidShadow.subtle)
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: AppSpacing.md) {
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
        }
        .frame(width: 200)
        .padding()
    }
}
