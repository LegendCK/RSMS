//
//  DiscrepancyDTO.swift
//  RSMS
//
//  Codable DTOs matching the Supabase `inventory_discrepancies` and
//  `inventory_discrepancy_logs` tables.
//

import Foundation

// MARK: - Read DTO (SELECT)

struct InventoryDiscrepancyDTO: Codable, Identifiable {
    let id:               UUID
    let storeId:          UUID
    let productId:        UUID
    let productName:      String
    let reportedQuantity: Int
    let systemQuantity:   Int
    let reason:           String
    let status:           String
    let reportedBy:       UUID
    let reportedByName:   String
    let reviewedBy:       UUID?
    let managerNotes:     String?
    let createdAt:        Date
    let updatedAt:        Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeId          = "store_id"
        case productId        = "product_id"
        case productName      = "product_name"
        case reportedQuantity = "reported_quantity"
        case systemQuantity   = "system_quantity"
        case reason
        case status
        case reportedBy       = "reported_by"
        case reportedByName   = "reported_by_name"
        case reviewedBy       = "reviewed_by"
        case managerNotes     = "manager_notes"
        case createdAt        = "created_at"
        case updatedAt        = "updated_at"
    }

    var discrepancyStatus: DiscrepancyStatus {
        DiscrepancyStatus(rawValue: status) ?? .pending
    }

    var quantityDelta: Int { abs(reportedQuantity - systemQuantity) }

    var deltaDirection: String {
        if reportedQuantity < systemQuantity { return "Short" }
        if reportedQuantity > systemQuantity { return "Over" }
        return "Match"
    }
}

// MARK: - Insert DTO (POST)

struct DiscrepancyInsertDTO: Codable {
    let storeId:          UUID
    let productId:        UUID
    let productName:      String
    let reportedQuantity: Int
    let systemQuantity:   Int
    let reason:           String
    let reportedBy:       UUID
    let reportedByName:   String

    enum CodingKeys: String, CodingKey {
        case storeId          = "store_id"
        case productId        = "product_id"
        case productName      = "product_name"
        case reportedQuantity = "reported_quantity"
        case systemQuantity   = "system_quantity"
        case reason
        case reportedBy       = "reported_by"
        case reportedByName   = "reported_by_name"
    }
}

// MARK: - Update DTO (PATCH for approve/reject)

struct DiscrepancyUpdateDTO: Codable {
    let status:       String
    let reviewedBy:   UUID
    let managerNotes: String?

    enum CodingKeys: String, CodingKey {
        case status
        case reviewedBy   = "reviewed_by"
        case managerNotes = "manager_notes"
    }
}

// MARK: - Audit Log DTO

struct DiscrepancyLogInsertDTO: Codable {
    let discrepancyId: UUID
    let action:        String
    let actorId:       UUID
    let actorName:     String
    let notes:         String?
    let oldQuantity:   Int?
    let newQuantity:   Int?

    enum CodingKeys: String, CodingKey {
        case discrepancyId = "discrepancy_id"
        case action
        case actorId       = "actor_id"
        case actorName     = "actor_name"
        case notes
        case oldQuantity   = "old_quantity"
        case newQuantity   = "new_quantity"
    }
}
