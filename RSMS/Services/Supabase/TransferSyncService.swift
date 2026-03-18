//
//  TransferSyncService.swift
//  RSMS
//
//  Syncs transfer receipt updates to Supabase `transfers`.
//

import Foundation
import Supabase

enum TransferSyncServiceError: LocalizedError {
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .syncFailed(let details):
            return "Transfer sync failed: \(details)"
        }
    }
}

@MainActor
final class TransferSyncService {
    static let shared = TransferSyncService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func syncReceipt(for transfer: Transfer) async throws {
        let richPayload = TransferUpsertDTO(transfer: transfer)
        do {
            try await client
                .from("transfers")
                .upsert(richPayload, onConflict: "id")
                .execute()
            return
        } catch {
            let richError = error.localizedDescription

            let minimalPayload = TransferMinimalUpsertDTO(transfer: transfer)
            do {
                try await client
                    .from("transfers")
                    .upsert(minimalPayload, onConflict: "id")
                    .execute()
                return
            } catch {
                let minimalError = error.localizedDescription

                let patchPayload = TransferReceiptPatchDTO(transfer: transfer)
                do {
                    try await client
                        .from("transfers")
                        .update(patchPayload)
                        .eq("id", value: transfer.id.uuidString)
                        .execute()
                    return
                } catch {
                    let patchError = error.localizedDescription
                    throw TransferSyncServiceError.syncFailed("rich upsert: \(richError); minimal upsert: \(minimalError); patch: \(patchError)")
                }
            }
        }
    }
}