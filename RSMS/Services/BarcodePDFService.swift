//
//  BarcodePDFService.swift
//  RSMS
//
//  Generates A4 print-ready PDF sheets for barcode stickers.
//  Uses UIGraphicsPDFRenderer to construct a 3-column masonry grid.
//

import Foundation
import UIKit
import PDFKit

final class BarcodePDFService: @unchecked Sendable {
    static let shared = BarcodePDFService()
    
    // Standard A4 dimensions at 72 points per inch (~210x297mm)
    let pageWidth: CGFloat = 595.2
    let pageHeight: CGFloat = 841.8
    
    private init() {}
    
    /// Generates a PDF containing a 3-column grid of barcode stickers.
    /// Returns the local file URL of the generated PDF document.
    func generatePDF(items: [ProductItemDTO], productName: String, brand: String) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "RSMS Application",
            kCGPDFContextAuthor: brand,
            kCGPDFContextTitle: "\(productName) Barcodes"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // Setup bounds for A4
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)_barcodes.pdf")
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                
                // 3 Columns setup
                let columns = 3
                let margin: CGFloat = 30.0
                let cellSpacing: CGFloat = 15.0
                
                let availableWidth = pageWidth - (margin * 2) - (cellSpacing * CGFloat(columns - 1))
                let cellWidth = availableWidth / CGFloat(columns)
                let cellHeight: CGFloat = 120.0
                
                var currentX: CGFloat = margin
                var currentY: CGFloat = margin
                
                // Track when to trigger a new page
                context.beginPage()
                var currentColumn = 0
                
                for item in items {
                    // Check if we need to wrap to the next line
                    if currentColumn >= columns {
                        currentColumn = 0
                        currentX = margin
                        currentY += cellHeight + cellSpacing
                    }
                    
                    // Check if we need a new page
                    if currentY + cellHeight > pageHeight - margin {
                        context.beginPage()
                        currentY = margin
                        currentX = margin
                        currentColumn = 0
                    }
                    
                    // Draw cell content
                    let cellRect = CGRect(x: currentX, y: currentY, width: cellWidth, height: cellHeight)
                    drawSticker(in: cellRect, item: item, productName: productName, brand: brand)
                    
                    // Advance column
                    currentX += cellWidth + cellSpacing
                    currentColumn += 1
                }
            }
            return tempURL
        } catch {
            print("[BarcodePDFService] Failed to generate PDF: \\(error)")
            return nil
        }
    }
    
    private func drawSticker(in rect: CGRect, item: ProductItemDTO, productName: String, brand: String) {
        let context = UIGraphicsGetCurrentContext()
        
        // Draw subtle border for sticker alignment
        context?.setStrokeColor(UIColor.lightGray.withAlphaComponent(0.3).cgColor)
        context?.setLineWidth(0.5)
        context?.stroke(rect)
        
        // Fonts
        let brandFont = UIFont.systemFont(ofSize: 8, weight: .semibold)
        let nameFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let barcodeFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        
        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = .center
        
        // Brand logic
        let brandRect = CGRect(x: rect.minX, y: rect.minY + 10, width: rect.width, height: 12)
        let brandAttrs: [NSAttributedString.Key: Any] = [.font: brandFont, .paragraphStyle: textStyle, .foregroundColor: UIColor.darkGray]
        brand.uppercased().draw(in: brandRect, withAttributes: brandAttrs)
        
        // Product Name logic
        let nameRect = CGRect(x: rect.minX, y: rect.minY + 22, width: rect.width, height: 14)
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .paragraphStyle: textStyle, .foregroundColor: UIColor.black]
        productName.draw(in: nameRect, withAttributes: nameAttrs)
        
        // Barcode Image
        // Generate barcode freshly for printing (on-demand to prevent memory overload natively)
        // A scale of 3 is perfectly sufficient for A4 300dpi without blowing up context size
        if let barcodeImage = BarcodeGeneratorService.shared.generateBarcode(from: item.barcode, scale: 3) {
            let imgSize = barcodeImage.size
            let maxImgWidth = rect.width - 20
            let maxImgHeight: CGFloat = 40
            
            // Aspect fit dimension calculation
            let widthRatio = maxImgWidth / imgSize.width
            let heightRatio = maxImgHeight / imgSize.height
            let minRatio = min(widthRatio, heightRatio)
            
            let finalWidth = imgSize.width * minRatio
            let finalHeight = imgSize.height * minRatio
            
            let imgRect = CGRect(
                x: rect.minX + (rect.width - finalWidth) / 2,
                y: rect.minY + 44,
                width: finalWidth,
                height: finalHeight
            )
            
            barcodeImage.draw(in: imgRect)
        }
        
        // Barcode Text String
        let codeRect = CGRect(x: rect.minX, y: rect.minY + 90, width: rect.width, height: 12)
        let codeAttrs: [NSAttributedString.Key: Any] = [.font: barcodeFont, .paragraphStyle: textStyle, .foregroundColor: UIColor.black]
        item.barcode.draw(in: codeRect, withAttributes: codeAttrs)
    }
}
