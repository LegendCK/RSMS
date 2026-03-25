//
//  SACartItem.swift
//  RSMS
//
//  Lightweight in-memory cart item for the SA POS flow.
//  Not persisted to SwiftData — lives only for the duration of one sale session.
//

import Foundation

struct SACartItem: Identifiable {
    let id: UUID
    let productId: UUID
    let productName: String
    let productBrand: String
    let unitPrice: Double
    let imageURL: URL?
    let selectedColor: String?
    let selectedSize: String?
    var quantity: Int

    var lineTotal: Double { unitPrice * Double(quantity) }

    var formattedUnitPrice: String { formatCurrency(unitPrice) }
    var formattedLineTotal: String { formatCurrency(lineTotal) }

    /// Human-readable variant label, e.g. "Noir · M"
    var variantLabel: String? {
        let parts = [selectedColor, selectedSize].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    init(
        productId: UUID,
        productName: String,
        productBrand: String,
        unitPrice: Double,
        imageURL: URL? = nil,
        selectedColor: String? = nil,
        selectedSize: String? = nil,
        quantity: Int = 1
    ) {
        self.id           = UUID()
        self.productId    = productId
        self.productName  = productName
        self.productBrand = productBrand
        self.unitPrice    = unitPrice
        self.imageURL     = imageURL
        self.selectedColor = selectedColor
        self.selectedSize  = selectedSize
        self.quantity     = quantity
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle  = .currency
        f.currencyCode = "INR"
        return f.string(from: NSNumber(value: v)) ?? "₹\(v)"
    }
}
