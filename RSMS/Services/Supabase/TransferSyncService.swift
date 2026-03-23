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
        if Task.isCancelled { throw CancellationError() }

        let richPayload = TransferUpsertDTO(transfer: transfer)
        do {
            try await client
                .from("transfers")
                .upsert(richPayload, onConflict: "id")
                .execute()
            return
        } catch {
            let richError = error.localizedDescription

            let minimalPayload = TransferSchemaSafeUpsertDTO(transfer: transfer)
            do {
                try await client
                    .from("transfers")
                    .upsert(minimalPayload, onConflict: "id")
                    .execute()
                return
            } catch {
                let minimalError = error.localizedDescription

                let legacyPayload = TransferLegacyUpsertDTO(transfer: transfer)
                do {
                    try await client
                        .from("transfers")
                        .upsert(legacyPayload, onConflict: "id")
                        .execute()
                    return
                } catch {
                    let legacyError = error.localizedDescription

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

                        // Last-chance fallback for legacy schemas that only allow status updates.
                        let statusOnly = TransferStatusPatchDTO(transfer: transfer)
                        do {
                            try await client
                                .from("transfers")
                                .update(statusOnly)
                                .eq("id", value: transfer.id.uuidString)
                                .execute()
                            return
                        } catch {
                            let statusError = error.localizedDescription
                            throw TransferSyncServiceError.syncFailed(
                                "rich upsert: \(richError); schema-safe upsert: \(minimalError); legacy upsert: \(legacyError); patch: \(patchError); status-only: \(statusError)"
                            )
                        }
                    }
                }
            }
        }
    }
}
