//
//  SplashScreenView.swift
//  infosys2
//
//  Premium splash screen with logo animation on dark luxury background.
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(AppState.self) var appState

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var taglineOpacity: Double = 0
    @State private var dividerWidth: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        ZStack {
            // Deep black background
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Logo mark — diamond icon as brand symbol
                VStack(spacing: AppSpacing.lg) {
                    ZStack {
                        // Outer purple glow ring
                        Circle()
                            .stroke(AppColors.purple.opacity(0.2), lineWidth: 1)
                            .frame(width: 150, height: 150)

                        // Inner gold ring
                        Circle()
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                            .frame(width: 120, height: 120)

                        // Inner diamond icon
                        Image(systemName: "diamond.fill")
                            .font(AppTypography.brandIconSplash)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accent, AppColors.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // Brand name
                    VStack(spacing: AppSpacing.xs) {
                        Text("MAISON")
                            .font(AppTypography.displayLarge)
                            .tracking(8)
                            .foregroundColor(AppColors.textPrimaryDark)

                        Text("LUXE")
                            .font(AppTypography.displayMedium)
                            .tracking(12)
                            .foregroundColor(AppColors.accent)
                    }
                    .opacity(logoOpacity)
                }

                // Gold divider line animation
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.accent.opacity(0),
                                AppColors.accent,
                                AppColors.accent.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: dividerWidth, height: 1)

                // Tagline
                Text("The Art of Luxury")
                    .font(AppTypography.bodyMedium)
                    .tracking(3)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .opacity(taglineOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Phase 1: Logo fade in and scale
        withAnimation(.easeOut(duration: 1.0)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        // Phase 2: Divider extends
        withAnimation(.easeInOut(duration: 0.8).delay(0.6)) {
            dividerWidth = 120
        }

        // Phase 3: Tagline fade in
        withAnimation(.easeIn(duration: 0.6).delay(1.0)) {
            taglineOpacity = 1.0
        }

        // Phase 4: Advance to next screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            appState.completeSplash()
        }
    }
}

#Preview {
    SplashScreenView()
        .environment(AppState())
}
