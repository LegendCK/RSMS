import Foundation
import Supabase

@MainActor
final class DiscrepancyService {
    static let shared = DiscrepancyService()
    private let client = SupabaseManager.shared.client
    private init() {}

    func fetchDiscrepancies(storeId: UUID) async throws -> [InventoryDiscrepancyDTO] {
        return try await client
            .from("inventory_discrepancies")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func submitDiscrepancy(dto: DiscrepancyInsertDTO) async throws {
        try await client
            .from("inventory_discrepancies")
            .insert(dto)
            .execute()
    }

    func approve(id: UUID, reviewerId: UUID, notes: String?) async throws {
        let patch = DiscrepancyUpdateDTO(
            status: "approved",
            reviewedBy: reviewerId,
            managerNotes: notes
        )
        try await client
            .from("inventory_discrepancies")
            .update(patch)
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    func reject(id: UUID, reviewerId: UUID, notes: String?) async throws {
        let patch = DiscrepancyUpdateDTO(
            status: "rejected",
            reviewedBy: reviewerId,
            managerNotes: notes
        )
        try await client
            .from("inventory_discrepancies")
            .update(patch)
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
}
