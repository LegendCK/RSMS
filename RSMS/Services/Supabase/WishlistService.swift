import Foundation
import SwiftData
import Supabase

@MainActor
final class WishlistService {
    static let shared = WishlistService()

    private let client = SupabaseManager.shared.client

    private init() {}

    private struct WishlistRow: Decodable {
        let productId: UUID

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
        }
    }

    private struct WishlistUpsertPayload: Encodable {
        let userId: UUID
        let productId: UUID

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case productId = "product_id"
        }
    }

    private func currentUserId() async throws -> UUID {
        try await client.auth.session.user.id
    }

    func fetchWishlistProductIDs() async throws -> Set<UUID> {
        let userId = try await currentUserId()
        let rows: [WishlistRow] = try await client
            .from("wishlist_items")
            .select("product_id")
            .eq("user_id", value: userId.uuidString.lowercased())
            .execute()
            .value
        return Set(rows.map(\.productId))
    }

    func hydrateLocalWishlist(modelContext: ModelContext) async throws {
        let wishedIds = try await fetchWishlistProductIDs()
        let products = try modelContext.fetch(FetchDescriptor<Product>())
        for product in products {
            let shouldBeWishlisted = wishedIds.contains(product.id)
            if product.isWishlisted != shouldBeWishlisted {
                product.isWishlisted = shouldBeWishlisted
            }
        }
        try modelContext.save()
    }

    func setWishlisted(productId: UUID, isWishlisted: Bool) async throws {
        if isWishlisted {
            let payload = WishlistUpsertPayload(userId: try await currentUserId(), productId: productId)
            _ = try await client
                .from("wishlist_items")
                .upsert(payload, onConflict: "user_id,product_id")
                .execute()
        } else {
            try await remove(productId: productId)
        }
    }

    func remove(productId: UUID) async throws {
        let userId = try await currentUserId()
        try await client
            .from("wishlist_items")
            .delete()
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("product_id", value: productId.uuidString.lowercased())
            .execute()
    }
}
