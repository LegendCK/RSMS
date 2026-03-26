//
//  Look.swift
//  RSMS
//

import Foundation
import SwiftData

@Model
final class Look {
    var id: UUID
    var name: String
    var creatorId: UUID
    var creatorName: String
    var productIds: [UUID]
    var createdAt: Date
    var isShared: Bool

    init(
        id: UUID = UUID(),
        name: String,
        creatorId: UUID,
        creatorName: String,
        productIds: [UUID] = [],
        createdAt: Date = Date(),
        isShared: Bool = false
    ) {
        self.id = id
        self.name = name
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.productIds = productIds
        self.createdAt = createdAt
        self.isShared = isShared
    }
}
