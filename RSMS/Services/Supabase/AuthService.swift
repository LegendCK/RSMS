//
//  AuthService.swift
//  infosys2
//
//  Handles all Supabase Auth operations:
//  signIn, signUp (customer), signOut, resetPassword, fetchProfile.
//

import Foundation
import Supabase

@MainActor
final class AuthService {

    static let shared = AuthService()
    private let client = SupabaseManager.shared.client
    private init() {}

    // MARK: - Fetch Profile

    /// Resolves the current session to either a staff `users` profile
    /// or a customer `clients` profile mapped to `UserDTO`.
    private func fetchMyProfile() async throws -> UserDTO {
        if let staffProfile = try await fetchStaffProfile() {
            return staffProfile
        }

        if let clientProfile = try await fetchClientProfile() {
            return clientProfile
        }

        throw AuthError.profileNotFound
    }

    /// Attempts to load a staff profile from `users`.
    /// First uses the legacy RPC if available, then falls back to a direct filtered read.
    private func fetchStaffProfile() async throws -> UserDTO? {
        do {
            let profiles: [UserDTO] = try await client
                .rpc("get_my_profile")
                .execute()
                .value

            if let profile = profiles.first {
                return profile
            }
        } catch {
            // If RPC is not present or fails for this role, use direct table fallback.
            print("[AuthService] get_my_profile RPC unavailable/fallback: \(error.localizedDescription)")
        }

        do {
            // Filter explicitly by auth UID — works with or without RLS SELECT policy.
            let uid = try await client.auth.session.user.id
            let profile: UserDTO = try await client
                .from("users")
                .select()
                .eq("id", value: uid.uuidString.lowercased())
                .single()
                .execute()
                .value
            return profile
        } catch {
            print("[AuthService] fetchStaffProfile fallback failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Attempts to load a customer profile from `clients` and map it to `UserDTO`.
    ///
    /// Strategy (two-pass):
    /// 1. Query by `id = auth.uid` — works for customers who self-registered (clients.id == auth.uid).
    /// 2. If that fails, fall back to `email = auth.email` — works for clients created offline
    ///    by a sales associate before the customer had a Supabase Auth account.
    private func fetchClientProfile() async throws -> UserDTO? {
        let uid: UUID
        let email: String
        do {
            let session = try await client.auth.session
            uid   = session.user.id
            email = session.user.email ?? ""
        } catch {
            print("[AuthService] fetchClientProfile: no session — \(error.localizedDescription)")
            return nil
        }
        print("[AuthService] fetchClientProfile: querying clients for uid=\(uid)")

        // Pass 1: match by primary key (common path — customer self-registered via the app)
        if let profile: ClientDTO = try? await client
            .from("clients")
            .select()
            .eq("id", value: uid.uuidString.lowercased())
            .single()
            .execute()
            .value {
            print("[AuthService] fetchClientProfile: found by id — \(profile.email)")
            return UserDTO(clientProfile: profile)
        }

        // Pass 2: match by email — handles clients pre-created by a sales associate
        // (their clients.id won't match auth.uid since they had no auth account at creation).
        guard !email.isEmpty else {
            print("[AuthService] fetchClientProfile: id miss and no auth email — giving up")
            return nil
        }

        print("[AuthService] fetchClientProfile: id miss — retrying by email: \(email)")
        do {
            let profile: ClientDTO = try await client
                .from("clients")
                .select()
                .eq("email", value: email.lowercased())
                .single()
                .execute()
                .value
            print("[AuthService] fetchClientProfile: found by email — \(profile.email)")
            return UserDTO(clientProfile: profile)
        } catch {
            print("[AuthService] fetchClientProfile failed (both passes): \(error.localizedDescription)")
            print("[AuthService] fetchClientProfile raw error: \(error)")
            return nil
        }
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

        // 2. Resolve profile from users (staff) or clients (customer)
        let profile = try await fetchMyProfile()
        print("[AuthService] Profile loaded: \(profile.email) (\(profile.role))")
        return profile
    }

    /// Performs an anonymous sign-in to allow guest users an authenticated session context.
    /// This is useful for RLS policies that permit 'authenticated' but not 'anon' access.
    func signInAnonymously() async throws {
        try await client.auth.signInAnonymously()
        print("[AuthService] signInAnonymously succeeded")
    }

    // MARK: - Sign Up (Customers only)

    /// Creates a Supabase Auth account then inserts the customer profile row in public.clients.
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

        // 2. Insert customer profile row in clients.
        let insert = ClientInsertDTO(
            id: authUser.id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone.isEmpty ? nil : phone,
            dateOfBirth: nil,
            nationality: nil,
            preferredLanguage: "en",
            addressLine1: nil,
            addressLine2: nil,
            city: nil,
            state: nil,
            postalCode: nil,
            country: nil,
            segment: "standard",
            notes: nil,
            gdprConsent: false,
            marketingOptIn: false,
            createdBy: nil,
            isActive: true
        )

        let profile: ClientDTO
        do {
            profile = try await client
                .from("clients")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("row-level security") || message.contains("permission denied") {
                throw AuthError.clientProfileInsertForbidden
            }
            throw error
        }

        return UserDTO(clientProfile: profile)
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
    case clientProfileInsertForbidden

    var errorDescription: String? {
        switch self {
        case .signUpFailed:      return "Sign up failed. Please try again."
        case .profileNotFound:   return "Account profile not found. Please contact support."
        case .sessionExpired:    return "Your session has expired. Please log in again."
        case .clientProfileInsertForbidden:
            return "Account was created, but client profile insertion is blocked by database policy. Please update clients insert policy for authenticated users."
        }
    }
}
