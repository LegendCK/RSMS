import Foundation
import Supabase

@MainActor
final class PromotionService {
    static let shared = PromotionService()
    private let client = SupabaseManager.shared.client
    private init() {}

    func createPromotion(
        name: String,
        details: String,
        scope: PromotionScope,
        targetProductId: UUID?,
        targetCategoryId: UUID?,
        discountType: PromotionDiscountType,
        discountValue: Double,
        startsAt: Date,
        endsAt: Date,
        isActive: Bool,
        createdBy: UUID?
    ) async throws -> PromotionDTO {
        let payload: [String: AnyEncodable] = [
            "name": AnyEncodable(name),
            "details": AnyEncodable(details),
            "promotion_scope": AnyEncodable(scope.rawValue),
            "target_product_id": AnyEncodable(targetProductId?.uuidString),
            "target_category_id": AnyEncodable(targetCategoryId?.uuidString),
            "discount_type": AnyEncodable(discountType.rawValue),
            "discount_value": AnyEncodable(discountValue),
            "starts_at": AnyEncodable(startsAt),
            "ends_at": AnyEncodable(endsAt),
            "is_active": AnyEncodable(isActive),
            "created_by": AnyEncodable(createdBy?.uuidString)
        ]

        return try await client
            .from("promotions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchPromotions(includeInactive: Bool = false) async throws -> [PromotionDTO] {
        var query = client.from("promotions").select()
        if !includeInactive {
            query = query.eq("is_active", value: true)
        }
        return try await query
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func setPromotionActiveState(id: UUID, isActive: Bool) async throws {
        try await client
            .from("promotions")
            .update(["is_active": isActive])
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
}

// Helper for dynamic dictionary encoding
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
