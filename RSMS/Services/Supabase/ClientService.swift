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

    /// Creates a new client profile in the `clients` table.
    func createClient(_ payload: ClientInsertDTO) async throws -> ClientDTO {
        return try await client
            .from("clients")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
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
            .in("segment", values: ["gold", "vip", "ultra_vip"])
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
}
