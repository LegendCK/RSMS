//
//  Appointment.swift
//  infosys2
//
//  SwiftData model for boutique appointments.
//

import Foundation
import SwiftData

enum AppointmentType: String, Codable, CaseIterable {
    case consultation = "Consultation"
    case styling = "Styling Session"
    case bridal = "Bridal Consultation"
    case watchConsultation = "Watch Consultation"
    case repairDropOff = "Repair Drop-Off"
    case repairPickup = "Repair Pickup"
    case privateViewing = "Private Viewing"
    case videoConsult = "Video Consultation"
}

enum AppointmentStatus: String, Codable, CaseIterable {
    case requested = "Requested"
    case confirmed = "Confirmed"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case noShow = "No Show"
}

@Model
final class Appointment {
    var id: UUID
    var customerEmail: String
    var customerName: String
    var associateEmail: String
    var boutiqueId: String
    var appointmentTypeRaw: String
    var scheduledAt: Date
    var durationMinutes: Int
    var statusRaw: String
    var notes: String
    var relatedProductIds: String   // JSON array of UUID strings
    var createdAt: Date

    var appointmentType: AppointmentType {
        get { AppointmentType(rawValue: appointmentTypeRaw) ?? .consultation }
        set { appointmentTypeRaw = newValue.rawValue }
    }

    var appointmentStatus: AppointmentStatus {
        get { AppointmentStatus(rawValue: statusRaw) ?? .requested }
        set { statusRaw = newValue.rawValue }
    }

    init(
        customerEmail: String,
        customerName: String = "",
        associateEmail: String = "",
        boutiqueId: String = "delhi-flagship",
        appointmentType: AppointmentType = .consultation,
        scheduledAt: Date,
        durationMinutes: Int = 60,
        status: AppointmentStatus = .requested,
        notes: String = "",
        relatedProductIds: String = "[]"
    ) {
        self.id = UUID()
        self.customerEmail = customerEmail
        self.customerName = customerName
        self.associateEmail = associateEmail
        self.boutiqueId = boutiqueId
        self.appointmentTypeRaw = appointmentType.rawValue
        self.scheduledAt = scheduledAt
        self.durationMinutes = durationMinutes
        self.statusRaw = status.rawValue
        self.notes = notes
        self.relatedProductIds = relatedProductIds
        self.createdAt = Date()
    }
}
