//
//  AllocationDTO.swift
//  RSMS
//
//  Codable DTOs for the inventory allocation system:
//  inventory, allocations, allocation_logs tables.
//

import Foundation

// MARK: - Allocation Status

enum AllocationStatus: String, Codable, CaseIterable {
    case pending    = "PENDING"
    case inTransit  = "IN_TRANSIT"
    case completed  = "COMPLETED"
    case cancelled  = "CANCELLED"

    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .inTransit: return "In Transit"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}



// MARK: - Allocation DTO

struct AllocationDTO: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let fromLocationId: UUID
    let toLocationId: UUID
    let quantity: Int
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let createdBy: UUID?

    // Joined product data (optional)
    let products: ProductDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case productId       = "product_id"
        case fromLocationId  = "from_location_id"
        case toLocationId    = "to_location_id"
        case quantity
        case status
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case createdBy       = "created_by"
        case products
    }

    var allocationStatus: AllocationStatus {
        AllocationStatus(rawValue: status) ?? .pending
    }

    var isCompletable: Bool {
        allocationStatus == .pending || allocationStatus == .inTransit
    }
}

// MARK: - Allocation Log DTO

struct AllocationLogDTO: Codable, Identifiable {
    let id: UUID
    let allocationId: UUID
    let action: String
    let performedBy: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case allocationId = "allocation_id"
        case action
        case performedBy  = "performed_by"
        case createdAt    = "created_at"
    }
}



// MARK: - RPC Response

struct AllocationRPCResponse: Codable {
    let success: Bool
    let error: String?
    let message: String?
    let allocationId: UUID?
    let reserved: Int?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case allocationId = "allocation_id"
        case reserved
    }
}
