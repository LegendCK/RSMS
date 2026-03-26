//
//  StoreSyncService.swift
//  RSMS
//
//  Syncs StoreLocation between local SwiftData and Supabase `stores`.
//

import Foundation
import SwiftData
import Supabase

@MainActor
final class StoreSyncService {
    static let shared = StoreSyncService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func syncStores(modelContext: ModelContext) async throws {
        try await pushLocalStores(modelContext: modelContext)
        try await pullRemoteStores(modelContext: modelContext)
    }

    func upsertStore(_ location: StoreLocation) async throws -> StoreDTO {
        // Resolve code conflict first
        if let existingId = try await findStoreId(byCode: location.code), existingId != location.id {
            location.id = existingId
        }

        struct InsertPayload: Encodable {
            let id: UUID
            let name: String
        }

        let payload = InsertPayload(id: location.id, name: location.name)

        let dto: StoreDTO = try await client
            .from("stores")
            .upsert(payload, onConflict: "id")
            .select("id, name, code, address, city, country, is_active")
            .single()
            .execute()
            .value

        return dto
    }

    func deleteStore(id: UUID) async throws {
        try await client
            .from("stores")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Fetches active boutique stores for customer appointment booking.
    func fetchActiveBoutiques() async throws -> [StoreDTO] {
        return try await client
            .from("stores")
            .select("id, name, code, address, city, country, is_active")
            .eq("is_active", value: true)
            .eq("type", value: "boutique")
            .order("name", ascending: true)
            .execute()
            .value
    }

    /// Fetches stores by ids.
    func fetchStores(ids: [UUID]) async throws -> [StoreDTO] {
        let uniqueIds = Array(Set(ids))
        guard !uniqueIds.isEmpty else { return [] }

        return try await client
            .from("stores")
            .select("id, name, code, address, city, country, is_active")
            .in("id", values: uniqueIds.map { $0.uuidString.lowercased() })
            .execute()
            .value
    }

    private func pushLocalStores(modelContext: ModelContext) async throws {
        let locals = try deduplicatedLocals(modelContext: modelContext)
        for location in locals {
            _ = try await upsertStore(location)
        }
    }

    private func pullRemoteStores(modelContext: ModelContext) async throws {
        let remote: [StoreDTO] = try await client
            .from("stores")
            .select("id, name, code, address, city, country, is_active")
            .execute()
            .value

        let locals = try deduplicatedLocals(modelContext: modelContext)
        var byId: [UUID: StoreLocation] = [:]
        for local in locals {
            byId[local.id] = local
        }

        for store in remote {
            if let existing = byId[store.id] {
                apply(store, to: existing)
            } else {
                let created = makeLocation(from: store)
                modelContext.insert(created)
                byId[created.id] = created
            }
        }

        try? modelContext.save()
    }

    private func deduplicatedLocals(modelContext: ModelContext) throws -> [StoreLocation] {
        let locals = (try? modelContext.fetch(FetchDescriptor<StoreLocation>())) ?? []
        guard !locals.isEmpty else { return [] }

        let byNewest = locals.sorted { $0.updatedAt > $1.updatedAt }

        var seenIDs = Set<UUID>()
        var seenCodes = Set<String>()
        var kept: [StoreLocation] = []

        for location in byNewest {
            let normalizedCode = location.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let duplicateID = seenIDs.contains(location.id)
            let duplicateCode = !normalizedCode.isEmpty && seenCodes.contains(normalizedCode)

            if duplicateID || duplicateCode {
                modelContext.delete(location)
                continue
            }

            seenIDs.insert(location.id)
            if !normalizedCode.isEmpty { seenCodes.insert(normalizedCode) }
            kept.append(location)
        }

        try? modelContext.save()
        return kept
    }

    private func findStoreId(byCode code: String) async throws -> UUID? {
        // Because StoreDTO only has id and name, we use a custom struct to decode
        struct PartialStore: Decodable { let id: UUID }
        
        let rows: [PartialStore] = try await client
            .from("stores")
            .select("id")
            .eq("code", value: code)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    private func apply(_ dto: StoreDTO, to location: StoreLocation) {
        location.name = dto.name
        if let code = dto.code, !code.isEmpty { location.code = code }
        if let address = dto.address { location.addressLine1 = address }
        if let city = dto.city, !city.isEmpty { location.city = city }
        if !dto.country.isEmpty { location.country = dto.country }
        location.isOperational = dto.isActive
    }

    private func makeLocation(from dto: StoreDTO) -> StoreLocation {
        let location = StoreLocation(
            code: dto.code ?? "BTQ-\(dto.id.uuidString.prefix(8))".uppercased(),
            name: dto.name,
            type: .boutique,
            addressLine1: dto.address ?? "",
            city: dto.city ?? "",
            stateProvince: "",
            postalCode: "",
            country: dto.country,
            region: dto.city ?? "Unassigned",
            managerName: "—",
            capacityUnits: 0,
            monthlySalesTarget: 300_000,
            isOperational: dto.isActive
        )
        location.id = dto.id
        return location
    }
}
