//
//  HandoverDocumentService.swift
//  RSMS
//
//  Generates a PDF handover document for a completed repair ticket.
//  Follows the same UIGraphicsPDFRenderer pattern as InvoicePDFService.
//

import Foundation
import UIKit

struct HandoverDocumentData {
    let ticketNumber: String
    let ticketType: String
    let clientName: String
    let clientEmail: String
    let clientPhone: String?
    let productName: String
    let productSKU: String
    let productBrand: String?
    let storeName: String
    let storeAddress: String?
    let repairSummary: String       // from ticket.notes + conditionNotes
    let estimatedCost: Double?
    let finalCost: Double?
    let currency: String
    let partsUsed: [HandoverPartLine]
    let pickupScheduledAt: Date?
    let generatedAt: Date
    let specialistName: String
}

struct HandoverPartLine {
    let name: String
    let sku: String
    let quantity: Int
}

enum HandoverDocumentService {

    static func generate(data: HandoverDocumentData) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let safe = data.ticketNumber.replacingOccurrences(of: "/", with: "-")
        let fileName = "Handover-\(safe).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext

            let left: CGFloat  = 40
            let right: CGFloat = pageRect.width - 40
            var y: CGFloat     = 36

            // ─── Helpers ────────────────────────────────────────────────────

