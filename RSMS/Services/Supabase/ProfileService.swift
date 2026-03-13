//
//  ProfileService.swift
//  RSMS
//
//  Handles authenticated customer profile reads/updates from public.clients.
//

import Foundation
import Supabase

@MainActor
final class ProfileService {

    static let shared = ProfileService()
    private let client = SupabaseManager.shared.client

    private init() {}

    /// Loads the currently authenticated user's client profile.
    func fetchMyClientProfile() async throws -> ClientDTO {
        let session = try await client.auth.session

        return try await client
            .from("clients")
            .select()
            .eq("id", value: session.user.id.uuidString)
            .single()
            .execute()
            .value
    }

    /// Updates the currently authenticated user's client profile.
    func updateMyClientProfile(_ payload: ClientUpdateDTO) async throws -> ClientDTO {
        let session = try await client.auth.session

        return try await client
            .from("clients")
            .update(payload)
            .eq("id", value: session.user.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}
