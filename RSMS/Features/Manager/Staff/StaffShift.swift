//
//  StaffShift.swift
//  RSMS
//
//  SwiftData model for boutique staff shift scheduling.
//

import Foundation
import SwiftData

@Model
final class StaffShift {
    var id: UUID
    var staffUserId: UUID
    var storeId: UUID
    var startAt: Date
    var endAt: Date
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        staffUserId: UUID,
        storeId: UUID,
        startAt: Date,
        endAt: Date,
        notes: String = ""
    ) {
        self.id = UUID()
        self.staffUserId = staffUserId
        self.storeId = storeId
        self.startAt = startAt
        self.endAt = endAt
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
