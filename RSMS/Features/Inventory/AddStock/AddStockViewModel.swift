//
//  AddStockViewModel.swift
//  RSMS
//
//  MVVM ViewModel for the InventoryAddStockView.
//  Drives product selection, quantity entry, and the createStock call.
//

import SwiftUI

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

    func createStock() async {
        guard let product = selectedProduct else { return }
        state = .loading

        do {
            let items = try await service.createStock(productId: product.id, quantity: quantity)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                state = .success(count: items.count, items: items)
            }
        } catch {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                state = .failure(error.localizedDescription)
            }
        }
    }

    func reset() {
        selectedProduct = nil
        quantity        = 1
        state           = .idle
    }
}
