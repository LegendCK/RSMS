import Foundation
import SwiftData

enum PromotionScope: String, Codable, CaseIterable, Identifiable {
    case product = "Specific Product"
    case category = "Category"
    case storeWide = "Store Wide"

    var id: String { rawValue }

    var title: String { rawValue }
}

enum PromotionDiscountType: String, Codable, CaseIterable, Identifiable {
    case percentage = "Percentage"
    case fixedAmount = "Fixed Amount"
    case bogo = "BOGO"

    var id: String { rawValue }

    var title: String { rawValue }
}

@Model
final class PromotionRule {
    var id: UUID
    var name: String
    var details: String
    var scopeRaw: String
    var targetProductId: UUID?
    var targetCategoryId: UUID?
    var discountTypeRaw: String
    var discountValue: Double
    var startsAt: Date
    var endsAt: Date
    var isActive: Bool
    var createdBy: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        scope: PromotionScope,
        targetProductId: UUID? = nil,
        targetCategoryId: UUID? = nil,
        discountType: PromotionDiscountType,
        discountValue: Double,
        startsAt: Date,
        endsAt: Date,
        isActive: Bool = true,
        createdBy: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.scopeRaw = scope.rawValue
        self.targetProductId = targetProductId
        self.targetCategoryId = targetCategoryId
        self.discountTypeRaw = discountType.rawValue
        self.discountValue = discountValue
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isActive = isActive
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var scope: PromotionScope {
        get { PromotionScope(rawValue: scopeRaw) ?? .product }
        set { scopeRaw = newValue.rawValue }
    }

    var discountType: PromotionDiscountType {
        get { PromotionDiscountType(rawValue: discountTypeRaw) ?? .percentage }
        set { discountTypeRaw = newValue.rawValue }
    }

    func isEligible(on date: Date = Date()) -> Bool {
        isActive && startsAt <= date && endsAt >= date
    }
}
