//
//  SalesLookDTO.swift
//  RSMS
//
//  Codable DTOs for the Supabase `sales_looks` table.
//

import Foundation

struct SalesLookDTO: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    let creatorId: UUID
    let creatorName: String
    let name: String
    let productIds: [UUID]
    let thumbnailSource: String?
    let isShared: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case name
        case productIds = "product_ids"
        case thumbnailSource = "thumbnail_source"
        case isShared = "is_shared"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SalesLookInsertDTO: Codable {
    let storeId: UUID
    let creatorId: UUID
    let creatorName: String
    let name: String
    let productIds: [UUID]
    let thumbnailSource: String?
    let isShared: Bool

    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case name
        case productIds = "product_ids"
        case thumbnailSource = "thumbnail_source"
        case isShared = "is_shared"
    }
}
