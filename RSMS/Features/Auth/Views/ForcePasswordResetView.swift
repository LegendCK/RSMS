//
//  ForcePasswordResetView.swift
//  RSMS
//
//  Mandatory password reset screen shown on first login when the account
//  was created by an admin, manager, or sales associate.
//  No dismiss/back — the user must set a new password to proceed.
//

import SwiftUI

struct ForcePasswordResetView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = ForcePasswordResetViewModel()
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Brand Mark ──────────────────────────────
                    VStack(spacing: 10) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 38, weight: .regular))
                            .foregroundColor(AppColors.accent)

                        Text("MAISON LUXE")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(6)
                            .foregroundColor(.black)
                    }
                    .padding(.top, 72)
                    .padding(.bottom, 36)

                    // ── Lock Icon ──────────────────────────────
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.07))
                            .frame(width: 90, height: 90)
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(AppColors.accent)
                    }
                    .padding(.bottom, 28)

                    // ── Title ──────────────────────────────────
                    VStack(spacing: 8) {
                        Text("Set Your Password")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        Text("For security, please create\na new password to continue.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 44)

                    // ── Password Fields ──────────────────────────
                    VStack(spacing: 24) {
                        // New Password
                        authPasswordField(
                            placeholder: "New Password",
                            text: $viewModel.newPassword,
                            showPassword: $showNewPassword
                        )

                        // Confirm Password
                        authPasswordField(
                            placeholder: "Confirm Password",
                            text: $viewModel.confirmPassword,
                            showPassword: $showConfirmPassword
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)

                    // ── Validation Indicators ────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        validationRow(
                            label: "At least 8 characters",
                            met: viewModel.passwordLengthMet
                        )
                        validationRow(
                            label: "Passwords match",
                            met: viewModel.passwordsMatch
                        )
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 36)

                    // ── Update Button ──────────────────────────
                    Button {
                        viewModel.resetPassword(appState: appState)
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("UPDATE PASSWORD")
                                    .font(.system(size: 15, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(viewModel.isValid ? AppColors.accent : Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(viewModel.isLoading || !viewModel.isValid)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { contentOpacity = 1 }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Validation Row

    private func validationRow(label: String, met: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(met ? AppColors.accent : Color(.systemGray4))

            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(met ? .primary : .secondary)
        }
    }
}

#Preview {
    ForcePasswordResetView()
        .environment(AppState())
}
