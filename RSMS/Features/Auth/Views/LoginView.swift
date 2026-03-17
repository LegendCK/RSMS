//
//  LoginView.swift
//  RSMS
//
//  Editorial luxury login — Zara/H&M inspired black & maroon.
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
                Color.white.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // Black editorial top band
                        ZStack(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 220)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("MAISON LUXE")
                                    .font(.system(size: 10, weight: .black))
                                    .tracking(6)
                                    .foregroundColor(AppColors.accent)
                                Text("Welcome\nBack.")
                                    .font(.system(size: 40, weight: .black))
                                    .foregroundColor(.white)
                                    .lineSpacing(2)
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)
                        }
                        .frame(height: 220)

                        // Form area
                        VStack(spacing: 0) {
                            VStack(spacing: AppSpacing.xl) {
                                LuxuryTextField(
                                    placeholder: "Email",
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
                            .padding(.horizontal, 24)
                            .padding(.top, 36)

                            // Forgot password
                            HStack {
                                Spacer()
                                Button(action: { showForgotPassword = true }) {
                                    Text("Forgot Password?")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                            // Sign in button — maroon, iOS-native rounded
                            Button(action: { viewModel.login(appState: appState) }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("SIGN IN")
                                            .font(.system(size: 14, weight: .semibold))
                                            .tracking(2)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(AppColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 28)

                            // Divider
                            HStack(spacing: AppSpacing.md) {
                                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
                                Text("OR")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(2)
                                    .foregroundColor(.black.opacity(0.3))
                                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)

                            // Create account — maroon outlined, iOS-native rounded
                            Button(action: { showSignUp = true }) {
                                Text("CREATE ACCOUNT")
                                    .font(.system(size: 14, weight: .semibold))
                                    .tracking(2)
                                    .foregroundColor(AppColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(AppColors.accent, lineWidth: 1.5)
                                    )
                            }
                            .padding(.horizontal, 24)

                            // Guest access
                            Button(action: { Task { await appState.continueAsGuest() } }) {
                                Text("Browse as Guest")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(.black.opacity(0.45))
                                    .underline()
                            }
                            .padding(.top, 20)

                            Text("Staff accounts are provisioned by management")
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(.black.opacity(0.3))
                                .padding(.top, 16)
                                .padding(.bottom, 48)
                        }
                    }
                }
                .opacity(contentOpacity)
            }
            .onAppear {
                withAnimation(.easeIn(duration: 0.5)) { contentOpacity = 1 }
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
