import Foundation

struct PromotionDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let details: String?
    let scope: String
    let targetProductId: UUID?
    let targetCategoryId: UUID?
    let discountType: String
    let discountValue: Double
    let startsAt: Date
    let endsAt: Date
    let isActive: Bool
    let createdBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, details, scope
        case targetProductId = "target_product_id"
        case targetCategoryId = "target_category_id"
        case discountType = "discount_type"
        case discountValue = "discount_value"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isActive = "is_active"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var promotionScope: PromotionScope {
        PromotionScope(rawValue: scope) ?? .product
    }

    var promotionDiscountType: PromotionDiscountType {
        PromotionDiscountType(rawValue: discountType) ?? .percentage
    }
}

struct PromotionInsertDTO: Codable {
    let name: String
    let details: String?
    let scope: String
    let targetProductId: UUID?
    let targetCategoryId: UUID?
    let discountType: String
    let discountValue: Double
    let startsAt: Date
    let endsAt: Date
    let isActive: Bool
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case name, details, scope
        case targetProductId = "target_product_id"
        case targetCategoryId = "target_category_id"
        case discountType = "discount_type"
        case discountValue = "discount_value"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isActive = "is_active"
        case createdBy = "created_by"
    }
}

struct PromotionUpdateDTO: Codable {
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
    }
}
