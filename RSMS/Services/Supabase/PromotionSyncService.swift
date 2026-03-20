import Foundation
import SwiftData

@MainActor
final class PromotionSyncService {
    static let shared = PromotionSyncService()

    private init() {}

    func refreshLocalPromotions(modelContext: ModelContext) async throws {
        let remotePromotions = try await PromotionService.shared.fetchPromotions(includeInactive: false)
        let locals = try modelContext.fetch(FetchDescriptor<PromotionRule>())
        var localById: [UUID: PromotionRule] = [:]

        for local in locals {
            if localById[local.id] == nil {
                localById[local.id] = local
            } else {
                modelContext.delete(local)
            }
        }

        let remoteIDs = Set(remotePromotions.map(\.id))
        for local in locals where !remoteIDs.contains(local.id) {
            modelContext.delete(local)
            localById.removeValue(forKey: local.id)
        }

        for dto in remotePromotions {
            if let local = localById[dto.id] {
                local.name = dto.name
                local.details = dto.details ?? ""
                local.scope = dto.promotionScope
                local.targetProductId = dto.targetProductId
                local.targetCategoryId = dto.targetCategoryId
                local.discountType = dto.promotionDiscountType
                local.discountValue = dto.discountValue
                local.startsAt = dto.startsAt
                local.endsAt = dto.endsAt
                local.isActive = dto.isActive
                local.createdBy = dto.createdBy
                local.createdAt = dto.createdAt
                local.updatedAt = dto.updatedAt
            } else {
                modelContext.insert(
                    PromotionRule(
                        id: dto.id,
                        name: dto.name,
                        details: dto.details ?? "",
                        scope: dto.promotionScope,
                        targetProductId: dto.targetProductId,
                        targetCategoryId: dto.targetCategoryId,
                        discountType: dto.promotionDiscountType,
                        discountValue: dto.discountValue,
                        startsAt: dto.startsAt,
                        endsAt: dto.endsAt,
                        isActive: dto.isActive,
                        createdBy: dto.createdBy,
                        createdAt: dto.createdAt,
                        updatedAt: dto.updatedAt
                    )
                )
            }
        }

        try modelContext.save()
    }
}
