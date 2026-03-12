//
//  AuthViewModel.swift
//  infosys2
//
//  ViewModel handling login, signup, and forgot password — powered by Supabase Auth.
//

import SwiftUI

@Observable
class AuthViewModel {

    // MARK: - Login fields
    var loginEmail: String = ""
    var loginPassword: String = ""

    // MARK: - Sign up fields (customers only)
    var signUpFirstName: String = ""
    var signUpLastName: String = ""
    var signUpEmail: String = ""
    var signUpPhone: String = ""
    var signUpPassword: String = ""
    var signUpConfirmPassword: String = ""

    // MARK: - Forgot password
    var resetEmail: String = ""

    // MARK: - UI state
    var errorMessage: String = ""
    var showError: Bool = false
    var isLoading: Bool = false
    var showResetSuccess: Bool = false

    // MARK: - Validation

    var isLoginValid: Bool {
        !loginEmail.trimmingCharacters(in: .whitespaces).isEmpty && !loginPassword.isEmpty
    }

    var isSignUpValid: Bool {
        !signUpFirstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !signUpLastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !signUpEmail.trimmingCharacters(in: .whitespaces).isEmpty &&
        !signUpPassword.isEmpty &&
        signUpPassword == signUpConfirmPassword &&
        signUpPassword.count >= 8
    }

    var isResetValid: Bool {
        let e = resetEmail.trimmingCharacters(in: .whitespaces)
        return !e.isEmpty && e.contains("@")
    }

    // MARK: - Login

    func login(appState: AppState) {
        guard isLoginValid else {
            showErrorMessage("Please enter your email and password.")
            return
        }
        isLoading = true
        let email    = loginEmail.trimmingCharacters(in: .whitespaces).lowercased()
        let password = loginPassword

        Task { @MainActor in
            defer { isLoading = false }
            do {
                let profile = try await AuthService.shared.signIn(email: email, password: password)
                appState.login(profile: profile)
            } catch {
                showErrorMessage(friendlyError(error))
            }
        }
    }

    // MARK: - Sign Up (Customers)

    func signUp(appState: AppState) {
        guard isSignUpValid else {
            if signUpPassword != signUpConfirmPassword {
                showErrorMessage("Passwords do not match.")
            } else if signUpPassword.count < 8 {
                showErrorMessage("Password must be at least 8 characters.")
            } else {
                showErrorMessage("Please fill in all required fields.")
            }
            return
        }
        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }
            do {
                let profile = try await AuthService.shared.signUp(
                    firstName: signUpFirstName.trimmingCharacters(in: .whitespaces),
                    lastName:  signUpLastName.trimmingCharacters(in: .whitespaces),
                    email:     signUpEmail.trimmingCharacters(in: .whitespaces).lowercased(),
                    phone:     signUpPhone.trimmingCharacters(in: .whitespaces),
                    password:  signUpPassword
                )
                appState.login(profile: profile)
            } catch {
                showErrorMessage(friendlyError(error))
            }
        }
    }

    // MARK: - Forgot Password

    func resetPassword() {
        guard isResetValid else {
            showErrorMessage("Please enter a valid email address.")
            return
        }
        isLoading = true
        let email = resetEmail.trimmingCharacters(in: .whitespaces).lowercased()

        Task { @MainActor in
            defer { isLoading = false }
            do {
                try await AuthService.shared.resetPassword(email: email)
                showResetSuccess = true
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
        if msg.contains("invalid login") || msg.contains("invalid credentials") || msg.contains("email not confirmed") {
            return "Invalid email or password. Please try again."
        }
        if msg.contains("network") || msg.contains("offline") || msg.contains("connection") {
            return "No internet connection. Please check your network."
        }
        if msg.contains("rate limit") || msg.contains("too many") {
            return "Too many attempts. Please wait a moment and try again."
        }
        return error.localizedDescription
    }
}
