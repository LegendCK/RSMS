//
//  LoginView.swift
//  RSMS
//
//  Luxury login — clean white, diamond logo mark, underline fields.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = AuthViewModel()
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showPassword = false
    @State private var contentOpacity: Double = 0

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

                        // ── Title ────────────────────────────────────
                        VStack(spacing: 6) {
                            Text("Welcome Back")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Sign in to your account")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 44)

                        // ── Form Fields ──────────────────────────────
                        VStack(spacing: 28) {
                            // Email
                            authUnderlineField(
                                placeholder: "Email",
                                text: $viewModel.loginEmail,
                                icon: "envelope",
                                keyboardType: .emailAddress
                            )

                            // Password
                            VStack(spacing: 0) {
                                authPasswordField(
                                    placeholder: "Password",
                                    text: $viewModel.loginPassword,
                                    showPassword: $showPassword
                                )
                                HStack {
                                    Spacer()
                                    Button("Forgot Password?") { showForgotPassword = true }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppColors.accent)
                                        .padding(.top, 10)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)

                        // ── Actions ──────────────────────────────────
                        VStack(spacing: 16) {
                            // Sign In
                            Button {
                                viewModel.login(appState: appState)
                            } label: {
                                Group {
                                    if viewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("SIGN IN")
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

                            orDivider

                            // Create Account
                            VStack(spacing: 10) {
                                Text("New to Maison Luxe?")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)

                                Button { showSignUp = true } label: {
                                    Text("CREATE ACCOUNT")
                                        .font(.system(size: 15, weight: .bold))
                                        .tracking(2)
                                        .foregroundColor(AppColors.accent)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(AppColors.backgroundSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(AppColors.accent, lineWidth: 1.5)
                                        )
                                }
                            }

                            orDivider

                            // Guest
                            Button {
                                Task { await appState.continueAsGuest() }
                            } label: {
                                Text("Browse as Guest")
                                    .font(.system(size: 14, weight: .regular))
                                    .underline()
                                    .foregroundColor(.secondary)
                            }

                            Text("Staff accounts are provisioned by management")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 60)
                    }
                }
                .opacity(contentOpacity)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 0.4)) { contentOpacity = 1 }
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

    // MARK: - Shared Field Components

    private var orDivider: some View {
        HStack(spacing: 14) {
            Rectangle().fill(Color(.systemGray5)).frame(height: 1)
            Text("OR")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(.secondary.opacity(0.5))
            Rectangle().fill(Color(.systemGray5)).frame(height: 1)
        }
    }
}

// MARK: - Reusable Underline Field Helpers

/// Plain underline text field used across auth screens
func authUnderlineField(
    placeholder: String,
    text: Binding<String>,
    icon: String,
    keyboardType: UIKeyboardType = .default,
    isSecure: Bool = false
) -> some View {
    HStack(spacing: 14) {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .light))
            .foregroundColor(.secondary)
            .frame(width: 18)

        if isSecure {
            SecureField(placeholder, text: text)
                .font(.system(size: 16))
        } else {
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
    .padding(.bottom, 14)
    .overlay(alignment: .bottom) {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
    }
}

/// Password field with show/hide toggle
func authPasswordField(
    placeholder: String,
    text: Binding<String>,
    showPassword: Binding<Bool>
) -> some View {
    HStack(spacing: 14) {
        Image(systemName: "lock")
            .font(.system(size: 15, weight: .light))
            .foregroundColor(.secondary)
            .frame(width: 18)

        Group {
            if showPassword.wrappedValue {
                TextField(placeholder, text: text)
                    .font(.system(size: 16))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: text)
                    .font(.system(size: 16))
            }
        }

        Button {
            showPassword.wrappedValue.toggle()
        } label: {
            Image(systemName: showPassword.wrappedValue ? "eye" : "eye.slash")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(.secondary)
        }
    }
    .padding(.bottom, 14)
    .overlay(alignment: .bottom) {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
