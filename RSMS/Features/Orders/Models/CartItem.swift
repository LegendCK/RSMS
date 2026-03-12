//
//  CartItem.swift
//  infosys2
//
//  SwiftData model for shopping cart items.
//

import Foundation
import SwiftData

@Model
final class CartItem {
    var id: UUID
    var customerEmail: String
    var productId: UUID
    var productName: String
    var productImageName: String
    var productBrand: String
    var unitPrice: Double
    var quantity: Int
    var addedAt: Date

    init(
        customerEmail: String,
        productId: UUID,
        productName: String,
        productImageName: String = "bag.fill",
        productBrand: String = "Maison Luxe",
        unitPrice: Double,
        quantity: Int = 1
    ) {
        self.id = UUID()
        self.customerEmail = customerEmail
        self.productId = productId
        self.productName = productName
        self.productImageName = productImageName
        self.productBrand = productBrand
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.addedAt = Date()
    }

    var lineTotal: Double {
        unitPrice * Double(quantity)
    }

    var formattedLineTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: lineTotal)) ?? "$\(lineTotal)"
    }
}
