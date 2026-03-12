//
//  TaxDTO.swift
//  infosys2
//
//  Codable DTOs matching the Supabase `tax_categories` and `tax_rates` tables exactly.
//
//  tax_categories columns: id, name, description, created_at
//  tax_rates columns: id, tax_category_id, country, rate, label, is_active, created_at, updated_at
//

import Foundation

// MARK: - TaxCategoryDTO

struct TaxCategoryDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
    }
}

// MARK: - TaxRateDTO

struct TaxRateDTO: Codable, Identifiable {
    let id: UUID
    let taxCategoryId: UUID
    let country: String             // ISO alpha-2, e.g. "US", "FR", "JP"
    let rate: Double                // e.g. 8.875 for 8.875%
    let label: String?              // e.g. "NY Sales Tax", "TVA", "Consumption Tax"
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case taxCategoryId = "tax_category_id"
        case country
        case rate
        case label
        case isActive      = "is_active"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    // MARK: - Convenience

    var ratePercent: String { String(format: "%.3g%%", rate) }

    /// Calculates tax amount for a given subtotal.
    func taxAmount(for subtotal: Double) -> Double {
        subtotal * (rate / 100.0)
    }
}

// MARK: - Insert Payloads

struct TaxCategoryInsertDTO: Codable {
    let name: String
    let description: String?
}

struct TaxRateInsertDTO: Codable {
    let taxCategoryId: UUID
    let country: String
    let rate: Double
    let label: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case taxCategoryId = "tax_category_id"
        case country, rate, label
        case isActive      = "is_active"
    }
}
