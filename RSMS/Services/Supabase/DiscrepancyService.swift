//
//  DiscrepancyService.swift
//  RSMS
//
//  Supabase operations for the inventory discrepancy approval flow.
//  Managers can fetch pending discrepancies, approve (which updates inventory)
//  or reject. All actions are logged in inventory_discrepancy_logs.
//

import Foundation
import Supabase
import SwiftData

// MARK: - Discrepancy Error

enum DiscrepancyError: LocalizedError {
    case discrepancyNotFound
    case alreadyProcessed
    case rejectionRequiresNotes
    case inventoryRecordMissing
    case unknownFailure(String)

    var errorDescription: String? {
        switch self {
        case .discrepancyNotFound:
            return "The discrepancy record could not be found."
        case .alreadyProcessed:
            return "This discrepancy has already been approved or rejected."
        case .rejectionRequiresNotes:
            return "Manager notes are required when rejecting a discrepancy."
        case .inventoryRecordMissing:
            return "No inventory record found for this product at this store. Inventory could not be updated."
        case .unknownFailure(let detail):
            return "An unexpected error occurred: \(detail)"
        }
    }
}

// MARK: - Service

@MainActor
final class DiscrepancyService {
    static let shared = DiscrepancyService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Fetch

    /// Fetches all discrepancies for a given store, newest-first.
    func fetchDiscrepancies(storeId: UUID) async throws -> [InventoryDiscrepancyDTO] {
        let rows: [InventoryDiscrepancyDTO] = try await client
            .from("inventory_discrepancies")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    // MARK: - Submit (Staff)

    /// Submits a new discrepancy from a staff member.
    func submitDiscrepancy(dto: DiscrepancyInsertDTO) async throws -> InventoryDiscrepancyDTO {
        let result: InventoryDiscrepancyDTO = try await client
            .from("inventory_discrepancies")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        // Insert a "submitted" log entry
        let log = DiscrepancyLogInsertDTO(
            discrepancyId: result.id,
            action:        "submitted",
            actorId:       dto.reportedBy,
            actorName:     dto.reportedByName,
            notes:         dto.reason,
            oldQuantity:   dto.systemQuantity,
            newQuantity:   nil
        )
        _ = try? await insertLog(log)

        return result
    }

    // MARK: - Approve

    /// Approves a discrepancy:
    ///   1. Validates it is still pending
    ///   2. PATCH status → "approved"
    ///   3. UPSERT inventory.quantity = reportedQuantity
    ///   4. INSERT audit log
    func approve(
        discrepancy: InventoryDiscrepancyDTO,
        reviewedBy:  UUID,
        reviewerName: String,
        modelContext: ModelContext
    ) async throws {
        guard discrepancy.status == DiscrepancyStatus.pending.rawValue else {
            throw DiscrepancyError.alreadyProcessed
        }

        let updateDTO = DiscrepancyUpdateDTO(
            status:       DiscrepancyStatus.approved.rawValue,
            reviewedBy:   reviewedBy,
            managerNotes: nil
        )

        // 1. Update the discrepancy record
        try await client
            .from("inventory_discrepancies")
            .update(updateDTO)
            .eq("id", value: discrepancy.id.uuidString.lowercased())
            .execute()

        // 2. Upsert inventory quantity
        let inventoryPayload = InventoryApprovalUpsertDTO(
            storeId:   discrepancy.storeId,
            productId: discrepancy.productId,
            quantity:  discrepancy.reportedQuantity
        )

        try await client
            .from("inventory")
            .upsert(inventoryPayload, onConflict: "store_id,product_id")
            .execute()

        // 3. Update local SwiftData (best-effort)
        updateLocalInventory(
            storeId:     discrepancy.storeId,
            productId:   discrepancy.productId,
            newQuantity: discrepancy.reportedQuantity,
            modelContext: modelContext
        )

        // 4. Audit log
        let log = DiscrepancyLogInsertDTO(
            discrepancyId: discrepancy.id,
            action:        "approved",
            actorId:       reviewedBy,
            actorName:     reviewerName,
            notes:         "Inventory adjusted from \(discrepancy.systemQuantity) to \(discrepancy.reportedQuantity)",
            oldQuantity:   discrepancy.systemQuantity,
            newQuantity:   discrepancy.reportedQuantity
        )
        _ = try? await insertLog(log)
    }

    // MARK: - Reject

    /// Rejects a discrepancy. Manager notes are required.
    func reject(
        discrepancy: InventoryDiscrepancyDTO,
        reviewedBy:  UUID,
        reviewerName: String,
        notes: String
    ) async throws {
        guard discrepancy.status == DiscrepancyStatus.pending.rawValue else {
            throw DiscrepancyError.alreadyProcessed
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else {
            throw DiscrepancyError.rejectionRequiresNotes
        }

        let updateDTO = DiscrepancyUpdateDTO(
            status:       DiscrepancyStatus.rejected.rawValue,
            reviewedBy:   reviewedBy,
            managerNotes: trimmedNotes
        )

        try await client
            .from("inventory_discrepancies")
            .update(updateDTO)
            .eq("id", value: discrepancy.id.uuidString.lowercased())
            .execute()

        // Audit log — inventory unchanged
        let log = DiscrepancyLogInsertDTO(
            discrepancyId: discrepancy.id,
            action:        "rejected",
            actorId:       reviewedBy,
            actorName:     reviewerName,
            notes:         trimmedNotes,
            oldQuantity:   discrepancy.systemQuantity,
            newQuantity:   nil
        )
        _ = try? await insertLog(log)
    }

    // MARK: - Helpers

    private func insertLog(_ log: DiscrepancyLogInsertDTO) async throws {
        try await client
            .from("inventory_discrepancy_logs")
            .insert(log)
            .execute()
    }

    /// Patches the local SwiftData InventoryByLocation record so the UI
    /// reflects the approved quantity without waiting for a full sync.
    private func updateLocalInventory(
        storeId:      UUID,
        productId:    UUID,
        newQuantity:  Int,
        modelContext: ModelContext
    ) {
        let predicate = #Predicate<InventoryByLocation> {
            $0.locationId == storeId && $0.productId == productId
        }
        if let record = try? modelContext.fetch(FetchDescriptor<InventoryByLocation>(predicate: predicate)).first {
            record.quantity  = newQuantity
            record.updatedAt = Date()
            try? modelContext.save()
        }

        // Also update Product.stockCount (used by InvStockSubview)
        let productPredicate = #Predicate<Product> { $0.id == productId }
        if let product = try? modelContext.fetch(FetchDescriptor<Product>(predicate: productPredicate)).first {
            product.stockCount = newQuantity
            try? modelContext.save()
        }
    }
}

// MARK: - Inventory Approval Upsert DTO

private struct InventoryApprovalUpsertDTO: Codable {
    let storeId:   UUID
    let productId: UUID
    let quantity:  Int

    enum CodingKeys: String, CodingKey {
        case storeId   = "store_id"
        case productId = "product_id"
        case quantity
    }
}
