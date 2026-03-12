//
//  OnboardingView.swift
//  infosys2
//
//  Onboarding pager with 3 luxury-themed pages, skip, and get started.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @State private var currentPage = 0

    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            icon: "crown.fill",
            title: "Discover Luxury Collections",
            subtitle: "Explore curated selections from the world's most prestigious brands and artisans.",
            accentDetail: "Collections"
        ),
        OnboardingPageData(
            icon: "person.crop.circle.fill",
            title: "Personalized Boutique Experience",
            subtitle: "Receive tailored recommendations and exclusive access to limited editions.",
            accentDetail: "Experience"
        ),
        OnboardingPageData(
            icon: "calendar.badge.clock",
            title: "Book Appointments & Manage Orders",
            subtitle: "Schedule private viewings and track your orders with white-glove service.",
            accentDetail: "Services"
        )
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with Skip
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(action: { appState.completeOnboarding() }) {
                            Text("Skip")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .frame(height: 44)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(data: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Custom page indicators + button
                VStack(spacing: AppSpacing.xl) {
                    // Page dots
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? AppColors.accent : AppColors.neutral700)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }

                    // Action button
                    if currentPage == pages.count - 1 {
                        PrimaryButton(title: "Get Started") {
                            appState.completeOnboarding()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        SecondaryButton(title: "Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, AppSpacing.xxxl)
                .animation(.easeInOut, value: currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
