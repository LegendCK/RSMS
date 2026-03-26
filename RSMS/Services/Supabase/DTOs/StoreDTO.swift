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
}
