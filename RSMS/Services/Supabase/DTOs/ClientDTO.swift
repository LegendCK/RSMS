//
//  ClientDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `clients` table exactly.
//  Columns: id, first_name, last_name, email, phone, date_of_birth,
//           nationality, preferred_language, address_line1, address_line2,
//           city, state, postal_code, country, segment, notes,
//           gdpr_consent, marketing_opt_in, created_by,
//           is_active, created_at, updated_at
//

import Foundation

struct ClientDTO: Codable, Identifiable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let dateOfBirth: String?        // "YYYY-MM-DD" date string from Supabase
    let nationality: String?        // ISO alpha-2 country code
    let preferredLanguage: String?  // e.g. "en", "fr", "ja"
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?            // ISO alpha-2 country code
    let segment: String?            // "standard" | "gold" | "platinum" | "prive"
    let notes: String?
    let gdprConsent: Bool
    let marketingOptIn: Bool
    let createdBy: UUID?            // FK to users.id (the associate who created)
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firstName       = "first_name"
        case lastName        = "last_name"
        case email
        case phone
        case dateOfBirth     = "date_of_birth"
        case nationality
        case preferredLanguage = "preferred_language"
        case addressLine1    = "address_line1"
        case addressLine2    = "address_line2"
        case city
        case state
        case postalCode      = "postal_code"
        case country
        case segment
        case notes
        case gdprConsent     = "gdpr_consent"
        case marketingOptIn  = "marketing_opt_in"
        case createdBy       = "created_by"
        case isActive        = "is_active"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
    }

    // MARK: - Convenience

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String { "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased() }
}

// MARK: - Insert Payload

struct ClientInsertDTO: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let dateOfBirth: String?
    let nationality: String?
    let preferredLanguage: String?
    let addressLine1: String?
    let city: String?
    let country: String?
    let segment: String
    let notes: String?
    let gdprConsent: Bool
    let marketingOptIn: Bool
    let createdBy: UUID?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case firstName      = "first_name"
        case lastName       = "last_name"
        case email, phone
        case dateOfBirth    = "date_of_birth"
        case nationality
        case preferredLanguage = "preferred_language"
        case addressLine1   = "address_line1"
        case city, country, segment, notes
        case gdprConsent    = "gdpr_consent"
        case marketingOptIn = "marketing_opt_in"
        case createdBy      = "created_by"
        case isActive       = "is_active"
    }
}
