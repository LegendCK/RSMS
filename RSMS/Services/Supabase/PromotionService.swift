import Foundation
import Supabase

enum PromotionServiceError: LocalizedError {
    case promotionsTableMissing

    var errorDescription: String? {
        switch self {
        case .promotionsTableMissing:
            return "Promotions backend is not set up yet. Run the latest Supabase migrations and reload schema."
        }
    }
}

@MainActor
final class PromotionService {
    static let shared = PromotionService()

    private let client = SupabaseManager.shared.client
    private let maxRetries = 2
    private let retryBaseDelay: UInt64 = 1_000_000_000

    private init() {}

    private func withRetry<T>(
        label: String,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch let urlError as URLError {
                lastError = urlError
                let retryable = [
                    URLError.networkConnectionLost,
                    URLError.notConnectedToInternet,
                    URLError.timedOut,
                    URLError.cannotConnectToHost,
                    URLError.dataNotAllowed,
                ].contains(urlError.code)
                guard retryable && attempt < maxRetries else { throw urlError }
                try await Task.sleep(nanoseconds: retryBaseDelay * UInt64(1 << attempt))
            } catch {
                if isMissingPromotionsTableError(error) {
                    throw PromotionServiceError.promotionsTableMissing
                }
                throw error
            }
        }
        throw lastError!
    }

    private func isMissingPromotionsTableError(_ error: Error) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("public.promotions")
            || text.contains("relation \"promotions\" does not exist")
            || text.contains("could not find the table")
    }

    func fetchPromotions(includeInactive: Bool = true) async throws -> [PromotionDTO] {
        try await withRetry(label: "fetchPromotions") {
            if includeInactive {
                return try await client
                    .from("promotions")
                    .select()
                    .order("starts_at", ascending: false)
                    .execute()
                    .value
            } else {
                return try await client
                    .from("promotions")
                    .select()
                    .eq("is_active", value: true)
                    .order("starts_at", ascending: false)
                    .execute()
                    .value
            }
        }
    }

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
        let payload = PromotionInsertDTO(
            name: name,
            details: details.isEmpty ? nil : details,
            scope: scope.rawValue,
            targetProductId: targetProductId,
            targetCategoryId: targetCategoryId,
            discountType: discountType.rawValue,
            discountValue: discountValue,
            startsAt: startsAt,
            endsAt: endsAt,
            isActive: isActive,
            createdBy: createdBy
        )

        return try await withRetry(label: "createPromotion") {
            try await client
                .from("promotions")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func setPromotionActiveState(id: UUID, isActive: Bool) async throws -> PromotionDTO {
        let payload = PromotionUpdateDTO(isActive: isActive)

        return try await withRetry(label: "setPromotionActiveState") {
            try await client
                .from("promotions")
                .update(payload)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value
        }
    }
}
