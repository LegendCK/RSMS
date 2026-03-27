//
//  ProductFeedbackService.swift
//  RSMS
//
//  Supabase-backed product review service.
//

import Foundation
import Supabase

@MainActor
final class ProductFeedbackService {
    static let shared = ProductFeedbackService()
    private let client = SupabaseManager.shared.client

    private init() {}

    func fetchProductFeedback(productId: UUID, limit: Int = 50) async throws -> [ProductFeedbackDTO] {
        try await client
            .from("product_feedback")
            .select()
            .eq("product_id", value: productId.uuidString.lowercased())
            .eq("status", value: "published")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchMyFeedback(productId: UUID, customerId: UUID) async throws -> ProductFeedbackDTO? {
        let rows: [ProductFeedbackDTO] = try await client
            .from("product_feedback")
            .select()
            .eq("product_id", value: productId.uuidString.lowercased())
            .eq("customer_id", value: customerId.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsertFeedback(
        productId: UUID,
        storeId: UUID?,
        customerId: UUID,
        customerName: String,
        rating: Int,
        title: String,
        comment: String
    ) async throws -> ProductFeedbackDTO {
        let payload = ProductFeedbackUpsertDTO(
            productId: productId,
            storeId: storeId,
            customerId: customerId,
            customerName: customerName,
            rating: max(1, min(5, rating)),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        return try await client
            .from("product_feedback")
            .upsert(payload, onConflict: "product_id,customer_id")
            .select()
            .single()
            .execute()
            .value
    }
}
