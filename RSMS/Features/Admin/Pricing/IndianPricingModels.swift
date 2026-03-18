import Foundation
import SwiftData

@Model
final class PricingPolicySettings {
    var id: UUID
    var businessState: String
    var currencyCode: String
    var freeShippingThreshold: Double
    var standardShippingFee: Double
    var shippingTaxable: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        businessState: String = "Maharashtra",
        currencyCode: String = "INR",
        freeShippingThreshold: Double = 500,
        standardShippingFee: Double = 25,
        shippingTaxable: Bool = false
    ) {
        self.id = UUID()
        self.businessState = businessState
        self.currencyCode = currencyCode
        self.freeShippingThreshold = freeShippingThreshold
        self.standardShippingFee = standardShippingFee
        self.shippingTaxable = shippingTaxable
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class IndianTaxRule {
    var id: UUID
    var goodsCategory: String
    var gstPercent: Double
    var cessPercent: Double
    var additionalLevyPercent: Double
    var isActive: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        goodsCategory: String,
        gstPercent: Double,
        cessPercent: Double = 0,
        additionalLevyPercent: Double = 0,
        isActive: Bool = true,
        notes: String = ""
    ) {
        self.id = UUID()
        self.goodsCategory = goodsCategory
        self.gstPercent = gstPercent
        self.cessPercent = cessPercent
        self.additionalLevyPercent = additionalLevyPercent
        self.isActive = isActive
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class RegionalPriceRule {
    var id: UUID
    var productId: UUID
    var regionState: String
    var overridePrice: Double
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        productId: UUID,
        regionState: String,
        overridePrice: Double,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.productId = productId
        self.regionState = regionState
        self.overridePrice = overridePrice
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
