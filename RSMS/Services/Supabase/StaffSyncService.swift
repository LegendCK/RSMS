//
//  StaffSyncService.swift
//  RSMS
//
//  Syncs local SwiftData staff users with Supabase `users` table.
//

import Foundation
import SwiftData
import Supabase

@MainActor
final class StaffSyncService {
    static let shared = StaffSyncService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func syncStaff(modelContext: ModelContext) async throws {
        try await pullRemoteStaff(modelContext: modelContext)
    }

    /// Creates a new staff member end-to-end:
    /// 1. Signs up in Supabase Auth  → creates `auth.users` entry.
    /// 2. Restores manager/admin session.
    /// 3. Inserts the profile row in `users` as manager/admin.
    /// Returns the persisted `UserDTO` with the real auth UUID.
    func createStaffWithAuth(
        name: String,
        email: String,
        phone: String,
        password: String,
        role: UserRole,
        storeId: UUID? = nil
    ) async throws -> UserDTO {
        // 1. Capture admin session before touching auth state.
        let adminSession = try await client.auth.session

        // 2. Sign up — creates auth.users entry and usually switches active session to new user.
        let authResponse = try await client.auth.signUp(email: email, password: password)
        let authUser = authResponse.user

        do {
            // 3. Restore manager/admin session before profile insert so RLS policies
            //    evaluate with manager/admin role.
            try await client.auth.setSession(
                accessToken: adminSession.accessToken,
                refreshToken: adminSession.refreshToken
            )

            // 4. Insert profile as manager/admin.
            let (firstName, lastName) = splitName(name)
            let payload = UserInsertDTO(
                id: authUser.id,
                role: snakeRole(for: role),
                storeId: storeId,
                firstName: firstName,
                lastName: lastName,
                email: email.lowercased(),
                phone: phone.isEmpty ? nil : phone,
                isActive: true
            )

            let dto: UserDTO = try await client
                .from("users")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            return dto
        } catch {
            // Always restore admin session, even on failure.
            try? await client.auth.setSession(
                accessToken: adminSession.accessToken,
                refreshToken: adminSession.refreshToken
            )
            throw error
        }
    }

    /// Updates an existing remote staff profile.
    func updateStaffIfExists(_ user: User) async throws -> UserDTO {
        let (firstName, lastName) = splitName(user.name)
        let payload = UserUpdateDTO(
            role: snakeRole(for: user.role),
            firstName: firstName,
            lastName: lastName,
            phone: user.phone.isEmpty ? nil : user.phone,
            isActive: user.isActive
        )

        let dto: UserDTO = try await client
            .from("users")
            .update(payload)
            .eq("email", value: user.email.lowercased())
            .select()
            .single()
            .execute()
            .value
        return dto
    }

    private func pullRemoteStaff(modelContext: ModelContext) async throws {
        let remote: [UserDTO] = try await client
            .from("users")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        // Build authoritative set of remote staff IDs (customers excluded).
        let remoteStaffIds = Set(remote.filter { $0.userRole != .customer }.map { $0.id })

        let locals = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })

        // Update existing or insert new staff from Supabase.
        for dto in remote {
            let role = dto.userRole
            guard role != .customer else { continue }

            if let existing = byId[dto.id] {
                apply(dto, to: existing)
            } else {
                let created = makeUser(from: dto)
                modelContext.insert(created)
                byId[created.id] = created
            }
        }

        // Delete local staff not present in Supabase (stale seed data / orphaned records).
        for local in locals where local.role != .customer {
            if !remoteStaffIds.contains(local.id) {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
    }

    private func apply(_ dto: UserDTO, to user: User) {
        user.storeId = dto.storeId
        user.name = dto.fullName
        user.email = dto.email
        user.phone = dto.phone ?? ""
        user.role = dto.userRole
        user.isActive = dto.isActive
    }

    private func makeUser(from dto: UserDTO) -> User {
        let user = User(
            name: dto.fullName,
            email: dto.email,
            phone: dto.phone ?? "",
            passwordHash: "",
            storeId: dto.storeId,
            role: dto.userRole,
            isActive: dto.isActive
        )
        user.id = dto.id
        user.createdAt = dto.createdAt
        return user
    }

    private func snakeRole(for role: UserRole) -> String {
        switch role {
        case .corporateAdmin: return "corporate_admin"
        case .boutiqueManager: return "boutique_manager"
        case .salesAssociate: return "sales_associate"
        case .inventoryController: return "inventory_controller"
        case .serviceTechnician: return "aftersales_specialist"
        case .customer: return "client"
        }
    }

    private func splitName(_ fullName: String) -> (String, String) {
        let parts = fullName
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return ("Staff", "User") }
        if parts.count == 1 { return (parts[0], "—") }
        return (parts[0], parts.dropFirst().joined(separator: " "))
    }
}
