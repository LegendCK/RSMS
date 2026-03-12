//
//  ServiceTicketDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `service_tickets` table exactly.
//  Columns: id, ticket_number, client_id, store_id, assigned_to,
//           product_id, order_id, type, status, condition_notes,
//           intake_photos, estimated_cost, final_cost, currency,
//           sla_due_date, notes, created_at, updated_at
//

import Foundation

struct ServiceTicketDTO: Codable, Identifiable {
    let id: UUID
    let ticketNumber: String?
    let clientId: UUID?
    let storeId: UUID
    let assignedTo: UUID?           // FK to users.id (service technician)
    let productId: UUID?
    let orderId: UUID?
    let type: String                // "repair" | "servicing" | "warranty" | "authentication" | "valuation" | "customization" | "exchange" | "return"
    let status: String              // "intake" | "assessed" | "estimate_sent" | "approved" | "in_progress" | "awaiting_parts" | "quality_check" | "completed" | "closed" | "declined"
    let conditionNotes: String?
    let intakePhotos: [String]?     // Array of Supabase Storage URLs
    let estimatedCost: Double?
    let finalCost: Double?
    let currency: String
    let slaDueDate: String?         // "YYYY-MM-DD" date string
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ticketNumber  = "ticket_number"
        case clientId      = "client_id"
        case storeId       = "store_id"
        case assignedTo    = "assigned_to"
        case productId     = "product_id"
        case orderId       = "order_id"
        case type
        case status
        case conditionNotes = "condition_notes"
        case intakePhotos  = "intake_photos"
        case estimatedCost = "estimated_cost"
        case finalCost     = "final_cost"
        case currency
        case slaDueDate    = "sla_due_date"
        case notes
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    // MARK: - Convenience

    var isOverdue: Bool {
        guard let due = slaDueDate,
              let dueDate = ISO8601DateFormatter().date(from: due + "T00:00:00Z")
        else { return false }
        return Date() > dueDate && status != "completed" && status != "closed"
    }
}

// MARK: - Insert Payload

struct ServiceTicketInsertDTO: Codable {
    let clientId: UUID?
    let storeId: UUID
    let assignedTo: UUID?
    let productId: UUID?
    let orderId: UUID?
    let type: String
    let status: String
    let conditionNotes: String?
    let estimatedCost: Double?
    let currency: String
    let slaDueDate: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case clientId      = "client_id"
        case storeId       = "store_id"
        case assignedTo    = "assigned_to"
        case productId     = "product_id"
        case orderId       = "order_id"
        case type, status, currency, notes
        case conditionNotes = "condition_notes"
        case estimatedCost = "estimated_cost"
        case slaDueDate    = "sla_due_date"
    }
}
