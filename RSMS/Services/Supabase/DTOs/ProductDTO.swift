//
//  ProductDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `products` table exactly.
//  Columns: id, sku, barcode, name, brand, category_id, tax_category_id,
//           description, price, cost_price, image_urls, is_active,
//           created_by, created_at, updated_at
//

import Foundation

struct ProductDTO: Codable, Identifiable {
    let id: UUID
    let sku: String
    let barcode: String?
    let name: String
    let brand: String?
    let categoryId: UUID?
    let taxCategoryId: UUID?
    let description: String?
    let price: Double
    let costPrice: Double?
    let imageUrls: [String]?        // Array of Supabase Storage public URLs
    let isActive: Bool
    let createdBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sku
        case barcode
        case name
        case brand
        case categoryId    = "category_id"
        case taxCategoryId = "tax_category_id"
        case description
        case price
        case costPrice     = "cost_price"
        case imageUrls     = "image_urls"
        case isActive      = "is_active"
        case createdBy     = "created_by"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    // MARK: - Convenience

    /// First image URL, or nil if none uploaded yet.
    var primaryImageUrl: String? { imageUrls?.first }

    /// Formatted price string in USD.
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
}

// MARK: - Insert Payload

struct ProductInsertDTO: Codable {
    let sku: String
    let barcode: String?
    let name: String
    let brand: String?
    let categoryId: UUID?
    let taxCategoryId: UUID?
    let description: String?
    let price: Double
    let costPrice: Double?
    let imageUrls: [String]?
    let isActive: Bool
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case sku, barcode, name, brand, description, price
        case categoryId    = "category_id"
        case taxCategoryId = "tax_category_id"
        case costPrice     = "cost_price"
        case imageUrls     = "image_urls"
        case isActive      = "is_active"
        case createdBy     = "created_by"
    }
}
