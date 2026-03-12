//
//  AppointmentDTO.swift
//  infosys2
//
//  Codable DTO matching the Supabase `appointments` table exactly.
//  Columns: id, client_id, store_id, associate_id, type, status,
//           scheduled_at, duration_minutes, notes, video_link,
//           created_at, updated_at
//

import Foundation

struct AppointmentDTO: Codable, Identifiable {
    let id: UUID
    let clientId: UUID
    let storeId: UUID
    let associateId: UUID?
    let type: String                // "in_store" | "video" | "phone"
    let status: String              // "scheduled" | "confirmed" | "completed" | "cancelled" | "no_show"
    let scheduledAt: Date
    let durationMinutes: Int
    let notes: String?
    let videoLink: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientId       = "client_id"
        case storeId        = "store_id"
        case associateId    = "associate_id"
        case type
        case status
        case scheduledAt    = "scheduled_at"
        case durationMinutes = "duration_minutes"
        case notes
        case videoLink      = "video_link"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }
}

// MARK: - Insert Payload

struct AppointmentInsertDTO: Codable {
    let clientId: UUID
    let storeId: UUID
    let associateId: UUID?
    let type: String
    let status: String
    let scheduledAt: Date
    let durationMinutes: Int
    let notes: String?
    let videoLink: String?

    enum CodingKeys: String, CodingKey {
        case clientId        = "client_id"
        case storeId         = "store_id"
        case associateId     = "associate_id"
        case type, status, notes
        case scheduledAt     = "scheduled_at"
        case durationMinutes = "duration_minutes"
        case videoLink       = "video_link"
    }
}