            func drawText(
                _ text: String,
                _ font: UIFont,
                _ color: UIColor = .black,
                x: CGFloat = left,
                width: CGFloat = pageRect.width - 80,
                alignment: NSTextAlignment = .left
            ) {
                let ps = NSMutableParagraphStyle()
                ps.alignment = alignment
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: ps
                ]
                let rect = CGRect(x: x, y: y, width: width, height: 200)
                text.draw(with: rect,
                           options: [.usesLineFragmentOrigin, .usesFontLeading],
                           attributes: attrs,
                           context: nil)
            }

            func drawLine() {
                cg.setStrokeColor(UIColor.systemGray4.cgColor)
                cg.setLineWidth(0.75)
                cg.move(to: CGPoint(x: left, y: y))
                cg.addLine(to: CGPoint(x: right, y: y))
                cg.strokePath()
                y += 10
            }

            func row(_ label: String, _ value: String) {
                drawText(label, .systemFont(ofSize: 10, weight: .regular), .darkGray,
                         x: left, width: 180)
                drawText(value, .systemFont(ofSize: 10, weight: .medium), .black,
                         x: left + 190, width: right - (left + 190))
                y += 16
            }

            // ─── Header ─────────────────────────────────────────────────────

            drawText(data.storeName, .systemFont(ofSize: 18, weight: .bold))
            y += 22
            if let addr = data.storeAddress {
                drawText(addr, .systemFont(ofSize: 9), .darkGray)
                y += 14
            }

            // Gold accent bar
            cg.setFillColor(UIColor(red: 0.72, green: 0.57, blue: 0.28, alpha: 1).cgColor)
            cg.fill(CGRect(x: left, y: y, width: right - left, height: 2))
            y += 10

            drawText("REPAIR HANDOVER DOCUMENT", .systemFont(ofSize: 14, weight: .semibold))
            y += 20

            // ─── Ticket Info ─────────────────────────────────────────────────

            drawText("TICKET DETAILS", .systemFont(ofSize: 10, weight: .semibold), .darkGray)
            y += 14
            row("Ticket Number",  data.ticketNumber)
            row("Service Type",   data.ticketType)
            row("Specialist",     data.specialistName)
            row("Generated On",   formatDate(data.generatedAt))
            y += 4
            drawLine()

            // ─── Client ──────────────────────────────────────────────────────

            drawText("CLIENT", .systemFont(ofSize: 10, weight: .semibold), .darkGray)
            y += 14
            row("Name",  data.clientName)
            row("Email", data.clientEmail)
            if let phone = data.clientPhone { row("Phone", phone) }
            y += 4
            drawLine()

            // ─── Product ─────────────────────────────────────────────────────

            drawText("PRODUCT", .systemFont(ofSize: 10, weight: .semibold), .darkGray)
            y += 14
            if let brand = data.productBrand { row("Brand", brand) }
            row("Name", data.productName)
            row("SKU",  data.productSKU)
            y += 4
            drawLine()

            // ─── Repair Summary ──────────────────────────────────────────────

            drawText("REPAIR SUMMARY", .systemFont(ofSize: 10, weight: .semibold), .darkGray)
            y += 14

            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]
            let summaryRect = CGRect(x: left, y: y, width: right - left, height: 200)
            data.repairSummary.draw(with: summaryRect,
                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                    attributes: summaryAttrs,
                                    context: nil)
            let summarySize = (data.repairSummary as NSString)
                .boundingRect(with: CGSize(width: right - left, height: 200),
                              options: [.usesLineFragmentOrigin, .usesFontLeading],
                              attributes: summaryAttrs,
                              context: nil)
            y += summarySize.height + 10
            drawLine()

            // ─── Parts Used ──────────────────────────────────────────────────

            if !data.partsUsed.isEmpty {
                drawText("SPARE PARTS USED", .systemFont(ofSize: 10, weight: .semibold), .darkGray)
                y += 14

                drawText("Part Name",  .systemFont(ofSize: 9, weight: .semibold), .darkGray, x: left, width: 260)
                drawText("SKU",        .systemFont(ofSize: 9, weight: .semibold), .darkGray, x: left + 270, width: 120)
                drawText("Qty",        .systemFont(ofSize: 9, weight: .semibold), .darkGray, x: left + 400, width: 60, alignment: .right)
                y += 13

                for part in data.partsUsed {
                    drawText(part.name, .systemFont(ofSize: 9), .black, x: left,        width: 260)
                    drawText(part.sku,  .systemFont(ofSize: 9), .black, x: left + 270,  width: 120)
                    drawText("\(part.quantity)", .systemFont(ofSize: 9), .black, x: left + 400, width: 60, alignment: .right)
                    y += 13
                }
                y += 4
                drawLine()
            }

            // ─── Cost ────────────────────────────────────────────────────────

            drawText("COST SUMMARY", .systemFont(ofSize: 10, weight: .semibold), .darkGray)
            y += 14
            if let est = data.estimatedCost {
                row("Estimated Cost", formatCurrency(est, code: data.currency))
            }
            if let fin = data.finalCost {
                row("Final Cost", formatCurrency(fin, code: data.currency))
            } else if data.estimatedCost == nil {
                row("Cost", "To be advised")
            }
            y += 4
            drawLine()

            // ─── Pickup ──────────────────────────────────────────────────────

            drawText("PICKUP DETAILS", .systemFont(ofSize: 10, weight: .semibold), .darkGray)
            y += 14
            if let pickup = data.pickupScheduledAt {
                row("Scheduled Pickup", formatDateTime(pickup))
            } else {
                row("Pickup", "To be scheduled")
            }
            y += 4
            drawLine()

            // ─── Signature block ─────────────────────────────────────────────

            y += 10
            drawText("Client Signature", .systemFont(ofSize: 9), .darkGray, x: left, width: 200)
            drawText("Date", .systemFont(ofSize: 9), .darkGray, x: right - 140, width: 140)
            y += 30

            cg.setStrokeColor(UIColor.systemGray3.cgColor)
            cg.setLineWidth(0.5)
            // Signature line
            cg.move(to: CGPoint(x: left, y: y))
            cg.addLine(to: CGPoint(x: left + 200, y: y))
            // Date line
            cg.move(to: CGPoint(x: right - 140, y: y))
            cg.addLine(to: CGPoint(x: right, y: y))
            cg.strokePath()
            y += 20

            // ─── Footer ──────────────────────────────────────────────────────

            drawText("Thank you for choosing \(data.storeName). Please retain this document for your records.",
                     .systemFont(ofSize: 8), .systemGray,
                     alignment: .center)
        }

        return url
    }

    // MARK: - Helpers

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private static func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private static func formatCurrency(_ amount: Double, code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: amount)) ?? "\(code) \(String(format: "%.2f", amount))"
    }
}
