//
//  GuestAuthGateView.swift
//  RSMS
//
//  Shown when a guest user tries to add to bag or buy now.
//  Presents sign-in / create-account options with a "Continue Browsing" escape hatch.
//

import SwiftUI

struct GuestAuthGateView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var showSignIn  = false
    @State private var showSignUp  = false

    /// The action the guest was trying to perform, e.g. "Add to Bag" or "Buy Now".
    let pendingAction: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // Lock icon
                        ZStack {
                            Circle()
                                .fill(AppColors.backgroundSecondary)
                                .frame(width: 84, height: 84)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.accent, AppColors.accentLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.top, AppSpacing.xxl)

                        // Headline
                        VStack(spacing: AppSpacing.xs) {
                            Text("Members Only")
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)

                            Text("Sign in or create an account\nto \(pendingAction.lowercased())")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }

                        // Member benefits
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            benefitRow(icon: "bag.fill",         text: "Free returns within 30 days")
                            benefitRow(icon: "gift.fill",        text: "Exclusive member offers & early access")
                            benefitRow(icon: "shippingbox.fill", text: "Track your orders in real time")
                            benefitRow(icon: "star.fill",        text: "Earn loyalty points on every purchase")
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusLarge)

                        // CTA buttons
                        VStack(spacing: AppSpacing.sm) {
                            PrimaryButton(title: "Sign In") {
                                showSignIn = true
                            }

                            SecondaryButton(title: "Create Account") {
                                showSignUp = true
                            }
                        }

                        // Escape hatch
                        Button("Continue Browsing") {
                            dismiss()
                        }
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.neutral500)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
            }
        }
        // Auto-dismiss when the user successfully signs in
        .onChange(of: appState.isGuest) { _, newValue in
            if !newValue { dismiss() }
        }
        .fullScreenCover(isPresented: $showSignIn) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showSignUp) {
            CustomerSignUpView()
        }
    }

    // MARK: - Subviews

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(AppColors.accent)
                .frame(width: 20, alignment: .center)

            Text(text)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)

            Spacer()
        }
    }
}

#Preview {
    GuestAuthGateView(pendingAction: "Add to Bag")
        .environment(AppState())
}
