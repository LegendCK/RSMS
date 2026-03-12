//
//  AppNotification.swift
//  infosys2
//
//  SwiftData model for in-app notifications.
//

import Foundation
import SwiftData

enum NotificationCategory: String, Codable, CaseIterable {
    case order = "Order"
    case appointment = "Appointment"
    case afterSales = "After-Sales"
    case inventory = "Inventory"
    case event = "Event"
    case promotion = "Promotion"
    case system = "System"
}

@Model
final class AppNotification {
    var id: UUID
    var recipientEmail: String
    var title: String
    var message: String
    var categoryRaw: String
    var isRead: Bool
    var deepLink: String            // e.g. "order/ORD-2026-0001" or "ticket/AST-2026-0042"
    var createdAt: Date

    var category: NotificationCategory {
        get { NotificationCategory(rawValue: categoryRaw) ?? .system }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        recipientEmail: String,
        title: String,
        message: String,
        category: NotificationCategory = .system,
        isRead: Bool = false,
        deepLink: String = ""
    ) {
        self.id = UUID()
        self.recipientEmail = recipientEmail
        self.title = title
        self.message = message
        self.categoryRaw = category.rawValue
        self.isRead = isRead
        self.deepLink = deepLink
        self.createdAt = Date()
    }
}
