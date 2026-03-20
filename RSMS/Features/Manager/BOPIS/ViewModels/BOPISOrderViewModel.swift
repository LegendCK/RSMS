//
//  BOPISOrderViewModel.swift
//  RSMS
//
//  ViewModel for the Boutique Manager BOPIS / Ship-from-Store monitor.
//  Fetches orders from Supabase, computes SLA alerts, persists for offline use,
//  and re-evaluates SLA status every 60 seconds via a timer.
//
//  Fallback: when Supabase returns zero rows (empty dev DB / demo mode),
//  BOPISOrderSeedData.generate() is used so the UI is never blank.
//

import SwiftUI
import Supabase

// MARK: - SLA Sort Priority Helper

private func slaPriority(_ s: SLAStatus) -> Int {
    switch s {
    case .breached: return 2
    case .atRisk:   return 1
    case .onTime:   return 0
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class BOPISOrderViewModel {

    // MARK: - State

    var orders: [BOPISOrder] = []
    var isLoading = false
    var isOffline = false
    var errorMessage: String?
    var selectedChannel: ChannelFilter = .all
    var selectedSLA: SLAFilter = .all
    var searchText: String = ""

    // MARK: - Filter Enums

    enum ChannelFilter: String, CaseIterable, Identifiable {
        case all            = "All"
        case bopis          = "Pick-Up"
        case shipFromStore  = "Ship-Out"

        var id: String { rawValue }

        var channel: BOPISChannel? {
            switch self {
            case .all:           return nil
            case .bopis:         return .bopis
            case .shipFromStore: return .shipFromStore
            }
        }
    }

    enum SLAFilter: String, CaseIterable, Identifiable {
        case all      = "All"
        case atRisk   = "At Risk"
        case breached = "Overdue"

        var id: String { rawValue }
    }

    // MARK: - Derived

    var filteredOrders: [BOPISOrder] {
        var result = orders

        if let ch = selectedChannel.channel {
            result = result.filter { $0.channel == ch }
        }

        switch selectedSLA {
        case .all:      break
        case .atRisk:   result = result.filter { $0.slaStatus == .atRisk }
        case .breached: result = result.filter { $0.slaStatus == .breached }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.orderNumber.lowercased().contains(q) ||
                $0.clientEmail.lowercased().contains(q)
            }
        }

        return result.sorted {
            let lp = slaPriority($0.slaStatus)
            let rp = slaPriority($1.slaStatus)
            if lp != rp { return lp > rp }
            return $0.pickupDeadline < $1.pickupDeadline
        }
    }

    var totalAlerts: Int {
        orders.filter { $0.slaStatus == .breached || $0.slaStatus == .atRisk }.count
    }

    var breachedCount: Int { orders.filter { $0.slaStatus == .breached }.count }
    var atRiskCount: Int   { orders.filter { $0.slaStatus == .atRisk }.count }
    var activeCount: Int   { orders.filter { !$0.isTerminal }.count }

    // MARK: - Private

    private var refreshTimer: Timer?
    private let client = SupabaseManager.shared.client

    // MARK: - Lifecycle

    func onAppear(storeId: UUID?) async {
        loadCache()
        await fetch(storeId: storeId)
        startTimer()
    }

    func onDisappear() {
        stopTimer()
    }

    func pullToRefresh(storeId: UUID?) async {
        await fetch(storeId: storeId)
    }

    // MARK: - Fetch

    func fetch(storeId: UUID?) async {
        guard let storeId else {
            // No store assigned — show seed data so the UI is never blank
            if orders.isEmpty { orders = BOPISOrderSeedData.generate() }
            isOffline = false
            return
        }

        if orders.isEmpty { isLoading = true }
        errorMessage = nil

        do {
            let rows: [_BOPISOrderDTO] = try await client
                .from("orders")
                .select("id, order_number, channel, status, client_email, grand_total, currency, created_at")
                .eq("store_id", value: storeId.uuidString)
                .in("channel", values: ["bopis", "ship_from_store"])
                .not("status", operator: .in, value: "(completed,cancelled,delivered)")
                .order("created_at", ascending: false)
                .limit(150)
                .execute()
                .value

            let fetched = rows.compactMap { BOPISOrder.from(dto: $0) }

            // Supabase returned nothing (empty dev DB / demo mode) → use seed data
            orders = fetched.isEmpty ? BOPISOrderSeedData.generate() : fetched
            isOffline = false
            BOPISOrderCache.save(orders)
        } catch {
            let cached = BOPISOrderCache.load()
            if !cached.isEmpty {
                orders = cached
                isOffline = true
            } else {
                // Network failed and no cache → still show seed data
                orders = BOPISOrderSeedData.generate()
            }
            errorMessage = isOffline
                ? "Showing cached data — connect to refresh."
                : nil
        }

        isLoading = false
    }

    // MARK: - Cache

    private func loadCache() {
        let cached = BOPISOrderCache.load()
        guard !cached.isEmpty else { return }
        orders = cached
        isOffline = true
    }

    // MARK: - Timer (ticks every 60 s to refresh SLA time-remaining labels)

    private func startTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nudgeObservation()
            }
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func nudgeObservation() {
        orders = orders
    }
}
