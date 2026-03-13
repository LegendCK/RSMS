//
//  ClientProfile.swift
//  infosys2
//
//  SwiftData model for clienteling — rich client profiles used by Sales Associates.
//

import Foundation
import SwiftData

enum VIPTier: String, Codable, CaseIterable {
    case standard = "Standard"
    case gold = "Gold"
    case platinum = "Platinum"
    case prive = "Privé"
}

@Model
final class ClientProfile {
    var id: UUID
    var customerEmail: String
    var customerName: String
    var customerPhone: String
    var preferredCategories: String  // JSON array: ["Jewellery","Watches"]
    var sizes: String               // JSON: {"ring":"6","wrist":"16cm","dress":"S","shoe":"38"}
    var anniversaries: String       // JSON array: [{"label":"Wedding","date":"2024-11-15"}]
    var notes: String
    var vipTierRaw: String
    var assignedAssociateEmail: String
    var lifetimeSpend: Double
    var visitCount: Int
    var lastVisitDate: Date?
    var privacyConsentGiven: Bool
    var createdAt: Date
    var updatedAt: Date

    var vipTier: VIPTier {
        get { VIPTier(rawValue: vipTierRaw) ?? .standard }
        set { vipTierRaw = newValue.rawValue }
    }

    init(
        customerEmail: String,
        customerName: String,
        customerPhone: String = "",
        preferredCategories: String = "[]",
        sizes: String = "{}",
        anniversaries: String = "[]",
        notes: String = "",
        vipTier: VIPTier = .standard,
        assignedAssociateEmail: String = "",
        lifetimeSpend: Double = 0,
        visitCount: Int = 0,
        lastVisitDate: Date? = nil,
        privacyConsentGiven: Bool = true
    ) {
        self.id = UUID()
        self.customerEmail = customerEmail
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.preferredCategories = preferredCategories
        self.sizes = sizes
        self.anniversaries = anniversaries
        self.notes = notes
        self.vipTierRaw = vipTier.rawValue
        self.assignedAssociateEmail = assignedAssociateEmail
        self.lifetimeSpend = lifetimeSpend
        self.visitCount = visitCount
        self.lastVisitDate = lastVisitDate
        self.privacyConsentGiven = privacyConsentGiven
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
