//
//  SupabaseManager.swift
//  RSMS
//
//  Singleton manager for the Supabase client instance with auth configuration.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        // Configure Supabase client
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
