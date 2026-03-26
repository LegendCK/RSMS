//
//  ForgotPasswordView.swift
//  RSMS
//
//  Password reset — clean white, matching login/signup aesthetic.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Brand Mark ──────────────────────────────
                        VStack(spacing: 10) {
                            MaisonLuxeLogo(size: 60)
                            Text("MAISON LUXE")
                                .font(.system(size: 15, weight: .semibold))
                                .tracking(6)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 72)
                        .padding(.bottom, 36)

                        // ── Icon ────────────────────────────────────
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.07))
                                .frame(width: 90, height: 90)
                            Image(systemName: "key.viewfinder")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(.bottom, 28)

                        // ── Title ────────────────────────────────────
                        VStack(spacing: 8) {
                            Text("Forgot Password?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Enter your email and we'll send\na secure reset link.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.bottom, 44)

                        // ── Email Field ──────────────────────────────
                        authUnderlineField(
                            placeholder: "Email Address",
                            text: $viewModel.resetEmail,
                            icon: "envelope",
                            keyboardType: .emailAddress
                        )
                        .padding(.horizontal, 32)
                        .padding(.bottom, 36)

                        // ── Send Button ──────────────────────────────
                        VStack(spacing: 20) {
                            Button {
                                viewModel.resetPassword()
                            } label: {
                                Group {
                                    if viewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("SEND RESET LINK")
                                            .font(.system(size: 15, weight: .bold))
                                            .tracking(2)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(AppColors.accent)
                                .clipShape(Capsule())
                            }
                            .disabled(viewModel.isLoading)

                            Button("Back to Sign In") { dismiss() }
                                .font(.system(size: 14, weight: .regular))
                                .underline()
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 60)
                    }
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .alert("Reset Link Sent", isPresented: $viewModel.showResetSuccess) {
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
