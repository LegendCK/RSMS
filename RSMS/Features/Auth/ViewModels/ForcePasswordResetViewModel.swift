//
//  ForcePasswordResetViewModel.swift
//  RSMS
//
//  ViewModel for the mandatory password reset screen shown on first login
//  when the account was created by an admin/manager/associate.
//

import SwiftUI

@Observable
class ForcePasswordResetViewModel {

    // MARK: - Fields
    var newPassword: String = ""
    var confirmPassword: String = ""

    // MARK: - UI State
    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false

    // MARK: - Validation

    var isValid: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword
    }

    var passwordLengthMet: Bool {
        newPassword.count >= 8
    }

    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    // MARK: - Reset Password

    func resetPassword(appState: AppState) {
        guard isValid else {
            if newPassword.count < 8 {
                showErrorMessage("Password must be at least 8 characters.")
            } else if newPassword != confirmPassword {
                showErrorMessage("Passwords do not match.")
            }
            return
        }

        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }
            do {
                // 1. Update the password in Supabase Auth
                try await AuthService.shared.updatePassword(newPassword)

                // 2. Clear the must_reset_password flag in the database
                try await AuthService.shared.clearMustResetFlag()

                // 3. Route to the correct dashboard
                appState.completePasswordReset()
            } catch {
                showErrorMessage(friendlyError(error))
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
        if msg.contains("weak") || msg.contains("password") {
            return "Password is too weak. Please choose a stronger password."
        }
        if msg.contains("session") || msg.contains("expired") {
            return "Your session has expired. Please log in again."
        }
        return "Failed to update password. Please try again."
    }
}
