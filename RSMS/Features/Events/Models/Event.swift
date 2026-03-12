//
//  Event.swift
//  infosys2
//
//  SwiftData model for boutique events (trunk shows, VIP previews, launches).
//

import Foundation
import SwiftData

enum EventType: String, Codable, CaseIterable {
    case trunkShow = "Trunk Show"
    case vipPreview = "VIP Preview"
    case launchParty = "Launch Party"
    case privateViewing = "Private Viewing"
    case masterclass = "Masterclass"
}

enum EventStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case confirmed = "Confirmed"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

@Model
final class Event {
    var id: UUID
    var eventName: String
    var eventTypeRaw: String
    var boutiqueId: String
    var scheduledDate: Date
    var durationMinutes: Int
    var capacity: Int
    var rsvpEmails: String          // JSON array of email strings
    var hostAssociateEmail: String
    var eventDescription: String
    var statusRaw: String
    var relatedCategory: String     // e.g. "Jewellery", "Couture"
    var createdAt: Date

    var eventType: EventType {
        get { EventType(rawValue: eventTypeRaw) ?? .trunkShow }
        set { eventTypeRaw = newValue.rawValue }
    }

    var eventStatus: EventStatus {
        get { EventStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var parsedRSVPs: [String] {
        guard let data = rsvpEmails.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return [] }
        return array
    }

    var rsvpCount: Int { parsedRSVPs.count }

    init(
        eventName: String,
        eventType: EventType = .trunkShow,
        boutiqueId: String = "delhi-flagship",
        scheduledDate: Date,
        durationMinutes: Int = 120,
        capacity: Int = 30,
        rsvpEmails: String = "[]",
        hostAssociateEmail: String = "",
        description: String = "",
        status: EventStatus = .planned,
        relatedCategory: String = ""
    ) {
        self.id = UUID()
        self.eventName = eventName
        self.eventTypeRaw = eventType.rawValue
        self.boutiqueId = boutiqueId
        self.scheduledDate = scheduledDate
        self.durationMinutes = durationMinutes
        self.capacity = capacity
        self.rsvpEmails = rsvpEmails
        self.hostAssociateEmail = hostAssociateEmail
        self.eventDescription = description
        self.statusRaw = status.rawValue
        self.relatedCategory = relatedCategory
        self.createdAt = Date()
    }
}
