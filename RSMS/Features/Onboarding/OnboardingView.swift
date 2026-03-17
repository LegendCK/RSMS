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
            Color(hex: "0D0D0D").ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(action: { appState.completeOnboarding() }) {
                            Text("Skip")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.trailing, 24)
                                .padding(.top, 20)
                        }
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
                                .fill(index == currentPage ? AppColors.accent : Color.white.opacity(0.2))
                                .frame(width: index == currentPage ? 24 : 6, height: 6)
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
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, 28)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Button(action: { withAnimation { currentPage += 1 } }) {
                            Text("CONTINUE")
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
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

            // Icon with glow rings
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.accent.opacity(0.18), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)

                // Decorative rings
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 200, height: 200)

                Circle()
                    .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                    .frame(width: 150, height: 150)

                Circle()
                    .stroke(AppColors.accent.opacity(0.5), lineWidth: 1)
                    .frame(width: 110, height: 110)

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
                    .foregroundColor(.white)
                    .lineSpacing(3)

                Text(data.subtitle)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(.white.opacity(0.55))
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
