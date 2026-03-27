import Foundation
import SwiftData
import Supabase

@MainActor
final class WishlistService {
    static let shared = WishlistService()

    enum SyncCapabilityError: Error {
        case missingWishlistTable
        case wishlistForeignKeyMisconfigured
    }

    private let client = SupabaseManager.shared.client
    private var hasLoggedMissingTableWarning = false
    private var hasLoggedForeignKeyWarning = false

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

    private func isMissingWishlistTableError(_ error: Error) -> Bool {
        if let postgrestError = error as? PostgrestError {
            let code = postgrestError.code ?? ""
            let message = postgrestError.message.lowercased()
            let hint = postgrestError.hint?.lowercased() ?? ""
            if code == "PGRST205" && (message.contains("wishlist_items") || hint.contains("wishlist_items")) {
                return true
            }
        }

        let description = error.localizedDescription.lowercased()
        return description.contains("pgrst205") && description.contains("wishlist_items")
    }

    private func normalizeWishlistError(_ error: Error) -> Error {
        if isMissingWishlistTableError(error) {
            return SyncCapabilityError.missingWishlistTable
        }
        if let postgrestError = error as? PostgrestError {
            let code = (postgrestError.code ?? "").uppercased()
            let message = postgrestError.message.lowercased()
            let description = error.localizedDescription.lowercased()
            if code == "23503" &&
                (message.contains("wishlist_items_user_id_fkey") ||
                 description.contains("wishlist_items_user_id_fkey")) {
                return SyncCapabilityError.wishlistForeignKeyMisconfigured
            }
        }
        return error
    }

    private func logMissingTableWarningOnce() {
        guard !hasLoggedMissingTableWarning else { return }
        hasLoggedMissingTableWarning = true
        print("[WishlistService] Supabase table 'public.wishlist_items' is missing. Apply migration: supabase/migrations/20260324_wishlist_items.sql")
    }

    private func logForeignKeyWarningOnce() {
        guard !hasLoggedForeignKeyWarning else { return }
        hasLoggedForeignKeyWarning = true
        print("[WishlistService] Supabase wishlist FK is misconfigured. Apply migration: supabase/migrations/20260327_fix_wishlist_user_fk.sql")
    }

    func fetchWishlistProductIDs() async throws -> Set<UUID> {
        let userId = try await currentUserId()
        do {
            let rows: [WishlistRow] = try await client
                .from("wishlist_items")
                .select("product_id")
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                .value
            return Set(rows.map(\.productId))
        } catch {
            throw normalizeWishlistError(error)
        }
    }

    func hydrateLocalWishlist(modelContext: ModelContext) async throws {
        let wishedIds: Set<UUID>
        do {
            wishedIds = try await fetchWishlistProductIDs()
        } catch SyncCapabilityError.missingWishlistTable {
            logMissingTableWarningOnce()
            return
        } catch SyncCapabilityError.wishlistForeignKeyMisconfigured {
            logForeignKeyWarningOnce()
            return
        }
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
            do {
                _ = try await client
                    .from("wishlist_items")
                    .upsert(payload, onConflict: "user_id,product_id")
                    .execute()
            } catch {
                let normalized = normalizeWishlistError(error)
                if case SyncCapabilityError.missingWishlistTable = normalized {
                    logMissingTableWarningOnce()
                }
                if case SyncCapabilityError.wishlistForeignKeyMisconfigured = normalized {
                    logForeignKeyWarningOnce()
                }
                throw normalized
            }
        } else {
            try await remove(productId: productId)
        }
    }

    func remove(productId: UUID) async throws {
        let userId = try await currentUserId()
        do {
            try await client
                .from("wishlist_items")
                .delete()
                .eq("user_id", value: userId.uuidString.lowercased())
                .eq("product_id", value: productId.uuidString.lowercased())
                .execute()
        } catch {
            let normalized = normalizeWishlistError(error)
            if case SyncCapabilityError.missingWishlistTable = normalized {
                logMissingTableWarningOnce()
            }
            if case SyncCapabilityError.wishlistForeignKeyMisconfigured = normalized {
                logForeignKeyWarningOnce()
            }
            throw normalized
        }
    }
}
