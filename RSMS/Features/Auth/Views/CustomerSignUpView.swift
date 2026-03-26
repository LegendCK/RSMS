//
//  CustomerSignUpView.swift
//  RSMS
//
//  Customer-only sign up form — clean white, underline fields, matching login aesthetic.
//

import SwiftUI

struct CustomerSignUpView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()
    @State private var showPassword = false
    @State private var showConfirmPassword = false

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
                        .padding(.top, 60)
                        .padding(.bottom, 28)

                        // ── Title ────────────────────────────────────
                        VStack(spacing: 6) {
                            Text("Create Account")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Join the Maison Luxe community")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 40)

                        // ── Form Fields ──────────────────────────────
                        VStack(spacing: 28) {
                            HStack(spacing: 20) {
                                authUnderlineField(
                                    placeholder: "First Name",
                                    text: $viewModel.signUpFirstName,
                                    icon: "person"
                                )
                                authUnderlineField(
                                    placeholder: "Last Name",
                                    text: $viewModel.signUpLastName,
                                    icon: "person"
                                )
                            }

                            authUnderlineField(
                                placeholder: "Email Address",
                                text: $viewModel.signUpEmail,
                                icon: "envelope",
                                keyboardType: .emailAddress
                            )

                            authUnderlineField(
                                placeholder: "Phone Number",
                                text: $viewModel.signUpPhone,
                                icon: "phone",
                                keyboardType: .phonePad
                            )

                            authPasswordField(
                                placeholder: "Password",
                                text: $viewModel.signUpPassword,
                                showPassword: $showPassword
                            )

                            authPasswordField(
                                placeholder: "Confirm Password",
                                text: $viewModel.signUpConfirmPassword,
                                showPassword: $showConfirmPassword
                            )

                            // Password hint
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.secondary)
                                Text("Minimum 8 characters required")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 36)

                        // ── Actions ──────────────────────────────────
                        VStack(spacing: 20) {
                            // Create Account
                            Button {
                                viewModel.signUp(appState: appState)
                            } label: {
                                Group {
                                    if viewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("CREATE ACCOUNT")
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

                            // Terms
                            Text("By creating an account, you agree to our\nTerms of Service and Privacy Policy")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.65))
                                .multilineTextAlignment(.center)

                            // Back to sign in
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                                Button("Sign In") { dismiss() }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
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
