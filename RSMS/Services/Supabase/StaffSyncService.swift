//
//  StaffSyncService.swift
//  RSMS
//

import Foundation
import SwiftData
import Supabase

@MainActor
final class StaffSyncService {

    static let shared = StaffSyncService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Response DTO for Edge Function

    struct CreateStaffResponseDTO: Decodable {
        let id: UUID
        let email: String
        let first_name: String
        let last_name: String
        let phone: String?
        let role: String
        let store_id: UUID?
        let is_active: Bool
        let created_at: Date

        var fullName: String {
            [first_name.trimmingCharacters(in: .whitespacesAndNewlines),
             last_name.trimmingCharacters(in: .whitespacesAndNewlines)]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        var userRole: UserRole {
            switch role.lowercased() {
            case "corporate_admin":      return .corporateAdmin
            case "boutique_manager":     return .boutiqueManager
            case "sales_associate":      return .salesAssociate
            case "inventory_controller": return .inventoryController
            case "service_technician":   return .serviceTechnician
            default:                     return .salesAssociate
            }
        }

        enum CodingKeys: String, CodingKey {
            case id, email, first_name, last_name, phone, role, store_id, is_active, created_at
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id         = try c.decode(UUID.self,   forKey: .id)
            email      = try c.decode(String.self, forKey: .email)
            first_name = try c.decode(String.self, forKey: .first_name)
            last_name  = try c.decode(String.self, forKey: .last_name)
            phone      = try c.decodeIfPresent(String.self, forKey: .phone)
            role       = try c.decode(String.self, forKey: .role)
            store_id   = try c.decodeIfPresent(UUID.self,   forKey: .store_id)
            is_active  = try c.decode(Bool.self,   forKey: .is_active)

            let dateString = try c.decode(String.self, forKey: .created_at)
            let formatter  = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                created_at = date
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                guard let date = formatter.date(from: dateString) else {
                    throw DecodingError.dataCorruptedError(forKey: .created_at, in: c,
                        debugDescription: "Cannot parse date: \(dateString)")
                }
                created_at = date
            }
        }
    }

    private struct EdgeResponse: Decodable {
        let success: Bool?
        let error: String?
        let user: CreateStaffResponseDTO?
    }

    // MARK: - Create with password (used by OrgCreateStaffSheet)
    // CA sets a temporary password and shares it with the new staff member.

    func createStaffWithAuth(
        name: String,
        email: String,
        phone: String,
        password: String,
        role: UserRole
    ) async throws -> UserDTO {

        // Capture admin session — ok if nil (CA using local auth)
        let adminSession = try? await client.auth.session

        // Sign up new user in Supabase Auth
        let authResponse = try await client.auth.signUp(email: email, password: password)
        let authUser = authResponse.user

        do {
            let (firstName, lastName) = splitName(name)
            let payload = UserInsertDTO(
                id: authUser.id,
                role: snakeRole(for: role),
                storeId: nil,
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

            // Restore admin session
            if let adminSession {
                _ = try? await client.auth.setSession(
                    accessToken: adminSession.accessToken,
                    refreshToken: adminSession.refreshToken
                )
            } else {
                try? await client.auth.signOut()
            }

            return dto

        } catch {
            if let adminSession {
                _ = try? await client.auth.setSession(
                    accessToken: adminSession.accessToken,
                    refreshToken: adminSession.refreshToken
                )
            } else {
                try? await client.auth.signOut()
            }
            throw error
        }
    }

    // MARK: - Create via Invite Email (future use when web app is ready)

    func createStaffWithInvite(
        name: String,
        email: String,
        phone: String,
        role: UserRole
    ) async throws -> CreateStaffResponseDTO {

        let (firstName, lastName) = splitName(name)

        struct Payload: Encodable {
            let email: String
            let firstName: String
            let lastName: String
            let phone: String
            let role: String
        }

        let payload = Payload(
            email: email.lowercased(),
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            role: snakeRole(for: role)
        )

        let response: EdgeResponse = try await client.functions.invoke(
            "create-staff-user",
            options: FunctionInvokeOptions(body: payload)
        )

        if let error = response.error {
            throw NSError(domain: "StaffSyncService", code: 0,
                userInfo: [NSLocalizedDescriptionKey: error])
        }

        guard let userDTO = response.user else {
            throw NSError(domain: "StaffSyncService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No user data returned"])
        }

        return userDTO
    }

    // MARK: - Sync

    func syncStaff(modelContext: ModelContext) async throws {
        try await pullRemoteStaff(modelContext: modelContext)
    }

    // MARK: - Update

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

    // MARK: - Private

    private func pullRemoteStaff(modelContext: ModelContext) async throws {
        let remote: [UserDTO] = try await client
            .from("users")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        let remoteStaffIds = Set(remote.filter { $0.userRole != .customer }.map { $0.id })
        let locals = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })

        for dto in remote {
            guard dto.userRole != .customer else { continue }
            if let existing = byId[dto.id] {
                apply(dto, to: existing)
            } else {
                let created = makeUser(from: dto)
                modelContext.insert(created)
                byId[created.id] = created
            }
        }

        for local in locals where local.role != .customer {
            if !remoteStaffIds.contains(local.id) {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
    }

    private func apply(_ dto: UserDTO, to user: User) {
        user.name     = dto.fullName
        user.email    = dto.email
        user.phone    = dto.phone ?? ""
        user.role     = dto.userRole
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
        case .corporateAdmin:      return "corporate_admin"
        case .boutiqueManager:     return "boutique_manager"
        case .salesAssociate:      return "sales_associate"
        case .inventoryController: return "inventory_controller"
        case .serviceTechnician:   return "service_technician"
        case .customer:            return "client"
        }
    }

    private func splitName(_ fullName: String) -> (String, String) {
        let parts = fullName.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !parts.isEmpty else { return ("Staff", "User") }
        if parts.count == 1 { return (parts[0], "—") }
        return (parts[0], parts.dropFirst().joined(separator: " "))
    }
}
