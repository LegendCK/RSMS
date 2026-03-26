//
//  EmailOTPVerificationView.swift
//  RSMS
//
//  Email OTP verification screen for customer login.
//  Shows a 6-digit code input with resend option.
//  No dismiss/back — the customer must verify to proceed.
//

import SwiftUI

struct EmailOTPVerificationView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel: EmailOTPViewModel
    @State private var contentOpacity: Double = 0
    @FocusState private var isCodeFocused: Bool

    init(email: String) {
        _viewModel = State(initialValue: EmailOTPViewModel(email: email))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Brand Mark
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

                    // Shield Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.07))
                            .frame(width: 90, height: 90)
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 38, weight: .ultraLight))
                            .foregroundColor(AppColors.accent)
                    }
                    .padding(.bottom, 28)

                    // Title
                    VStack(spacing: 8) {
                        Text("Verify Your Email")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        Text("We've sent a 6-digit code to\n\(viewModel.email)")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 44)

                    // OTP Input
                    VStack(spacing: 16) {
                        otpInputField
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                    // Resend Section
                    resendSection
                        .padding(.bottom, 36)

                    // Verify Button
                    Button {
                        viewModel.verifyOTP(appState: appState)
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("VERIFY")
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
            // Auto-send OTP when view appears
            if !viewModel.codeSent {
                viewModel.sendOTP()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - OTP Input Field

    private var otpInputField: some View {
        VStack(spacing: 12) {
            // Hidden text field for keyboard input
            TextField("", text: $viewModel.otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isCodeFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: viewModel.otpCode) { _, newValue in
                    // Limit to 6 digits
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    if filtered != newValue {
                        viewModel.otpCode = filtered
                    }
                }

            // Visual OTP boxes
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    otpDigitBox(at: index)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isCodeFocused = true }
        }
        .onAppear { isCodeFocused = true }
    }

    private func otpDigitBox(at index: Int) -> some View {
        let digits = Array(viewModel.otpCode)
        let hasDigit = index < digits.count
        let digit = hasDigit ? String(digits[index]) : ""
        let isCurrentPosition = index == digits.count

        return Text(digit)
            .font(.system(size: 28, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .frame(width: 48, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCurrentPosition ? AppColors.accent :
                            hasDigit ? AppColors.accent.opacity(0.3) :
                            Color(.systemGray4),
                        lineWidth: isCurrentPosition ? 2 : 1
                    )
            )
    }

    // MARK: - Resend Section

    private var resendSection: some View {
        HStack(spacing: 4) {
            if viewModel.isSending {
                ProgressView()
                    .scaleEffect(0.75)
                Text("Sending code...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else if viewModel.resendCooldown > 0 {
                Text("Resend code in \(viewModel.resendCooldown)s")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Text("Didn't receive the code?")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Button("Resend") {
                    viewModel.resendOTP()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.accent)
            }
        }
    }
}

#Preview {
    EmailOTPVerificationView(email: "test@example.com")
        .environment(AppState())
}
