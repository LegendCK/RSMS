//
//  AllocationTransferViewModel.swift
//  RSMS
//
//  ViewModel for the Transfers (Allocation Tracking) screen.
//  Loads allocations grouped by status and handles completion.
//

import SwiftUI

@Observable
@MainActor
final class AllocationTransferViewModel {

    // MARK: - State

    var allocations: [AllocationDTO] = []
    var locations: [StoreDTO] = []
    var isLoading = false
    var errorMessage: String?

    // Completion state
    var completingId: UUID?
    var completionError: String?

    // Dispatch state
    var dispatchingId: UUID?
    var dispatchError: String?

    // Filter
    var selectedFilter: AllocationStatus? = nil

    // MARK: - Dependencies

    private let service: AllocationServiceProtocol

    init(service: AllocationServiceProtocol = AllocationService.shared) {
        self.service = service
    }

    // MARK: - Computed

    var pendingAllocations: [AllocationDTO] {
        allocations.filter { $0.allocationStatus == .pending }
    }

    var inTransitAllocations: [AllocationDTO] {
        allocations.filter { $0.allocationStatus == .inTransit }
    }

    var completedAllocations: [AllocationDTO] {
        allocations.filter { $0.allocationStatus == .completed }
    }

    var filteredAllocations: [AllocationDTO] {
        guard let filter = selectedFilter else { return allocations }
        return allocations.filter { $0.allocationStatus == filter }
    }

    func locationName(for id: UUID) -> String {
        locations.first(where: { $0.id == id })?.name ?? id.uuidString.prefix(8) + "…"
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let allocs = service.fetchAllocations(status: nil)
            async let locs = service.fetchLocations()
            allocations = try await allocs
            locations = try await locs
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Dispatch Allocation (PENDING → IN_TRANSIT)

    func dispatchAllocation(_ allocation: AllocationDTO, performedBy: UUID?) async {
        guard allocation.allocationStatus == .pending else { return }
        dispatchingId = allocation.id
        dispatchError = nil
        defer { dispatchingId = nil }

        do {
            let response = try await service.dispatchAllocation(
                allocationId: allocation.id,
                performedBy: performedBy
            )

            if response.success {
                await loadData()
            } else {
                dispatchError = response.error ?? "Dispatch failed"
            }
        } catch {
            dispatchError = error.localizedDescription
        }
    }

    // MARK: - Complete Allocation (PENDING/IN_TRANSIT → COMPLETED)

    func completeAllocation(_ allocation: AllocationDTO, performedBy: UUID?) async {
        guard allocation.isCompletable else { return }
        completingId = allocation.id
        completionError = nil
        defer { completingId = nil }

        do {
            let response = try await service.completeAllocation(
                allocationId: allocation.id,
                performedBy: performedBy
            )

            if response.success {
                // Update local state immediately
                if let index = allocations.firstIndex(where: { $0.id == allocation.id }) {
                    // Refetch to get server state
                    await loadData()
                }
            } else {
                completionError = response.error ?? "Completion failed"
            }
        } catch {
            completionError = error.localizedDescription
        }
    }
}
