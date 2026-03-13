//
//  CustomerSignUpView.swift
//  infosys2
//
//  Customer-only sign up form. Staff accounts are created by admins.
//

import SwiftUI

struct CustomerSignUpView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: AppSpacing.xs) {
                            Text("Create Account")
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)

                            Text("Join the Maison Luxe experience")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(.top, AppSpacing.xxl)
                        .padding(.bottom, AppSpacing.xxxl)

                        // Input fields
                        VStack(spacing: AppSpacing.xl) {
                            LuxuryTextField(
                                placeholder: "First Name",
                                text: $viewModel.signUpFirstName,
                                icon: "person"
                            )

                            LuxuryTextField(
                                placeholder: "Last Name",
                                text: $viewModel.signUpLastName,
                                icon: "person"
                            )

                            LuxuryTextField(
                                placeholder: "Email Address",
                                text: $viewModel.signUpEmail,
                                icon: "envelope"
                            )
                            .keyboardType(.emailAddress)

                            LuxuryTextField(
                                placeholder: "Phone Number",
                                text: $viewModel.signUpPhone,
                                icon: "phone"
                            )
                            .keyboardType(.phonePad)

                            LuxuryTextField(
                                placeholder: "Password",
                                text: $viewModel.signUpPassword,
                                isSecure: true,
                                icon: "lock"
                            )

                            LuxuryTextField(
                                placeholder: "Confirm Password",
                                text: $viewModel.signUpConfirmPassword,
                                isSecure: true,
                                icon: "lock.shield"
                            )
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Password hint
                        HStack {
                            Image(systemName: "info.circle")
                                .font(AppTypography.infoIcon)
                            Text("Minimum 8 characters")
                                .font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.neutral500)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Sign Up button
                        PrimaryButton(
                            title: "Create Account",
                            isLoading: viewModel.isLoading
                        ) {
                            viewModel.signUp(appState: appState)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.xxl)

                        // Terms
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.neutral500)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xxxl)
                            .padding(.top, AppSpacing.lg)
                            .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

#Preview {
    CustomerSignUpView()
        .environment(AppState())
}
