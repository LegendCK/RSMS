import Foundation
import UIKit

enum InvoicePDFService {
    static func generatePDF(for invoice: InvoiceSnapshot) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let fileName = "Invoice-\(invoice.invoiceNumber.replacingOccurrences(of: "/", with: "-")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let cgContext = context.cgContext

            var y: CGFloat = 28
            let left: CGFloat = 32
            let right: CGFloat = pageRect.width - 32

            func drawText(_ text: String, _ font: UIFont, _ color: UIColor = .black, x: CGFloat = left, y: CGFloat, width: CGFloat = pageRect.width - 64, alignment: NSTextAlignment = .left) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = alignment
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
                let rect = CGRect(x: x, y: y, width: width, height: 100)
                text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
            }

            func row(_ label: String, _ value: String) {
                drawText(label, .systemFont(ofSize: 10, weight: .regular), .darkGray, x: left, y: y, width: 220)
                drawText(value, .systemFont(ofSize: 10, weight: .medium), .black, x: left + 160, y: y, width: right - (left + 160))
                y += 16
            }

            drawText(invoice.storeName, .systemFont(ofSize: 20, weight: .bold), .black, y: y)
            y += 26
            drawText(invoice.storeAddress, .systemFont(ofSize: 10, weight: .regular), .darkGray, y: y)
            y += 32

            drawText("TAX INVOICE", .systemFont(ofSize: 16, weight: .semibold), .black, y: y)
            y += 22

            row("Invoice No", invoice.invoiceNumber)
            row("Order No", invoice.orderNumber)
            row("Issued On", dateTimeString(invoice.issuedAt))
            row("Customer", invoice.customerName)
            row("Email", invoice.customerEmail)
            row("Fulfillment", invoice.fulfillmentLabel)
            row("Payment", invoice.paymentMethod)
            row("Ship To", invoice.shippingAddress)
            y += 10

            cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: left, y: y))
            cgContext.addLine(to: CGPoint(x: right, y: y))
            cgContext.strokePath()
            y += 10

            drawText("Products Purchased", .systemFont(ofSize: 13, weight: .semibold), .black, y: y)
            y += 20

            drawText("Item", .systemFont(ofSize: 10, weight: .semibold), .darkGray, x: left, y: y, width: 260)
            drawText("Qty", .systemFont(ofSize: 10, weight: .semibold), .darkGray, x: left + 270, y: y, width: 40)
            drawText("Unit", .systemFont(ofSize: 10, weight: .semibold), .darkGray, x: left + 320, y: y, width: 90, alignment: .right)
            drawText("Total", .systemFont(ofSize: 10, weight: .semibold), .darkGray, x: left + 415, y: y, width: 140, alignment: .right)
            y += 14

            for item in invoice.items {
                drawText("\(item.brand) \(item.name)", .systemFont(ofSize: 10), .black, x: left, y: y, width: 260)
                drawText("\(item.quantity)", .systemFont(ofSize: 10), .black, x: left + 270, y: y, width: 40)
                drawText(formatCurrency(item.unitPrice, code: invoice.currencyCode), .systemFont(ofSize: 10), .black, x: left + 320, y: y, width: 90, alignment: .right)
                drawText(formatCurrency(item.lineTotal, code: invoice.currencyCode), .systemFont(ofSize: 10), .black, x: left + 415, y: y, width: 140, alignment: .right)
                y += 14
            }

            y += 10
            cgContext.move(to: CGPoint(x: left, y: y))
            cgContext.addLine(to: CGPoint(x: right, y: y))
            cgContext.strokePath()
            y += 12

            drawText("Subtotal", .systemFont(ofSize: 11), .black, x: left + 320, y: y, width: 90, alignment: .right)
            drawText(formatCurrency(invoice.subtotal, code: invoice.currencyCode), .systemFont(ofSize: 11), .black, x: left + 415, y: y, width: 140, alignment: .right)
            y += 14

            drawText("CGST", .systemFont(ofSize: 11), .black, x: left + 320, y: y, width: 90, alignment: .right)
            drawText(formatCurrency(invoice.taxBreakdown.cgst, code: invoice.currencyCode), .systemFont(ofSize: 11), .black, x: left + 415, y: y, width: 140, alignment: .right)
            y += 14

            drawText("SGST", .systemFont(ofSize: 11), .black, x: left + 320, y: y, width: 90, alignment: .right)
            drawText(formatCurrency(invoice.taxBreakdown.sgst, code: invoice.currencyCode), .systemFont(ofSize: 11), .black, x: left + 415, y: y, width: 140, alignment: .right)
            y += 14

            if invoice.taxBreakdown.igst > 0 {
                drawText("IGST", .systemFont(ofSize: 11), .black, x: left + 320, y: y, width: 90, alignment: .right)
                drawText(formatCurrency(invoice.taxBreakdown.igst, code: invoice.currencyCode), .systemFont(ofSize: 11), .black, x: left + 415, y: y, width: 140, alignment: .right)
                y += 14
            }

            if invoice.taxBreakdown.cess > 0 {
                drawText("Cess", .systemFont(ofSize: 11), .black, x: left + 320, y: y, width: 90, alignment: .right)
                drawText(formatCurrency(invoice.taxBreakdown.cess, code: invoice.currencyCode), .systemFont(ofSize: 11), .black, x: left + 415, y: y, width: 140, alignment: .right)
                y += 14
            }

            if invoice.taxBreakdown.other > 0 {
                drawText("Other Tax", .systemFont(ofSize: 11), .black, x: left + 320, y: y, width: 90, alignment: .right)
                drawText(formatCurrency(invoice.taxBreakdown.other, code: invoice.currencyCode), .systemFont(ofSize: 11), .black, x: left + 415, y: y, width: 140, alignment: .right)
                y += 14
            }

            y += 6
            drawText("Grand Total", .systemFont(ofSize: 13, weight: .bold), .black, x: left + 320, y: y, width: 90, alignment: .right)
            drawText(formatCurrency(invoice.total, code: invoice.currencyCode), .systemFont(ofSize: 13, weight: .bold), .black, x: left + 415, y: y, width: 140, alignment: .right)

            drawText(
                "This is a system-generated invoice for customer order history. Keep it for your records.",
                .systemFont(ofSize: 9),
                .darkGray,
                y: pageRect.height - 40,
                width: pageRect.width - 64
            )
        }

        return url
    }

    private static func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatCurrency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(value)"
    }
}
