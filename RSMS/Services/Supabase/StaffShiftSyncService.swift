//
//  StaffShiftSyncService.swift
//  RSMS
//
//  Syncs StaffShift between local SwiftData and Supabase `staff_shifts`.
//

import Foundation
import SwiftData
import Supabase

@MainActor
final class StaffShiftSyncService {
    static let shared = StaffShiftSyncService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func syncShifts(modelContext: ModelContext, storeId: UUID?) async throws {
        guard let storeId else { return }

        let remote: [StaffShiftDTO] = try await client
            .from("staff_shifts")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("start_at", ascending: true)
            .execute()
            .value

        let locals = (try? modelContext.fetch(FetchDescriptor<StaffShift>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })

        for dto in remote {
            if let local = byId[dto.id] {
                apply(dto, to: local)
            } else {
                let shift = makeShift(from: dto)
                modelContext.insert(shift)
                byId[shift.id] = shift
            }
        }

        // Keep local cache authoritative for the current store only.
        let remoteIds = Set(remote.map { $0.id })
        for local in locals where local.storeId == storeId {
            if !remoteIds.contains(local.id) {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
    }

    func createShift(
        storeId: UUID,
        staffUserId: UUID,
        startAt: Date,
        endAt: Date,
        notes: String?
    ) async throws -> StaffShiftDTO {
        let payload = StaffShiftInsertDTO(
            id: UUID(),
            staffUserId: staffUserId,
            storeId: storeId,
            startAt: startAt,
            endAt: endAt,
            notes: notes
        )

        let dto: StaffShiftDTO = try await client
            .from("staff_shifts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return dto
    }

    func updateShift(
        id: UUID,
        staffUserId: UUID,
        startAt: Date,
        endAt: Date,
        notes: String?
    ) async throws -> StaffShiftDTO {
        let payload = StaffShiftUpdateDTO(
            staffUserId: staffUserId,
            startAt: startAt,
            endAt: endAt,
            notes: notes
        )

        let dto: StaffShiftDTO = try await client
            .from("staff_shifts")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return dto
    }

    func applyToLocal(_ dto: StaffShiftDTO, modelContext: ModelContext) {
        let locals = (try? modelContext.fetch(FetchDescriptor<StaffShift>())) ?? []
        if let existing = locals.first(where: { $0.id == dto.id }) {
            apply(dto, to: existing)
        } else {
            modelContext.insert(makeShift(from: dto))
        }

        try? modelContext.save()
    }

    private func makeShift(from dto: StaffShiftDTO) -> StaffShift {
        let shift = StaffShift(
            staffUserId: dto.staffUserId,
            storeId: dto.storeId,
            startAt: dto.startAt,
            endAt: dto.endAt,
            notes: dto.notes ?? ""
        )
        shift.id = dto.id
        shift.createdAt = dto.createdAt
        shift.updatedAt = dto.updatedAt
        return shift
    }

    private func apply(_ dto: StaffShiftDTO, to shift: StaffShift) {
        shift.staffUserId = dto.staffUserId
        shift.storeId = dto.storeId
        shift.startAt = dto.startAt
        shift.endAt = dto.endAt
        shift.notes = dto.notes ?? ""
        shift.createdAt = dto.createdAt
        shift.updatedAt = dto.updatedAt
    }
}
