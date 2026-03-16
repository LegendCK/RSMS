//
//  SavedPaymentCard.swift
//  RSMS
//
//  SwiftData model for customer saved payment cards.
//  Only stores display metadata — last 4 digits, brand, expiry.
//  Full card numbers are never persisted.
//

import Foundation
import SwiftData

@Model
final class SavedPaymentCard {
    var id: UUID
    var customerEmail: String
    var cardHolderName: String
    var lastFourDigits: String      // e.g. "4242"
    var expiryMonth: Int            // 1 – 12
    var expiryYear: Int             // e.g. 2029
    var cardBrand: String           // "Visa" | "Mastercard" | "Amex" | "Discover" | "Card"
    var isDefault: Bool
    var createdAt: Date

    init(
        customerEmail: String,
        cardHolderName: String,
        lastFourDigits: String,
        expiryMonth: Int,
        expiryYear: Int,
        cardBrand: String,
        isDefault: Bool = false
    ) {
        self.id             = UUID()
        self.customerEmail  = customerEmail
        self.cardHolderName = cardHolderName
        self.lastFourDigits = lastFourDigits
        self.expiryMonth    = expiryMonth
        self.expiryYear     = expiryYear
        self.cardBrand      = cardBrand
        self.isDefault      = isDefault
        self.createdAt      = Date()
    }

    /// e.g. "•••• •••• •••• 4242"
    var maskedNumber: String { "•••• •••• •••• \(lastFourDigits)" }

    /// e.g. "03/29"
    var expiryLabel: String {
        String(format: "%02d/%02d", expiryMonth, expiryYear % 100)
    }

    /// 2–4 letter abbreviation shown on the card chip
    var brandInitials: String {
        switch cardBrand {
        case "Visa":       return "VISA"
        case "Mastercard": return "MC"
        case "Amex":       return "AMEX"
        case "Discover":   return "DISC"
        default:           return "CARD"
        }
    }

    var brandIcon: String {
        switch cardBrand {
        case "Visa":       return "v.square.fill"
        case "Mastercard": return "m.square.fill"
        case "Amex":       return "a.square.fill"
        case "Discover":   return "d.square.fill"
        default:           return "creditcard.fill"
        }
    }

    var isExpired: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let yr  = now.year  ?? 0
        let mo  = now.month ?? 0
        return expiryYear < yr || (expiryYear == yr && expiryMonth < mo)
    }
}
