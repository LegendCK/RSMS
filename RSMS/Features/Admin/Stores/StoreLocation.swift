//
//  StoreLocation.swift
//  RSMS
//
//  SwiftData model representing a boutique or distribution center.
//  Synced from/to Supabase `stores` table by StoreSyncService.
//

import Foundation
import SwiftData

// MARK: - Location Type

enum LocationType: String, Codable {
    case boutique           = "boutique"
    case distributionCenter = "distribution_center"
}

// MARK: - Model

@Model
final class StoreLocation {
    var id: UUID
    var code: String
    var name: String
    // Persist as raw string for schema resilience and safe fallback.
    var typeRaw: String
    var country: String
    var city: String
    var addressLine1: String
    var stateProvince: String
    var postalCode: String
    var region: String
    var managerName: String
    var capacityUnits: Int
    var monthlySalesTarget: Double
    var isOperational: Bool
    var createdAt: Date
    var updatedAt: Date

    var type: LocationType {
        get { LocationType(rawValue: typeRaw) ?? .boutique }
        set { typeRaw = newValue.rawValue }
    }

    init(
        code: String,
        name: String,
        type: LocationType,
        addressLine1: String,
        city: String,
        stateProvince: String,
        postalCode: String,
        country: String,
        region: String,
        managerName: String,
        capacityUnits: Int,
        monthlySalesTarget: Double = 300_000,
        isOperational: Bool
    ) {
        self.id = UUID()
        self.code = code
        self.name = name
        self.typeRaw = type.rawValue
        self.addressLine1 = addressLine1
        self.city = city
        self.stateProvince = stateProvince
        self.postalCode = postalCode
        self.country = country
        self.region = region
        self.managerName = managerName
        self.capacityUnits = capacityUnits
        self.monthlySalesTarget = monthlySalesTarget
        self.isOperational = isOperational
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
