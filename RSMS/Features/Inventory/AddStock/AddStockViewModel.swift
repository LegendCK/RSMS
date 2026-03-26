//
//  AddStockViewModel.swift
//  RSMS
//
//  MVVM ViewModel for the InventoryAddStockView.
//  Drives product selection, quantity entry, and the createStock call.
//

import SwiftUI
import Supabase

// MARK: - Add Stock State
//
// NOT Equatable: the success case carries [ProductItemDTO] which doesn't
// conform to Equatable. canSubmit uses pattern matching instead.

enum AddStockState {
    case idle
    case loading
    case success(count: Int, items: [ProductItemDTO])
    case failure(String)
}

// MARK: - AddStockViewModel

private struct AddStockInventoryRow: Decodable, Sendable {
    let quantity: Int
}

@Observable
@MainActor
final class AddStockViewModel {

    // MARK: - Input

    var selectedProduct: ProductDTO? = nil
    var quantity: Int = 1

    // MARK: - Output

    var state: AddStockState = .idle

    // MARK: - Derived

    var canSubmit: Bool {
        guard selectedProduct != nil else { return false }
        if case .loading = state { return false }
        return quantity >= 1 && quantity <= 500
    }

    // MARK: - Dependencies
    // Assigned lazily in init to avoid referencing StockService.shared
    // from a default parameter value — which would be a nonisolated context.

    private let service: StockServiceProtocol

    init(service: StockServiceProtocol? = nil) {
        self.service = service ?? StockService.shared
    }

    // MARK: - Actions

    /// storeId: the IC's assigned store — used to update the aggregated `inventory` table.
    func createStock(storeId: UUID?) async {
        guard let product = selectedProduct else { return }
        state = .loading

        do {
            // 1. Create serialized product_items rows via RPC, stamped with the IC's store
            let items = try await service.createStock(productId: product.id, quantity: quantity, storeId: storeId)

            // 2. Increment the aggregated `inventory` table so stock counts update instantly
            if let sid = storeId {
                await incrementInventoryTable(productId: product.id, storeId: sid, addedQty: items.count)
            }

            // 3. Notify all listening views to re-sync from Supabase
            NotificationCenter.default.post(name: .inventoryStockUpdated, object: nil)

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                state = .success(count: items.count, items: items)
            }
        } catch {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                state = .failure(error.localizedDescription)
            }
        }
    }

    // MARK: - Private: Upsert inventory table

    private func incrementInventoryTable(productId: UUID, storeId: UUID, addedQty: Int) async {
        let client = SupabaseManager.shared.client
        do {
            let rows: [AddStockInventoryRow] = try await client
                .from("inventory")
                .select("quantity")
                .eq("location_id", value: storeId.uuidString.lowercased())
                .eq("product_id", value: productId.uuidString.lowercased())
                .execute()
                .value

            let currentQty = rows.first?.quantity ?? 0
            let newQty     = currentQty + addedQty

            let payload: [String: AnyJSON] = [
                "location_id": .string(storeId.uuidString.lowercased()),
                "product_id": .string(productId.uuidString.lowercased()),
                "quantity": .integer(newQty)
            ]

            try await client
                .from("inventory")
                .upsert(payload, onConflict: "location_id,product_id")
                .execute()

            print("[AddStockVM] inventory updated: \(productId) qty \(currentQty) → \(newQty)")
        } catch {
            // Non-fatal — local sync will correct on next pull-to-refresh
            print("[AddStockVM] inventory upsert failed (non-fatal): \(error.localizedDescription)")
        }
    }

    func reset() {
        selectedProduct = nil
        quantity        = 1
        state           = .idle
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let inventoryStockUpdated = Notification.Name("inventoryStockUpdated")
}
