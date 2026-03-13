//
//  StoreSyncService.swift
//  infosys2
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
        let payload = StoreInsertDTO(
            id: location.id,
            code: location.code,
            name: location.name,
            type: location.type == .boutique ? "boutique" : "distribution_center",
            country: location.country,
            city: location.city,
            address: location.addressLine1,
            currency: inferredCurrency(for: location.country),
            timezone: inferredTimeZone(for: location.country),
            region: location.region,
            managerName: location.managerName,
            capacityUnits: location.capacityUnits,
            isActive: location.isOperational
        )

        let dto: StoreDTO = try await client
            .from("stores")
            .upsert(payload, onConflict: "id")
            .select()
            .single()
            .execute()
            .value

        return dto
    }

    private func pushLocalStores(modelContext: ModelContext) async throws {
        let locals = (try? modelContext.fetch(FetchDescriptor<StoreLocation>())) ?? []
        for location in locals {
            _ = try await upsertStore(location)
        }
    }

    private func pullRemoteStores(modelContext: ModelContext) async throws {
        let remote: [StoreDTO] = try await client
            .from("stores")
            .select()
            .execute()
            .value

        let locals = (try? modelContext.fetch(FetchDescriptor<StoreLocation>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })

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

    private func apply(_ dto: StoreDTO, to location: StoreLocation) {
        location.code = dto.code ?? location.code
        location.name = dto.name
        location.type = dto.type == "distribution_center" ? .distributionCenter : .boutique
        location.country = dto.country
        location.city = dto.city ?? location.city
        location.addressLine1 = dto.address ?? location.addressLine1
        location.region = dto.region ?? location.region
        location.managerName = dto.managerName ?? location.managerName
        location.capacityUnits = dto.capacityUnits ?? location.capacityUnits
        location.isOperational = dto.isActive
        location.updatedAt = dto.updatedAt
    }

    private func makeLocation(from dto: StoreDTO) -> StoreLocation {
        let type: LocationType = dto.type == "distribution_center" ? .distributionCenter : .boutique
        let location = StoreLocation(
            code: dto.code ?? fallbackCode(for: dto),
            name: dto.name,
            type: type,
            addressLine1: dto.address ?? "",
            city: dto.city ?? "",
            stateProvince: "",
            postalCode: "",
            country: dto.country,
            region: dto.region ?? "Unassigned",
            managerName: dto.managerName ?? "—",
            capacityUnits: dto.capacityUnits ?? 0,
            isOperational: dto.isActive
        )
        location.id = dto.id
        location.createdAt = dto.createdAt
        location.updatedAt = dto.updatedAt
        return location
    }

    private func fallbackCode(for dto: StoreDTO) -> String {
        let prefix = dto.type == "distribution_center" ? "DC" : "BTQ"
        return "\(prefix)-\(dto.id.uuidString.prefix(8))".uppercased()
    }

    private func inferredCurrency(for country: String) -> String {
        switch country.uppercased() {
        case "USA", "US":
            return "USD"
        case "FRANCE", "ITALY", "FR", "IT":
            return "EUR"
        case "JAPAN", "JP":
            return "JPY"
        default:
            return "USD"
        }
    }

    private func inferredTimeZone(for country: String) -> String {
        switch country.uppercased() {
        case "USA", "US":
            return "America/New_York"
        case "FRANCE", "ITALY", "FR", "IT":
            return "Europe/Paris"
        case "JAPAN", "JP":
            return "Asia/Tokyo"
        default:
            return "UTC"
        }
    }
}
