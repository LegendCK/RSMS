//
//  ShippingDocumentService.swift
//  RSMS
//
//  Generates packing slip / shipping document PDFs for ship-from-store orders.
//  Follows the same pattern as InvoicePDFService.
//

import Foundation
import UIKit

// MARK: - Shipping Document Data Model

struct ShippingDocumentItem {
    let name: String
    let brand: String
    let sku: String
    let quantity: Int
    let unitPrice: Double

    var lineTotal: Double { unitPrice * Double(quantity) }
}

struct ShippingDocument: Identifiable {
    let id: UUID
    let orderNumber: String
    let orderId: UUID
    let createdAt: Date
    let customerName: String
    let customerEmail: String
    let shippingAddress: String
    let originStoreName: String
    let originStoreAddress: String
    let fulfillmentType: String
    let items: [ShippingDocumentItem]
    let totalQuantity: Int
    let notes: String
}

// MARK: - PDF Generator

enum ShippingDocumentService {

    static func generatePDF(for doc: ShippingDocument) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let fileName = "PackingSlip-\(doc.orderNumber.replacingOccurrences(of: "/", with: "-")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let cgContext = context.cgContext

            var y: CGFloat = 28
            let left: CGFloat = 32
            let right: CGFloat = pageRect.width - 32

            // MARK: Helpers

            func drawText(_ text: String, _ font: UIFont, _ color: UIColor = .black,
                          x: CGFloat = left, y: CGFloat, width: CGFloat = pageRect.width - 64,
                          alignment: NSTextAlignment = .left) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = alignment
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
                let rect = CGRect(x: x, y: y, width: width, height: 100)
                text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                          attributes: attrs, context: nil)
            }

            func separator() {
                cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
                cgContext.setLineWidth(1)
                cgContext.move(to: CGPoint(x: left, y: y))
                cgContext.addLine(to: CGPoint(x: right, y: y))
                cgContext.strokePath()
                y += 12
            }

            func row(_ label: String, _ value: String) {
                drawText(label, .systemFont(ofSize: 10, weight: .regular), .darkGray,
                         x: left, y: y, width: 160)
                drawText(value, .systemFont(ofSize: 10, weight: .medium), .black,
                         x: left + 160, y: y, width: right - (left + 160))
                y += 16
            }

            // MARK: Header

            drawText("PACKING SLIP", .systemFont(ofSize: 22, weight: .bold), .black, y: y)
            y += 30

            drawText(doc.originStoreName, .systemFont(ofSize: 14, weight: .semibold), .black, y: y)
            y += 18
            drawText(doc.originStoreAddress, .systemFont(ofSize: 10, weight: .regular), .darkGray, y: y)
            y += 24

            separator()

            // MARK: Order Info

            row("Order Number", doc.orderNumber)
            row("Order Date", dateTimeString(doc.createdAt))
            row("Fulfillment", doc.fulfillmentType)
            row("Customer", doc.customerName)
            row("Email", doc.customerEmail)
            y += 4

            // MARK: Ship To

            drawText("SHIP TO", .systemFont(ofSize: 11, weight: .semibold), .darkGray, y: y)
            y += 16
            drawText(doc.shippingAddress, .systemFont(ofSize: 10, weight: .medium), .black, y: y)
            y += 28

            separator()

            // MARK: Items Table Header

            drawText("ITEMS TO PACK", .systemFont(ofSize: 13, weight: .semibold), .black, y: y)
            y += 22

            drawText("Product", .systemFont(ofSize: 10, weight: .semibold), .darkGray,
                     x: left, y: y, width: 220)
            drawText("SKU", .systemFont(ofSize: 10, weight: .semibold), .darkGray,
                     x: left + 230, y: y, width: 100)
            drawText("Qty", .systemFont(ofSize: 10, weight: .semibold), .darkGray,
                     x: left + 340, y: y, width: 50, alignment: .center)
            drawText("Price", .systemFont(ofSize: 10, weight: .semibold), .darkGray,
                     x: left + 400, y: y, width: 130, alignment: .right)
            y += 16

            // MARK: Item Rows

            for item in doc.items {
                // Check for page overflow
                if y > pageRect.height - 100 {
                    context.beginPage()
                    y = 28
                }

                let label = item.brand.isEmpty ? item.name : "\(item.brand) — \(item.name)"
                drawText(label, .systemFont(ofSize: 10), .black,
                         x: left, y: y, width: 220)
                drawText(item.sku, .systemFont(ofSize: 9), .darkGray,
                         x: left + 230, y: y, width: 100)
                drawText("\(item.quantity)", .systemFont(ofSize: 10), .black,
                         x: left + 340, y: y, width: 50, alignment: .center)
                drawText(formatCurrency(item.lineTotal), .systemFont(ofSize: 10), .black,
                         x: left + 400, y: y, width: 130, alignment: .right)
                y += 16
            }

            y += 8
            separator()

            // MARK: Totals Row

            drawText("Total Items: \(doc.totalQuantity)", .systemFont(ofSize: 12, weight: .bold),
                     .black, y: y)
            y += 20

            // MARK: Notes

            if !doc.notes.isEmpty {
                y += 8
                drawText("Notes:", .systemFont(ofSize: 10, weight: .semibold), .darkGray, y: y)
                y += 14
                drawText(doc.notes, .systemFont(ofSize: 10), .black, y: y)
            }

            // MARK: Footer

            drawText(
                "This packing slip was automatically generated by RSMS. Please verify all items before sealing.",
                .systemFont(ofSize: 9),
                .darkGray,
                y: pageRect.height - 40,
                width: pageRect.width - 64
            )
        }

        return url
    }

    // MARK: - Build from Order

    static func buildDocument(from order: Order, storeName: String, storeAddress: String) -> ShippingDocument {
        let items = parseOrderItems(order.orderItems)
        let totalQty = items.reduce(0) { $0 + $1.quantity }

        let address: String = {
            guard let data = order.shippingAddress.data(using: .utf8),
                  let addr = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                return "Address on file"
            }
            let line1 = addr["line1"] ?? ""
            let city = addr["city"] ?? ""
            let state = addr["state"] ?? ""
            let zip = addr["zip"] ?? ""
            let country = addr["country"] ?? ""
            if line1.isEmpty { return "Address on file" }
            return "\(line1)\n\(city), \(state) \(zip)\n\(country)"
        }()

        return ShippingDocument(
            id: order.id,
            orderNumber: order.orderNumber,
            orderId: order.id,
            createdAt: order.createdAt,
            customerName: order.customerEmail.split(separator: "@").first.map { $0.split(separator: ".").map { $0.capitalized }.joined(separator: " ") } ?? "Customer",
            customerEmail: order.customerEmail,
            shippingAddress: address,
            originStoreName: storeName,
            originStoreAddress: storeAddress,
            fulfillmentType: order.fulfillmentType.rawValue,
            items: items,
            totalQuantity: totalQty,
            notes: order.notes
        )
    }

    // MARK: - Private

    private static func parseOrderItems(_ json: String) -> [ShippingDocumentItem] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.map { dict in
            ShippingDocumentItem(
                name: dict["name"] as? String ?? "Product",
                brand: dict["brand"] as? String ?? "",
                sku: (dict["sku"] as? String) ?? "",
                quantity: dict["qty"] as? Int ?? 1,
                unitPrice: dict["price"] as? Double ?? 0
            )
        }
    }

    private static func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }
}
