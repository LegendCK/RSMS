//
//  EmailOTPViewModel.swift
//  RSMS
//
//  ViewModel for the email OTP verification screen.
//  Handles sending, resending, and verifying 6-digit codes.
//

import SwiftUI

@MainActor
@Observable
class EmailOTPViewModel {

    // MARK: - Fields
    var otpCode: String = ""
    let email: String

    // MARK: - UI State
    var isLoading: Bool = false
    var isSending: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    var resendCooldown: Int = 0   // seconds remaining before resend is allowed
    var codeSent: Bool = false

    private var cooldownTask: Task<Void, Never>?

    init(email: String) {
        self.email = email
    }

    // MARK: - Validation

    var isValid: Bool {
        otpCode.count == 6 && otpCode.allSatisfy(\.isNumber)
    }

    // MARK: - Send OTP

    func sendOTP() {
        isSending = true

        Task { @MainActor in
            defer { isSending = false }
            do {
                try await AuthService.shared.sendOTP(email: email)
                codeSent = true
                startCooldown()
            } catch {
                showErrorMessage("Failed to send verification code. Please try again.")
            }
        }
    }

    // MARK: - Resend OTP

    func resendOTP() {
        guard resendCooldown == 0 else { return }
        sendOTP()
    }

    // MARK: - Verify OTP

    func verifyOTP(appState: AppState) {
        guard isValid else {
            showErrorMessage("Please enter a valid 6-digit code.")
            return
        }

        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }
            do {
                let verified = try await AuthService.shared.verifyOTP(email: email, code: otpCode)
                if verified {
                    appState.completeOTPVerification()
                } else {
                    showErrorMessage("Invalid or expired code. Please try again.")
                }
            } catch {
                showErrorMessage(friendlyError(error))
            }
        }
    }

    // MARK: - Cooldown Timer

    private func startCooldown() {
        cooldownTask?.cancel()
        resendCooldown = 60
        cooldownTask = Task { [weak self] in
            for remaining in stride(from: 60, through: 1, by: -1) {
                if Task.isCancelled { return }
                await MainActor.run {
                    self?.resendCooldown = remaining
                }
                try? await Task.sleep(for: .seconds(1))
                if self == nil { return }
            }
            await MainActor.run {
                self?.resendCooldown = 0
            }
        }
    }

    // MARK: - Helpers

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("network") || msg.contains("offline") || msg.contains("connection") {
            return "No internet connection. Please check your network."
        }
        if msg.contains("expired") {
            return "Code has expired. Please request a new one."
        }
        return "Verification failed. Please try again."
    }
}
