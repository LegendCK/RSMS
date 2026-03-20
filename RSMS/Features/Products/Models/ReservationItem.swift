//
//  ReservationItem.swift
//  RSMS
//
//  SwiftData model for product reservations.
//

import Foundation
import SwiftData

enum ReservationStatus: String, Codable {
    case active = "Active"
    case expired = "Expired"
    case purchased = "Purchased"
    case cancelled = "Cancelled"
}

@Model
final class ReservationItem {
    var id: UUID
    var remoteId: UUID?
    var customerEmail: String
    var productId: UUID
    var productName: String
    var productBrand: String
    var productImageName: String
    var selectedColor: String
    var selectedSize: String?
    var addedAt: Date
    var expiresAt: Date
    var statusRaw: String // Using raw string since enums can sometimes be tricky with SwiftData migrations
    
    var status: ReservationStatus {
        get { ReservationStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        remoteId: UUID? = nil,
        customerEmail: String,
        productId: UUID,
        productName: String,
        productBrand: String,
        productImageName: String = "bag.fill",
        selectedColor: String,
        selectedSize: String? = nil,
        durationDays: Int = 2,
        status: ReservationStatus = .active
    ) {
        self.id = UUID()
        self.remoteId = remoteId
        self.customerEmail = customerEmail
        self.productId = productId
        self.productName = productName
        self.productBrand = productBrand
        self.productImageName = productImageName
        self.selectedColor = selectedColor
        self.selectedSize = selectedSize
        self.statusRaw = status.rawValue
        
        let now = Date()
        self.addedAt = now
        self.expiresAt = Calendar.current.date(byAdding: .day, value: durationDays, to: now) ?? now.addingTimeInterval(Double(durationDays) * 86400)
    }
    
    var isExpired: Bool {
        return Date() > expiresAt || status == .expired
    }
    
    var timeRemainingString: String {
        guard !isExpired else { return "Expired" }
        
        let diff = Calendar.current.dateComponents([.hour, .minute], from: Date(), to: expiresAt)
        let hrs = diff.hour ?? 0
        let mins = diff.minute ?? 0
        
        if hrs > 0 {
            return "\(hrs)h \(mins)m remaining"
        } else {
            return "\(mins)m remaining"
        }
    }
}
