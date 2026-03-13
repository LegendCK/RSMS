//
//  CartViewModel.swift
//  infosys2
//
//  Observable cart manager — handles CartItem CRUD, totals, and order creation.
//

import Foundation
import SwiftData

@Observable
class CartViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext
    private(set) var customerEmail: String

    // MARK: - State

    private(set) var cartItems: [CartItem] = []
    private(set) var isLoading = false

    // MARK: - Computed

    var itemCount: Int { cartItems.reduce(0) { $0 + $1.quantity } }
    var subtotal: Double { cartItems.reduce(0) { $0 + $1.lineTotal } }
    var taxRate: Double { 0.08 }
    var tax: Double { subtotal * taxRate }
    var total: Double { subtotal + tax }
    var isEmpty: Bool { cartItems.isEmpty }

    var formattedSubtotal: String { formatCurrency(subtotal) }
    var formattedTax: String { formatCurrency(tax) }
    var formattedTotal: String { formatCurrency(total) }

    // MARK: - Init

    init(modelContext: ModelContext, customerEmail: String) {
        self.modelContext = modelContext
        self.customerEmail = customerEmail
        fetchCartItems()
    }

    // MARK: - CRUD

    func fetchCartItems() {
        let email = customerEmail
        let descriptor = FetchDescriptor<CartItem>(
            predicate: #Predicate<CartItem> { $0.customerEmail == email },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        cartItems = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addToCart(product: Product, quantity: Int = 1) {
        // Check if product already in cart — increment quantity
        if let existing = cartItems.first(where: { $0.productId == product.id }) {
            existing.quantity += quantity
        } else {
            let item = CartItem(
                customerEmail: customerEmail,
                productId: product.id,
                productName: product.name,
                productImageName: product.imageName,
                productBrand: product.brand,
                unitPrice: product.price,
                quantity: quantity
            )
            modelContext.insert(item)
        }
        save()
        fetchCartItems()
    }

    func removeFromCart(_ item: CartItem) {
        modelContext.delete(item)
        save()
        fetchCartItems()
    }

    func updateQuantity(_ item: CartItem, quantity: Int) {
        if quantity <= 0 {
            removeFromCart(item)
        } else {
            item.quantity = quantity
            save()
            fetchCartItems()
        }
    }

    func clearCart() {
        for item in cartItems {
            modelContext.delete(item)
        }
        save()
        fetchCartItems()
    }

    // MARK: - Order Creation

    func createOrder(
        fulfillmentType: FulfillmentType,
        paymentMethod: String,
        shippingAddress: String = "",
        notes: String = ""
    ) -> Order {
        // Generate order number
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        let year = dateFormatter.string(from: Date())
        let random = String(format: "%04d", Int.random(in: 1000...9999))
        let orderNumber = "ML-ORD-\(year)-\(random)"

        // Serialize cart items to JSON
        let itemsArray: [[String: Any]] = cartItems.map { item in
            [
                "name": item.productName,
                "brand": item.productBrand,
                "qty": item.quantity,
                "price": item.unitPrice,
                "image": item.productImageName
            ]
        }
        let itemsJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: itemsArray),
           let str = String(data: data, encoding: .utf8) {
            itemsJSON = str
        } else {
            itemsJSON = "[]"
        }

        let order = Order(
            orderNumber: orderNumber,
            customerEmail: customerEmail,
            status: .confirmed,
            orderItems: itemsJSON,
            subtotal: subtotal,
            tax: tax,
            total: total,
            shippingAddress: shippingAddress,
            fulfillmentType: fulfillmentType,
            paymentMethod: paymentMethod,
            notes: notes
        )
        modelContext.insert(order)

        // Clear cart
        clearCart()

        return order
    }

    // MARK: - Helpers

    private func save() {
        try? modelContext.save()
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
