//
//  AuthService.swift
//  infosys2
//
//  Handles all Supabase Auth operations:
//  signIn, signUp (customer), signOut, resetPassword, fetchProfile.
//
//  Uses the server-side `get_my_profile()` RPC function which runs
//  as SECURITY DEFINER to bypass RLS and auto-sync placeholder UUIDs.
//

import Foundation
import Supabase

@MainActor
final class AuthService {

    static let shared = AuthService()
    private let client = SupabaseManager.shared.client
    private init() {}

    // MARK: - Fetch Profile via RPC

    /// Calls the `get_my_profile()` Postgres function (SECURITY DEFINER).
    /// This bypasses RLS and auto-syncs placeholder UUIDs from seed.sql.
    private func fetchMyProfile() async throws -> UserDTO {
        let profiles: [UserDTO] = try await client
            .rpc("get_my_profile")
            .execute()
            .value

        guard let profile = profiles.first else {
            throw AuthError.profileNotFound
        }
        return profile
    }

    // MARK: - Sign In

    /// Authenticates with Supabase Auth then fetches the user's profile row.
    /// Returns the UserDTO on success, throws on failure.
    func signIn(email: String, password: String) async throws -> UserDTO {
        // 1. Authenticate
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        print("[AuthService] signIn succeeded for user: \(session.user.id)")

        // 2. Fetch profile using RPC (handles UUID mismatch automatically)
        let profile = try await fetchMyProfile()
        print("[AuthService] Profile loaded: \(profile.email) (\(profile.role))")
        return profile
    }

    // MARK: - Sign Up (Customers only)

    /// Creates a Supabase Auth account then inserts a profile row in public.users.
    func signUp(
        firstName: String,
        lastName: String,
        email: String,
        phone: String,
        password: String
    ) async throws -> UserDTO {
        // 1. Create Auth account
        let authResponse = try await client.auth.signUp(
            email: email,
            password: password
        )

        let authUser = authResponse.user

        // 2. Insert profile row
        let insert = UserInsertDTO(
            id: authUser.id,
            role: "client",
            storeId: nil,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone.isEmpty ? nil : phone,
            isActive: true
        )

        let profile: UserDTO = try await client
            .from("users")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return profile
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Forgot Password

    /// Sends a password reset email via Supabase Auth.
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    // MARK: - Restore Session

    /// Checks for an existing valid session on app launch.
    /// Returns the UserDTO if a session exists, nil otherwise.
    func restoreSession() async -> UserDTO? {
        do {
            _ = try await client.auth.session
            print("[AuthService] restoreSession: valid session found")

            let profile = try await fetchMyProfile()
            print("[AuthService] restoreSession: profile loaded: \(profile.email)")
            return profile
        } catch {
            print("[AuthService] restoreSession: failed — \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case signUpFailed
    case profileNotFound
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .signUpFailed:      return "Sign up failed. Please try again."
        case .profileNotFound:   return "Account profile not found. Please contact support."
        case .sessionExpired:    return "Your session has expired. Please log in again."
        }
    }
}
