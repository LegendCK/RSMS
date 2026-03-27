//
//  OnboardingView.swift
//  RSMS
//
//  Dark luxury onboarding — centered icon glow, bold title, pill dots, Continue button.
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
            title: "White-Glove Service",
            subtitle: "Schedule private viewings and track your orders with dedicated concierge service.",
            accentDetail: "Services"
        )
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(action: { appState.completeOnboarding() }) {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textPrimaryDark.opacity(0.75))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppColors.backgroundSecondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.border.opacity(0.6), lineWidth: 1)
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 60)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageContent(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom controls
                VStack(spacing: 28) {
                    // Pill dots
                    HStack(spacing: 6) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? AppColors.accent : AppColors.backgroundSecondary)
                                .frame(width: index == currentPage ? 24 : 6, height: 6)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            index == currentPage
                                                ? AppColors.accent
                                                : AppColors.border.opacity(0.75),
                                            lineWidth: 1
                                        )
                                )
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }

                    // Action button
                    if currentPage == pages.count - 1 {
                        Button(action: { appState.completeOnboarding() }) {
                            Text("GET STARTED")
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(AppColors.accent)
                                .clipShape(Capsule())
                                .shadow(color: AppColors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 28)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Button(action: { withAnimation { currentPage += 1 } }) {
                            Text("CONTINUE")
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(AppColors.backgroundSecondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AppColors.border.opacity(0.75), lineWidth: 1.5)
                                )
                        }
                        .padding(.horizontal, 28)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 52)
                .animation(.easeInOut, value: currentPage)
            }
        }
    }

    private func pageContent(_ data: OnboardingPageData) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon without glow rings
            ZStack {

                // Icon
                Image(systemName: data.icon)
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent, AppColors.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Spacer().frame(height: 52)

            // Text — left aligned
            VStack(alignment: .leading, spacing: 10) {
                Text(data.accentDetail.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(4)
                    .foregroundColor(AppColors.accent)

                Text(data.title)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineSpacing(3)

                Text(data.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineSpacing(5)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
