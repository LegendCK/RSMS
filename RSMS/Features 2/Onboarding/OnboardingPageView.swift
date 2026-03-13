//
//  OnboardingPageView.swift
//  infosys2
//
//  Single onboarding page template with icon, title, and subtitle.
//

import SwiftUI

struct OnboardingPageData {
    let icon: String
    let title: String
    let subtitle: String
    let accentDetail: String
}

struct OnboardingPageView: View {
    let data: OnboardingPageData

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon area
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppColors.accent.opacity(0.15),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)

                // Outer decorative ring — purple
                Circle()
                    .stroke(AppColors.purple.opacity(0.15), lineWidth: 1)
                    .frame(width: 200, height: 200)

                // Middle decorative ring — gold
                Circle()
                    .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                    .frame(width: 160, height: 160)

                // Inner ring
                Circle()
                    .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                    .frame(width: 120, height: 120)

                // Icon
                Image(systemName: data.icon)
                    .font(AppTypography.iconHero)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent, AppColors.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Spacer()
                .frame(height: AppSpacing.hero)

            // Text content
            VStack(spacing: AppSpacing.md) {
                // Eyebrow
                Text(data.accentDetail.uppercased())
                    .font(AppTypography.overline)
                    .tracking(3)
                    .foregroundColor(AppColors.accent)

                // Title
                Text(data.title)
                    .font(AppTypography.displaySmall)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)

                // Subtitle
                Text(data.subtitle)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.xxxl)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        OnboardingPageView(data: OnboardingPageData(
            icon: "crown.fill",
            title: "Discover Luxury Collections",
            subtitle: "Explore curated selections from the world's most prestigious brands.",
            accentDetail: "Collections"
        ))
    }
}
