//
//  Product.swift
//  infosys2
//
//  SwiftData model for luxury products.
//

import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID
    var name: String
    var brand: String
    var productDescription: String
    var price: Double
    var categoryName: String
    var imageName: String
    var isLimitedEdition: Bool
    var isFeatured: Bool
    var isWishlisted: Bool
    var rating: Double
    var stockCount: Int
    var createdAt: Date

    // MARK: - Identity & Tracking (Phase 1 — SRS compliance)
    var sku: String
    var serialNumber: String
    var barcode: String
    var rfidTagID: String
    var certificateRef: String

    // MARK: - Product Type & Attributes
    var productTypeName: String   // Sub-type within category, e.g. "Engagement Rings"
    var attributes: String        // JSON blob for category-specific data

    // MARK: - Additional Metadata
    var material: String
    var countryOfOrigin: String
    var weight: Double
    var dimensions: String

    init(
        name: String,
        brand: String,
        description: String,
        price: Double,
        categoryName: String,
        imageName: String = "bag.fill",
        isLimitedEdition: Bool = false,
        isFeatured: Bool = false,
        rating: Double = 4.5,
        stockCount: Int = 10,
        sku: String = "",
        serialNumber: String = "",
        barcode: String = "",
        rfidTagID: String = "",
        certificateRef: String = "",
        productTypeName: String = "",
        attributes: String = "{}",
        material: String = "",
        countryOfOrigin: String = "",
        weight: Double = 0,
        dimensions: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.productDescription = description
        self.price = price
        self.categoryName = categoryName
        self.imageName = imageName
        self.isLimitedEdition = isLimitedEdition
        self.isFeatured = isFeatured
        self.isWishlisted = false
        self.rating = rating
        self.stockCount = stockCount
        self.createdAt = Date()
        self.sku = sku
        self.serialNumber = serialNumber
        self.barcode = barcode
        self.rfidTagID = rfidTagID
        self.certificateRef = certificateRef
        self.productTypeName = productTypeName
        self.attributes = attributes
        self.material = material
        self.countryOfOrigin = countryOfOrigin
        self.weight = weight
        self.dimensions = dimensions
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    /// Parses the `attributes` JSON string into a dictionary.
    var parsedAttributes: [String: String] {
        guard let data = attributes.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return dict
    }
}
