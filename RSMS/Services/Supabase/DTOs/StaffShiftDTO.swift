//
//  StaffShiftDTO.swift
//  RSMS
//
//  Codable DTOs for Supabase `staff_shifts` table.
//

import Foundation

struct StaffShiftDTO: Codable, Identifiable {
    let id: UUID
    let staffUserId: UUID
    let storeId: UUID
    let startAt: Date
    let endAt: Date
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case staffUserId = "staff_user_id"
        case storeId = "store_id"
        case startAt = "start_at"
        case endAt = "end_at"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct StaffShiftInsertDTO: Codable {
    let id: UUID
    let staffUserId: UUID
    let storeId: UUID
    let startAt: Date
    let endAt: Date
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case staffUserId = "staff_user_id"
        case storeId = "store_id"
        case startAt = "start_at"
        case endAt = "end_at"
        case notes
    }
}

struct StaffShiftUpdateDTO: Codable {
    let staffUserId: UUID
    let startAt: Date
    let endAt: Date
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case staffUserId = "staff_user_id"
        case startAt = "start_at"
        case endAt = "end_at"
        case notes
    }
}
