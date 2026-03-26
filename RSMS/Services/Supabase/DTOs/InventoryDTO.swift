//
//  InventoryDTO.swift
//  RSMS
//
//  Codable DTO matching the Supabase `inventory` table.
//

import Foundation

struct InventoryDTO: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let locationId: UUID
    let quantity: Int
    let reservedQuantity: Int
    let availableQty: Int?

    
    // Remote joins
    var products: ProductDTO?
    var stores: StoreDTO?
    
    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case locationId = "location_id"
        case quantity
        case reservedQuantity = "reserved_quantity"
        case availableQty = "available_qty"
    }
}
