//
//  SalesDashboardViewModel.swift
//  RSMS
//
//  Fetches live KPI data for the Sales Associate dashboard:
//  today's POS sales total, total client count, and today's booking count.
//

import Foundation
import Supabase

@Observable
@MainActor
final class SalesDashboardViewModel {

    var todaySalesTotal: Double = 0
    var clientCount: Int = 0
    var todayBookingCount: Int = 0
    var todayAppointments: [AppointmentDTO] = []
    var clientsById: [UUID: ClientDTO] = [:]
    var isLoading = false

    private let db = SupabaseManager.shared.client

    func load(storeId: UUID?) async {
        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTodaySales(storeId: storeId) }
            group.addTask { await self.loadClientCount() }
            group.addTask { await self.loadTodaySchedule(storeId: storeId) }
        }
    }

    // MARK: - Today's Sales

    private func loadTodaySales(storeId: UUID?) async {
        guard let storeId else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let fmt = iso8601()

        struct Row: Decodable {
            let grandTotal: Double
            enum CodingKeys: String, CodingKey { case grandTotal = "grand_total" }
        }

        do {
            let rows: [Row] = try await db
                .from("orders")
                .select("grand_total")
                .eq("store_id", value: storeId.uuidString.lowercased())
                .eq("channel",  value: "in_store")
                .eq("status",   value: "completed")
                .gte("created_at", value: fmt.string(from: start))
                .lt("created_at",  value: fmt.string(from: end))
                .execute()
                .value
            todaySalesTotal = rows.reduce(0) { $0 + $1.grandTotal }
        } catch {
            print("[SalesDashboardVM] todaySales error: \(error)")
        }
    }

    // MARK: - Client Count

    private func loadClientCount() async {
        struct Row: Decodable { let id: UUID }
        do {
            let rows: [Row] = try await db
                .from("clients")
                .select("id")
                .execute()
                .value
            clientCount = rows.count
        } catch {
            print("[SalesDashboardVM] clientCount error: \(error)")
        }
    }

    // MARK: - Today's Schedule

    private func loadTodaySchedule(storeId: UUID?) async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        do {
            let appts: [AppointmentDTO]
            if let storeId {
                appts = try await AppointmentService.shared.fetchAppointments(forStoreId: storeId)
            } else {
                appts = []
            }
            let todayAppts = appts.filter {
                $0.scheduledAt >= start && $0.scheduledAt < end &&
                ["scheduled", "confirmed", "in_progress"].contains($0.status)
            }.sorted { $0.scheduledAt < $1.scheduledAt }

            todayAppointments = todayAppts
            todayBookingCount = todayAppts.count

            // Load client names for schedule display
            let ids = Array(Set(todayAppts.map(\.clientId)))
            if !ids.isEmpty {
                let clients = try await ClientService.shared.fetchClients(ids: ids)
                for c in clients { clientsById[c.id] = c }
            }
        } catch {
            print("[SalesDashboardVM] todaySchedule error: \(error)")
        }
    }

    // MARK: - Helpers

    var formattedTodaySales: String {
        let f = NumberFormatter()
        f.numberStyle  = .currency
        f.currencyCode = "INR"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: todaySalesTotal)) ?? "₹0"
    }

    private func iso8601() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }
}
