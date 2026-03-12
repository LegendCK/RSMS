//
//  ForgotPasswordView.swift
//  infosys2
//
//  Password reset flow with email input.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: AppSpacing.hero)

                    // Icon
                    // Icon
                    ZStack {
                        Circle()
                            .stroke(AppColors.purple.opacity(0.2), lineWidth: 1)
                            .frame(width: 100, height: 100)

                        Circle()
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                            .frame(width: 80, height: 80)

                        Image(systemName: "key.fill")
                            .font(AppTypography.keyIcon)
                            .foregroundColor(AppColors.accent)
                            .rotationEffect(.degrees(-45))
                    }
                    .padding(.bottom, AppSpacing.xl)

                    // Header
                    VStack(spacing: AppSpacing.xs) {
                        Text("Reset Password")
                            .font(AppTypography.displaySmall)
                            .foregroundColor(AppColors.textPrimaryDark)

                        Text("Enter your email and we'll send you\na link to reset your password")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.bottom, AppSpacing.xxxl)

                    // Email field
                    LuxuryTextField(
                        placeholder: "Email Address",
                        text: $viewModel.resetEmail,
                        icon: "envelope"
                    )
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Reset button
                    PrimaryButton(
                        title: "Send Reset Link",
                        isLoading: viewModel.isLoading
                    ) {
                        viewModel.resetPassword()
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xxl)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(AppTypography.closeButton)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .alert("Success", isPresented: $viewModel.showResetSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("A password reset link has been sent to your email address.")
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
    ForgotPasswordView()
}
