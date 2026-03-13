//
//  LoginView.swift
//  infosys2
//
//  Premium login screen with luxury branding.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = AuthViewModel()

    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var contentOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Brand header
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "diamond.fill")
                                .font(AppTypography.brandIcon)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.accent, AppColors.accentLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("MAISON LUXE")
                                .font(AppTypography.heading2)
                                .tracking(6)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        .padding(.top, AppSpacing.hero)
                        .padding(.bottom, AppSpacing.xxxl)

                        // Welcome text
                        VStack(spacing: AppSpacing.xs) {
                            Text("Welcome Back")
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)

                            Text("Sign in to your account")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(.bottom, AppSpacing.xxxl)

                        // Input fields
                        VStack(spacing: AppSpacing.xl) {
                            LuxuryTextField(
                                placeholder: "Email or Employee ID",
                                text: $viewModel.loginEmail,
                                icon: "envelope"
                            )
                            .keyboardType(.emailAddress)

                            LuxuryTextField(
                                placeholder: "Password",
                                text: $viewModel.loginPassword,
                                isSecure: true,
                                icon: "lock"
                            )
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Forgot password
                        HStack {
                            Spacer()
                            Button(action: { showForgotPassword = true }) {
                                Text("Forgot Password?")
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)

                        // Login button
                        PrimaryButton(
                            title: "Sign In",
                            isLoading: viewModel.isLoading
                        ) {
                            viewModel.login(appState: appState)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.xxl)

                        // Divider
                        HStack(spacing: AppSpacing.md) {
                            GoldDivider(opacity: 0.2)
                            Text("OR")
                                .font(AppTypography.caption)
                                .tracking(2)
                                .foregroundColor(AppColors.neutral500)
                            GoldDivider(opacity: 0.2)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.vertical, AppSpacing.xl)

                        // Sign up link
                        VStack(spacing: AppSpacing.xs) {
                            Text("New to Maison Luxe?")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)

                            SecondaryButton(title: "Create Account") {
                                showSignUp = true
                            }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // Staff note
                        Text("Staff accounts are provisioned by management")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.neutral600)
                            .padding(.top, AppSpacing.xl)
                            .padding(.bottom, AppSpacing.xxl)
                    }
                }
                .opacity(contentOpacity)
            }
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) {
                    contentOpacity = 1
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $showSignUp) {
                CustomerSignUpView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
