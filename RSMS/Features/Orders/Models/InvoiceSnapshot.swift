import Foundation

struct InvoiceLineItem: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let quantity: Int
    let unitPrice: Double

    var lineTotal: Double { unitPrice * Double(quantity) }
}

struct InvoiceTaxBreakdown {
    let cgst: Double
    let sgst: Double
    let igst: Double
    let cess: Double
    let other: Double

    var total: Double { cgst + sgst + igst + cess + other }
}

struct InvoiceSnapshot {
    let invoiceNumber: String
    let orderNumber: String
    let issuedAt: Date
    let customerName: String
    let customerEmail: String
    let storeName: String
    let storeAddress: String
    let shippingAddress: String
    let fulfillmentLabel: String
    let paymentMethod: String
    let currencyCode: String
    let items: [InvoiceLineItem]
    let subtotal: Double
    let discountTotal: Double
    let taxBreakdown: InvoiceTaxBreakdown
    let total: Double
    let isTaxFree: Bool
    let taxFreeReason: String
}
