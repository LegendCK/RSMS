//
//  ProductFeedbackDTO.swift
//  RSMS
//
//  Codable DTOs for product feedback synced with Supabase.
//

import Foundation

struct ProductFeedbackDTO: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let storeId: UUID?
    let customerId: UUID
    let customerName: String
    let rating: Int
    let title: String
    let comment: String
    let status: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case storeId = "store_id"
        case customerId = "customer_id"
        case customerName = "customer_name"
        case rating
        case title
        case comment
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProductFeedbackUpsertDTO: Codable {
    let productId: UUID
    let storeId: UUID?
    let customerId: UUID
    let customerName: String
    let rating: Int
    let title: String
    let comment: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case storeId = "store_id"
        case customerId = "customer_id"
        case customerName = "customer_name"
        case rating
        case title
        case comment
    }
}
