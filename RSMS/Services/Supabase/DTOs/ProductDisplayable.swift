//
//  ProductDisplayable.swift
//  infosys2
//
//  Shared display protocol so ProductDetailView works with both
//  the local SwiftData `Product` and the remote `ProductDTO`.
//
//  Place inside: Services/Supabase/DTOs/
//

import Foundation

// MARK: - Protocol

protocol ProductDisplayable {
    var displayName: String { get }
    var displayBrand: String { get }
    var displayDescription: String { get }
    var displayPrice: String { get }
    var displaySKU: String { get }
    var displayMaterial: String { get }
    var displayOrigin: String { get }
    var displayProductType: String { get }
    var displayIsLimitedEdition: Bool { get }
    var displayIsActive: Bool { get }
    var displayRating: Double { get }
    var displayStockCount: Int { get }
    var displayAttributes: [String: String] { get }
    /// Remote image URLs from Supabase Storage. Empty until synced.
    var displayImageURLs: [URL] { get }
    /// SF Symbol fallback when no remote image exists.
    var displayFallbackIcon: String { get }
}

// MARK: - SwiftData Product conformance

extension Product: ProductDisplayable {
    var displayName: String                 { name }
    var displayBrand: String                { brand }
    var displayDescription: String          { productDescription }
    var displayPrice: String                { formattedPrice }
    var displaySKU: String                  { sku }
    var displayMaterial: String             { material }
    var displayOrigin: String               { countryOfOrigin }
    var displayProductType: String          { productTypeName }
    var displayIsLimitedEdition: Bool       { isLimitedEdition }
    var displayIsActive: Bool               { true }
    var displayRating: Double               { rating }
    var displayStockCount: Int              { stockCount }
    var displayAttributes: [String: String] { parsedAttributes }
    var displayImageURLs: [URL]             { [] }
    var displayFallbackIcon: String         { imageName }
}

// MARK: - Remote ProductDTO conformance
// ProductDTO is already defined in ProductDTO.swift — this just adds display helpers.

extension ProductDTO: ProductDisplayable {
    var displayName: String                 { name }
    var displayBrand: String                { brand ?? "" }
    var displayDescription: String          { description ?? "" }
    var displayPrice: String                { formattedPrice }
    var displaySKU: String                  { sku }
    var displayMaterial: String             { "" }
    var displayOrigin: String               { "" }
    var displayProductType: String          { "" }
    var displayIsLimitedEdition: Bool       { false }
    var displayIsActive: Bool               { isActive }
    var displayRating: Double               { 0 }
    var displayStockCount: Int              { isActive ? 1 : 0 }
    var displayAttributes: [String: String] { [:] }
    var displayImageURLs: [URL]             { imageUrls?.compactMap { URL(string: $0) } ?? [] }
    var displayFallbackIcon: String         { "bag.fill" }
}
