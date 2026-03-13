//
//  AfterSalesTicket.swift
//  infosys2
//
//  SwiftData model for after-sales service tickets (repairs, warranty, authentication, valuation).
//

import Foundation
import SwiftData

enum TicketType: String, Codable, CaseIterable {
    case repair = "Repair"
    case servicing = "Servicing"
    case warranty = "Warranty Claim"
    case authentication = "Authentication"
    case valuation = "Valuation"
    case customization = "Customization"
    case exchange = "Exchange"
    case returnItem = "Return"
}

enum TicketStatus: String, Codable, CaseIterable {
    case created = "Created"
    case assessed = "Assessed"
    case estimateSent = "Estimate Sent"
    case approved = "Approved"
    case inProgress = "In Progress"
    case awaitingParts = "Awaiting Parts"
    case qualityCheck = "Quality Check"
    case completed = "Completed"
    case closed = "Closed"
    case declined = "Declined"
}

@Model
final class AfterSalesTicket {
    var id: UUID
    var ticketNumber: String
    var customerEmail: String
    var customerName: String
    var productId: UUID
    var productName: String
    var serialNumber: String
    var ticketTypeRaw: String
    var statusRaw: String
    var issueDescription: String
    var assessmentNotes: String
    var estimatedCost: Double
    var actualCost: Double
    var estimatedCompletionDate: Date?
    var completedDate: Date?
    var assignedTechnicianEmail: String
    var boutiqueId: String
    var photos: String              // JSON array of photo identifiers
    var warrantyValid: Bool
    var createdAt: Date
    var updatedAt: Date

    var ticketType: TicketType {
        get { TicketType(rawValue: ticketTypeRaw) ?? .repair }
        set { ticketTypeRaw = newValue.rawValue }
    }

    var ticketStatus: TicketStatus {
        get { TicketStatus(rawValue: statusRaw) ?? .created }
        set { statusRaw = newValue.rawValue }
    }

    init(
        ticketNumber: String,
        customerEmail: String,
        customerName: String = "",
        productId: UUID = UUID(),
        productName: String = "",
        serialNumber: String = "",
        ticketType: TicketType = .repair,
        status: TicketStatus = .created,
        issueDescription: String = "",
        assessmentNotes: String = "",
        estimatedCost: Double = 0,
        actualCost: Double = 0,
        estimatedCompletionDate: Date? = nil,
        assignedTechnicianEmail: String = "",
        boutiqueId: String = "delhi-flagship",
        photos: String = "[]",
        warrantyValid: Bool = false
    ) {
        self.id = UUID()
        self.ticketNumber = ticketNumber
        self.customerEmail = customerEmail
        self.customerName = customerName
        self.productId = productId
        self.productName = productName
        self.serialNumber = serialNumber
        self.ticketTypeRaw = ticketType.rawValue
        self.statusRaw = status.rawValue
        self.issueDescription = issueDescription
        self.assessmentNotes = assessmentNotes
        self.estimatedCost = estimatedCost
        self.actualCost = actualCost
        self.estimatedCompletionDate = estimatedCompletionDate
        self.completedDate = nil
        self.assignedTechnicianEmail = assignedTechnicianEmail
        self.boutiqueId = boutiqueId
        self.photos = photos
        self.warrantyValid = warrantyValid
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
