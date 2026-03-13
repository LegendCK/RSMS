//
//  Order.swift
//  infosys2
//
//  SwiftData model for customer orders and POS transactions.
//

import Foundation
import SwiftData

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case processing = "Processing"
    case shipped = "Shipped"
    case delivered = "Delivered"
    case readyForPickup = "Ready for Pickup"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

enum FulfillmentType: String, Codable, CaseIterable {
    case standard = "Standard Delivery"
    case bopis = "Pick Up In Store"
    case shipFromStore = "Ship From Store"
    case inStore = "In-Store Purchase"
}

@Model
final class Order {
    var id: UUID
    var orderNumber: String
    var customerEmail: String
    var statusRaw: String
    var orderItems: String          // JSON: [{productId, productName, qty, unitPrice, serialNumber}]
    var subtotal: Double
    var tax: Double
    var discount: Double
    var total: Double
    var shippingAddress: String     // JSON: {line1, line2, city, state, zip, country}
    var fulfillmentTypeRaw: String
    var paymentMethod: String
    var notes: String
    var salesAssociateEmail: String
    var boutiqueId: String
    var createdAt: Date
    var updatedAt: Date

    var status: OrderStatus {
        get { OrderStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var fulfillmentType: FulfillmentType {
        get { FulfillmentType(rawValue: fulfillmentTypeRaw) ?? .standard }
        set { fulfillmentTypeRaw = newValue.rawValue }
    }

    init(
        orderNumber: String,
        customerEmail: String,
        status: OrderStatus = .pending,
        orderItems: String = "[]",
        subtotal: Double = 0,
        tax: Double = 0,
        discount: Double = 0,
        total: Double = 0,
        shippingAddress: String = "{}",
        fulfillmentType: FulfillmentType = .standard,
        paymentMethod: String = "",
        notes: String = "",
        salesAssociateEmail: String = "",
        boutiqueId: String = ""
    ) {
        self.id = UUID()
        self.orderNumber = orderNumber
        self.customerEmail = customerEmail
        self.statusRaw = status.rawValue
        self.orderItems = orderItems
        self.subtotal = subtotal
        self.tax = tax
        self.discount = discount
        self.total = total
        self.shippingAddress = shippingAddress
        self.fulfillmentTypeRaw = fulfillmentType.rawValue
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.salesAssociateEmail = salesAssociateEmail
        self.boutiqueId = boutiqueId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: total)) ?? "$\(total)"
    }
}
