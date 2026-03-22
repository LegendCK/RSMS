import Foundation
import Supabase

struct ProductWarrantyPolicyDTO: Codable, Sendable {
    let productId: UUID
    let coverageMonths: Int
    let eligibleServices: [String]
    let createdBy: UUID?
    let updatedBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case coverageMonths = "coverage_months"
        case eligibleServices = "eligible_services"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct ProductWarrantyPolicyUpsertDTO: Encodable {
    let productId: UUID
    let coverageMonths: Int
    let eligibleServices: [String]
    let updatedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case coverageMonths = "coverage_months"
        case eligibleServices = "eligible_services"
        case updatedBy = "updated_by"
    }
}

@MainActor
final class ProductWarrantyPolicyService {
    static let shared = ProductWarrantyPolicyService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func fetchPolicy(productId: UUID) async throws -> ProductWarrantyPolicyDTO? {
        let rows: [ProductWarrantyPolicyDTO] = try await client
            .from("product_warranty_policies")
            .select()
            .eq("product_id", value: productId.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    @discardableResult
    func upsertPolicy(
        productId: UUID,
        coverageMonths: Int,
        eligibleServices: [String],
        updatedBy: UUID?
    ) async throws -> ProductWarrantyPolicyDTO {
        let payload = ProductWarrantyPolicyUpsertDTO(
            productId: productId,
            coverageMonths: max(0, min(coverageMonths, 120)),
            eligibleServices: eligibleServices,
            updatedBy: updatedBy
        )

        return try await client
            .from("product_warranty_policies")
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value
    }
}

