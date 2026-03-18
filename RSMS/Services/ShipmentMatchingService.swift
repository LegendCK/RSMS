//
//  ShipmentMatchingService.swift
//  RSMS
//
//  Validates incoming shipment receipts against ASN-linked transfer records.
//

import Foundation
import SwiftData

struct ShipmentMatchResult {
    let transferId: UUID
    let asnNumber: String
    let expectedQuantity: Int
    let receivedThisCheck: Int
    let cumulativeReceivedQuantity: Int
    let missingQuantity: Int
    let extraQuantity: Int
    let isPartial: Bool
    let warnings: [String]

    var isFullyMatched: Bool {
        missingQuantity == 0
    }
}

enum ShipmentMatchingError: LocalizedError {
    case transferCancelled
    case quantityMustBePositive
    case transferNotReceivable(TransferStatus)

    var errorDescription: String? {
        switch self {
        case .transferCancelled:
            return "This shipment is cancelled and cannot be received."
        case .quantityMustBePositive:
            return "Received quantity must be greater than zero."
        case .transferNotReceivable(let status):
            return "Shipment cannot be matched while transfer is in status: \(status.rawValue)."
        }
    }
}

@MainActor
final class ShipmentMatchingService {
    static let shared = ShipmentMatchingService()

    private init() {}

    func processIncomingShipment(
        transfer: Transfer,
        receivedThisCheck: Int,
        receiverEmail: String,
        modelContext: ModelContext
    ) async throws -> ShipmentMatchResult {
        if transfer.status == .cancelled {
            throw ShipmentMatchingError.transferCancelled
        }

        if receivedThisCheck <= 0 {
            throw ShipmentMatchingError.quantityMustBePositive
        }

        let receivableStatuses: Set<TransferStatus> = [
            .approved,
            .picking,
            .packed,
            .inTransit,
            .partiallyReceived,
            .delivered
        ]

        if !receivableStatuses.contains(transfer.status) {
            throw ShipmentMatchingError.transferNotReceivable(transfer.status)
        }

        let previousReceived = max(transfer.receivedQuantity, 0)
        let expected = transfer.expectedQuantity
        let cumulativeReceived = previousReceived + receivedThisCheck
        let missing = max(expected - cumulativeReceived, 0)
        let extra = max(cumulativeReceived - expected, 0)

        transfer.receivedQuantity = cumulativeReceived
        transfer.receivedByEmail = receiverEmail
        transfer.lastReceivedAt = Date()
        transfer.updatedAt = Date()
        transfer.status = missing > 0 ? .partiallyReceived : .delivered

        var warnings: [String] = []
        warnings.append(contentsOf: applyInventoryAdjustments(for: transfer, delta: receivedThisCheck, modelContext: modelContext))

        if extra > 0 {
            appendNote(
                transfer: transfer,
                line: "[\(timestamp())] Over-receipt detected vs ASN \(transfer.asnNumber): +\(extra) units over expected."
            )
        } else if missing > 0 {
            appendNote(
                transfer: transfer,
                line: "[\(timestamp())] Partial receipt vs ASN \(transfer.asnNumber): \(missing) units still pending."
            )
        } else {
            appendNote(
                transfer: transfer,
                line: "[\(timestamp())] ASN \(transfer.asnNumber) fully matched and verified."
            )
        }

        try modelContext.save()
        warnings.append(contentsOf: await syncToSupabase(transfer: transfer, modelContext: modelContext))

        return ShipmentMatchResult(
            transferId: transfer.id,
            asnNumber: transfer.asnNumber,
            expectedQuantity: expected,
            receivedThisCheck: receivedThisCheck,
            cumulativeReceivedQuantity: cumulativeReceived,
            missingQuantity: missing,
            extraQuantity: extra,
            isPartial: missing > 0,
            warnings: warnings
        )
    }

    private func syncToSupabase(transfer: Transfer, modelContext: ModelContext) async -> [String] {
        var warnings: [String] = []

        do {
            try await TransferSyncService.shared.syncReceipt(for: transfer)
        } catch {
            warnings.append("Supabase transfer sync failed: \(error.localizedDescription)")
        }

        guard let inventoryRow = inventoryRowForTransfer(transfer, modelContext: modelContext) else {
            return warnings
        }

        do {
            _ = try await InventorySyncService.shared.upsertInventory(inventoryRow)
        } catch {
            warnings.append("Supabase inventory sync failed: \(error.localizedDescription)")
        }

        return warnings
    }

    private func applyInventoryAdjustments(
        for transfer: Transfer,
        delta: Int,
        modelContext: ModelContext
    ) -> [String] {
        var warnings: [String] = []

        let products = (try? modelContext.fetch(FetchDescriptor<Product>())) ?? []
        let productById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        let product: Product?
        if let exact = productById[transfer.productId] {
            product = exact
        } else {
            product = products.first {
                !$0.name.isEmpty && $0.name.caseInsensitiveCompare(transfer.productName) == .orderedSame
            }
            if product == nil {
                warnings.append("No matching Product record found for this transfer; stock totals were not updated.")
            }
        }

        guard let product else {
            return warnings
        }

        product.stockCount += delta

        let storeId = resolveStoreId(for: transfer, modelContext: modelContext)
        guard let storeId else {
            warnings.append("Destination store could not be resolved from toBoutiqueId=\(transfer.toBoutiqueId); per-location inventory was not updated.")
            return warnings
        }

        let inventoryRows = (try? modelContext.fetch(FetchDescriptor<InventoryByLocation>())) ?? []
        if let row = inventoryRows.first(where: { $0.locationId == storeId && $0.productId == product.id }) {
            row.quantity += delta
            row.updatedAt = Date()
        } else {
            let created = InventoryByLocation(
                locationId: storeId,
                productId: product.id,
                sku: product.sku.isEmpty ? product.id.uuidString : product.sku,
                productName: product.name,
                categoryName: product.categoryName,
                quantity: delta,
                reorderPoint: 2,
                updatedAt: Date()
            )
            modelContext.insert(created)
        }

        return warnings
    }

    private func resolveStoreId(for transfer: Transfer, modelContext: ModelContext) -> UUID? {
        if let id = UUID(uuidString: transfer.toBoutiqueId) {
            return id
        }

        let stores = (try? modelContext.fetch(FetchDescriptor<StoreLocation>())) ?? []
        return stores.first { $0.code.caseInsensitiveCompare(transfer.toBoutiqueId) == .orderedSame }?.id
    }

    private func inventoryRowForTransfer(_ transfer: Transfer, modelContext: ModelContext) -> InventoryByLocation? {
        guard let storeId = resolveStoreId(for: transfer, modelContext: modelContext) else {
            return nil
        }

        let inventoryRows = (try? modelContext.fetch(FetchDescriptor<InventoryByLocation>())) ?? []
        if let exact = inventoryRows.first(where: { $0.locationId == storeId && $0.productId == transfer.productId }) {
            return exact
        }

        guard !transfer.productName.isEmpty else {
            return nil
        }

        return inventoryRows.first {
            $0.locationId == storeId &&
            $0.productName.caseInsensitiveCompare(transfer.productName) == .orderedSame
        }
    }

    private func appendNote(transfer: Transfer, line: String) {
        let trimmed = transfer.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        transfer.notes = trimmed.isEmpty ? line : "\(trimmed)\n\(line)"
    }

    private func timestamp() -> String {
        Date().formatted(date: .abbreviated, time: .shortened)
    }
}
