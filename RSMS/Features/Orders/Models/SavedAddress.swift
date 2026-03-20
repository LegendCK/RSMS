//
//  SavedAddress.swift
//  RSMS
//
//  SwiftData model for customer saved shipping addresses.
//

import Foundation
import SwiftData

@Model
final class SavedAddress {
    var id: UUID
    var customerEmail: String
    var label: String          // "Home", "Work", "Other"
    var line1: String
    var line2: String
    var city: String
    var state: String
    var zip: String
    var country: String
    var isDefault: Bool
    var createdAt: Date

    init(
        customerEmail: String,
        label: String = "Home",
        line1: String = "",
        line2: String = "",
        city: String = "",
        state: String = "",
        zip: String = "",
        country: String = "IN",
        isDefault: Bool = false
    ) {
        self.id            = UUID()
        self.customerEmail = customerEmail
        self.label         = label
        self.line1         = line1
        self.line2         = line2
        self.city          = city
        self.state         = state
        self.zip           = zip
        self.country       = country
        self.isDefault     = isDefault
        self.createdAt     = Date()
    }

    /// One-line summary for display in pickers and cards.
    var shortSummary: String {
        [line1, city, state].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Full formatted multi-line address.
    var fullAddress: String {
        var parts: [String] = [line1]
        if !line2.isEmpty { parts.append(line2) }
        parts.append("\(city), \(state) \(zip)")
        parts.append(country)
        return parts.joined(separator: "\n")
    }
}
