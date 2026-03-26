//
//  StoreDTO.swift
//  RSMS
//
//  Codable DTO matching the Supabase `stores` table.
//

import Foundation

struct StoreDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let code: String?
    let address: String?
    let city: String?
    let country: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, code, address, city, country
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country) ?? ""
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}
