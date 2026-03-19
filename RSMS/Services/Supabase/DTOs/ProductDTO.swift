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
    let name: String
    let brand: String?
    let categoryId: UUID?
    let collectionId: UUID?
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
        case name
        case brand
        case categoryId    = "category_id"
        case collectionId  = "collection_id"
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

    /// Normalized image URLs that can be rendered by SwiftUI.
    /// Supports:
    /// - fully qualified URLs
    /// - `/storage/v1/object/public/...` paths
    /// - `storage/v1/object/public/...` paths
    /// - `/object/public/...` paths
    /// - `object/public/...` paths
    /// - `product-images/...` bucket-prefixed paths
    /// - raw object paths like `products/{id}/1.jpg` (assumes `product-images` bucket)
    var resolvedImageURLs: [URL] {
        (imageUrls ?? []).compactMap { raw in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }

            // Absolute URL
            if let absolute = URL(string: value), absolute.scheme != nil {
                return absolute
            }

            let base = SupabaseConfig.projectURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // Path that already includes storage public prefix
            if value.hasPrefix("/storage/v1/object/public/") {
                return URL(string: "\(base)\(value)")
            }
            if value.hasPrefix("storage/v1/object/public/") {
                return URL(string: "\(base)/\(value)")
            }
            if value.hasPrefix("/object/public/") {
                return URL(string: "\(base)/storage/v1\(value)")
            }
            if value.hasPrefix("object/public/") {
                return URL(string: "\(base)/storage/v1/\(value)")
            }

            // Bucket-prefixed object path, e.g. `product-images/products/<id>/1.jpg`
            if value.hasPrefix("product-images/") {
                let pathOnly = String(value.dropFirst("product-images/".count))
                let encoded = pathOnly.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pathOnly
                return URL(string: "\(base)/storage/v1/object/public/product-images/\(encoded)")
            }

            // Raw object path in `product-images` bucket
            let encodedPath = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
            return URL(string: "\(base)/storage/v1/object/public/product-images/\(encodedPath)")
        }
    }

    /// Formatted price string in INR.
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: price)) ?? "INR \(price)"
    }
}

// MARK: - Insert Payload

struct ProductInsertDTO: Codable {
    let sku: String
    let name: String
    let brand: String?
    let categoryId: UUID?
    let collectionId: UUID?
    let taxCategoryId: UUID?
    let description: String?
    let price: Double
    let costPrice: Double?
    let imageUrls: [String]?
    let isActive: Bool
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case sku, name, brand, description, price
        case categoryId    = "category_id"
        case collectionId  = "collection_id"
        case taxCategoryId = "tax_category_id"
        case costPrice     = "cost_price"
        case imageUrls     = "image_urls"
        case isActive      = "is_active"
        case createdBy     = "created_by"
    }
}

// MARK: - Update Payload

struct ProductUpdateDTO: Codable {
    let sku: String
    let name: String
    let brand: String?
    let categoryId: UUID?
    let collectionId: UUID?
    let description: String?
    let price: Double
    let costPrice: Double?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case sku, name, brand, description, price
        case categoryId = "category_id"
        case collectionId = "collection_id"
        case costPrice = "cost_price"
        case isActive = "is_active"
    }
}
