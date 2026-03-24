//
//  ClientService.swift
//  infosys2
//
//  Handles client profile CRUD operations via Supabase for Sales Associates.
//

import Foundation
import Supabase

@MainActor
final class ClientService {
    static let shared = ClientService()
    private let client = SupabaseManager.shared.client

    private init() {}

    /// Creates a Supabase Auth account for a new offline client, inserts their
    /// profile into `clients`, then restores the associate's session.
    /// Returns the created ClientDTO and a temporary password for the client to use.
    func createClientWithAuth(_ payload: ClientInsertDTO) async throws -> (client: ClientDTO, temporaryPassword: String) {
        // 1. Save the current associate's session so we can restore it afterward.
        let associateSession = try await client.auth.session

        // 2. Generate a secure temporary password.
        let tempPassword = Self.generateTempPassword()

        // 3. Create the Supabase Auth account — this gives us a real UUID.
        let authResponse = try await client.auth.signUp(email: payload.email, password: tempPassword)
        let authUser = authResponse.user

        // 4. Insert the client profile row using the auth UUID as `id`.
        var payloadWithId = payload
        payloadWithId.id = authUser.id

        do {
            let createdClient: ClientDTO = try await client
                .from("clients")
                .insert(payloadWithId)
                .select()
                .single()
                .execute()
                .value

            // 5. Restore the associate's session.
            try await client.auth.setSession(
                accessToken: associateSession.accessToken,
                refreshToken: associateSession.refreshToken
            )

            return (createdClient, tempPassword)
        } catch {
            // Always restore the associate's session even on failure.
            _ = try? await client.auth.setSession(
                accessToken: associateSession.accessToken,
                refreshToken: associateSession.refreshToken
            )
            throw error
        }
    }

    /// Generates a temporary password that satisfies Supabase's requirements.
    private static func generateTempPassword() -> String {
        let lowers = Array("abcdefghijklmnopqrstuvwxyz")
        let uppers = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let digits = Array("0123456789")
        let symbols = Array("@#$%")
        let all = lowers + uppers + digits + symbols

        var chars: [Character] = []
        chars.append(lowers.randomElement() ?? "a")
        chars.append(uppers.randomElement() ?? "A")
        chars.append(digits.randomElement() ?? "1")
        chars.append(symbols.randomElement() ?? "@")
        for _ in 0..<8 {
            chars.append(all.randomElement() ?? "x")
        }
        return String(chars.shuffled())
    }

    /// Fetches all active clients.
    func fetchAllClients() async throws -> [ClientDTO] {
        return try await client
            .from("clients")
            .select()
            .eq("is_active", value: true)
            .order("last_name", ascending: true)
            .execute()
            .value
    }

    /// Fetches active clients created by a specific associate.
    func fetchClientsForAssociate(associateId: UUID) async throws -> [ClientDTO] {
        return try await client
            .from("clients")
            .select()
            .eq("created_by", value: associateId.uuidString)
            .eq("is_active", value: true)
            .order("last_name", ascending: true)
            .execute()
            .value
    }
    
    /// Fetches active VIP clients for a specific associate.
    func fetchVIPClients(associateId: UUID? = nil) async throws -> [ClientDTO] {
        var query = client.from("clients").select().eq("is_active", value: true)
        
        if let associateId {
            query = query.eq("created_by", value: associateId.uuidString)
        }
        
        // Match multiple VIP segments using 'in' works, but Supabase swift client uses in(column, array)
        return try await query
            .in("segment", values: ["gold", "vip"])
            .order("last_name", ascending: true)
            .execute()
            .value
    }

    /// Searches for clients by name, email, or phone.
    func searchClients(query: String) async throws -> [ClientDTO] {
        guard !query.isEmpty else { return try await fetchAllClients() }
        let searchTerm = "%\(query)%"
        
        // using an OR query: first_name ILIKE %query% OR last_name ILIKE %query% OR email ILIKE %query% OR phone ILIKE %query%
        return try await client
            .from("clients")
            .select()
            .eq("is_active", value: true)
            .or("first_name.ilike.\(searchTerm),last_name.ilike.\(searchTerm),email.ilike.\(searchTerm),phone.ilike.\(searchTerm)")
            .order("last_name", ascending: true)
            .execute()
            .value
    }

    /// Fetches a single client by ID.
    func fetchClient(id: UUID) async throws -> ClientDTO {
        return try await client
            .from("clients")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    /// Fetches a batch of clients by IDs.
    func fetchClients(ids: [UUID]) async throws -> [ClientDTO] {
        let uniqueIds = Array(Set(ids))
        guard !uniqueIds.isEmpty else { return [] }

        return try await client
            .from("clients")
            .select()
            .in("id", values: uniqueIds.map { $0.uuidString.lowercased() })
            .execute()
            .value
    }

    /// Updates a client's full profile (associate-level: includes segment + notes blob).
    /// Records `updated_at` via Supabase trigger automatically.
    func updateClient(id: UUID, payload: ClientAssociateUpdateDTO) async throws -> ClientDTO {
        return try await client
            .from("clients")
            .update(payload)
            .eq("id", value: id.uuidString.lowercased())
            .select()
            .single()
            .execute()
            .value
    }
}
