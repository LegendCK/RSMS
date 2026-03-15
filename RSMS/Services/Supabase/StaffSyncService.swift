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

    /// Updates an existing remote staff profile.
    /// Does not create new remote rows because `users.id` is typically a FK to `auth.users`.
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

        let locals = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })

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

        try? modelContext.save()
    }

    private func apply(_ dto: UserDTO, to user: User) {
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
        case .serviceTechnician: return "service_technician"
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
