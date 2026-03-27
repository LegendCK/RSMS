//
//  ScanResultDTO.swift
//  RSMS
//
//  UI-facing result assembled from a ProductItemDTO + embedded ProductDTO.
//  Returned by ScanService after a successful barcode lookup.
//

import Foundation

struct ScanResultDTO: Codable {
    let productName: String
    let sku: String
    let price: Double
    let itemStatus: String      // ProductItemStatus raw value
    let barcode: String
    let brand: String?
    let imageUrls: [String]?

    // MARK: Convenience

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0 // Remove unnecessary ".00"
        
        let lakhs = price / 100000.0
        if lakhs >= 1.0 {
            let str = String(format: "₹%.1fL", lakhs).replacingOccurrences(of: ".0L", with: "L")
            return str
        }
        
        return formatter.string(from: NSNumber(value: price)) ?? "₹\(Int(price))"
    }

    var itemStatusEnum: ProductItemStatus {
        ProductItemStatus(rawValue: itemStatus) ?? .inStock
    }

    // MARK: - Init from ProductItemDTO

    init(from item: ProductItemDTO) {
        self.barcode    = item.barcode
        self.itemStatus = item.status
        let p           = item.products
        self.productName = p?.name  ?? "Unknown Product"
        self.sku         = p?.sku   ?? ""
        self.price       = p?.price ?? 0
        self.brand       = p?.brand
        self.imageUrls   = p?.imageUrls
    }
}
