//
//  SalesLooksService.swift
//  RSMS
//
//  Supabase service for Sales Associate curated lookbooks.
//

import Foundation
import Supabase

@MainActor
final class SalesLooksService {
    static let shared = SalesLooksService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func fetchLooks(storeId: UUID) async throws -> [SalesLookDTO] {
        try await client
            .from("sales_looks")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createLook(
        storeId: UUID,
        creatorId: UUID,
        creatorName: String,
        name: String,
        productIds: [UUID],
        thumbnailSource: String?,
        isShared: Bool
    ) async throws -> SalesLookDTO {
        let payload = SalesLookInsertDTO(
            storeId: storeId,
            creatorId: creatorId,
            creatorName: creatorName,
            name: name,
            productIds: productIds,
            thumbnailSource: thumbnailSource,
            isShared: isShared
        )

        return try await client
            .from("sales_looks")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }
}
