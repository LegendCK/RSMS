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
    let rate: Double                // Stored as decimal: 0.28 = 28%, 0.18 = 18%
    let label: String?              // e.g. "GST 28%", "NY Sales Tax", "TVA"
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

    /// Rate as percentage string (e.g., "28%" for rate=0.28)
    var ratePercent: String { String(format: "%.0f%%", rate * 100) }

    /// Calculates tax amount for a given subtotal.
    /// Rate is stored as decimal (0.28 = 28%), so multiply directly.
    func taxAmount(for subtotal: Double) -> Double {
        subtotal * rate
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
