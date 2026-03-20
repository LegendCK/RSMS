//
//  ReservationDTO.swift
//  RSMS
//
//  Data Transfer Objects representing the Supabase reservations table
//

import Foundation

struct ReservationDTO: Codable, Identifiable {
    let id: UUID
    let clientId: UUID
    let productId: UUID
    let storeId: UUID?
    let selectedColor: String?
    let selectedSize: String?
    let status: String
    let expiresAt: Date
    let createdAt: Date
    let updatedAt: Date
    
    // Nested relationships defined in Supabase
    let product: ProductDTO?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case productId = "product_id"
        case storeId = "store_id"
        case selectedColor = "selected_color"
        case selectedSize = "selected_size"
        case status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case product = "products" // Supabase auto-expands foreign keys
    }
}

struct ReservationInsertDTO: Codable {
    let clientId: UUID
    let productId: UUID
    let storeId: UUID?
    let selectedColor: String?
    let selectedSize: String?
    let status: String
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case productId = "product_id"
        case storeId = "store_id"
        case selectedColor = "selected_color"
        case selectedSize = "selected_size"
        case status
        case expiresAt = "expires_at"
    }
}

struct ReservationUpdateDTO: Codable {
    let status: String?
}
