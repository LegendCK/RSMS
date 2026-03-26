import Foundation
import Supabase

enum ManagerDashboardSignalSeverity: String, Codable {
    case positive
    case attention
    case warning
}

struct ManagerDashboardOperationalSignal: Codable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let severity: ManagerDashboardSignalSeverity
}

struct ManagerDashboardSalesMetrics: Codable {
    let actualRevenue: Double
    let targetRevenue: Double
    let transactions: Int
    let averageTicket: Double
    let conversionRate: Double
    let uniqueClients: Int

    var targetProgress: Double {
        guard targetRevenue > 0 else { return 0 }
        return actualRevenue / targetRevenue
    }

    var revenueGap: Double {
        targetRevenue - actualRevenue
    }
}

struct ManagerDashboardAppointmentMetrics: Codable {
    let totalBooked: Int
    let confirmed: Int
    let completed: Int
    let cancelled: Int
    let noShow: Int
    let upcomingToday: Int
    let upcomingThisWeek: Int
    let completionRate: Double
}

struct ManagerDashboardStaffPerformance: Codable, Identifiable {
    let id: UUID
    let name: String
    let role: String
    let revenue: Double
    let transactions: Int
    let appointmentsHandled: Int
    let conversionRate: Double
}

struct ManagerDashboardSnapshot: Codable {
    let storeId: UUID
    let syncedAt: Date
    let periodStart: Date
    let sales: ManagerDashboardSalesMetrics
    let appointments: ManagerDashboardAppointmentMetrics
    let staffRanking: [ManagerDashboardStaffPerformance]
    let operationalSignals: [ManagerDashboardOperationalSignal]
}

@MainActor
final class ManagerDashboardService {
    static let shared = ManagerDashboardService()

    private let client = SupabaseManager.shared.client
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let calendar = Calendar.current

    private init() {}

    func cachedSnapshot(for storeId: UUID) -> ManagerDashboardSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: storeId)) else {
            return nil
        }

        return try? decoder.decode(ManagerDashboardSnapshot.self, from: data)
    }

    func refreshSnapshot(for storeId: UUID) async throws -> ManagerDashboardSnapshot {
        async let orders = fetchOrders(for: storeId)
        async let appointments = fetchAppointments(for: storeId)
        async let staff = fetchStaff(for: storeId)
        async let store = fetchStore(for: storeId)

        let snapshot = buildSnapshot(
            storeId: storeId,
            orders: try await orders,
            appointments: try await appointments,
            staff: try await staff,
            store: try await store
        )

        if let data = try? encoder.encode(snapshot) {
            UserDefaults.standard.set(data, forKey: cacheKey(for: storeId))
        }

        return snapshot
    }

    private func fetchStore(for storeId: UUID) async throws -> StoreDTO {
        try await client
            .from("stores")
            .select()
            .eq("id", value: storeId.uuidString.lowercased())
            .single()
            .execute()
            .value
    }

    private func fetchOrders(for storeId: UUID) async throws -> [OrderDTO] {
        try await client
            .from("orders")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func fetchAppointments(for storeId: UUID) async throws -> [AppointmentDTO] {
        try await client
            .from("appointments")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .order("scheduled_at", ascending: false)
            .execute()
            .value
    }

    private func fetchStaff(for storeId: UUID) async throws -> [UserDTO] {
        try await client
            .from("users")
            .select()
            .eq("store_id", value: storeId.uuidString.lowercased())
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func buildSnapshot(
        storeId: UUID,
        orders: [OrderDTO],
        appointments: [AppointmentDTO],
        staff: [UserDTO],
        store: StoreDTO
    ) -> ManagerDashboardSnapshot {
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)

        let activeOrders = orders.filter { normalizedStatus($0.status) != "cancelled" }
        let monthOrders = activeOrders.filter { monthInterval.contains($0.createdAt) }
        let monthAppointments = appointments.filter { monthInterval.contains($0.scheduledAt) }

        let transactionCount = monthOrders.count
        let actualRevenue = monthOrders.reduce(0) { $0 + $1.grandTotal }
        let averageTicket = transactionCount == 0 ? 0 : actualRevenue / Double(transactionCount)
        let uniqueClients = Set(monthOrders.compactMap(\ .clientId)).count

        let attendedAppointments = monthAppointments.filter {
            let status = normalizedStatus($0.status)
            return $0.scheduledAt <= now && status != "cancelled" && status != "no_show"
        }
        let conversionRate: Double
        if attendedAppointments.isEmpty {
            conversionRate = transactionCount > 0 ? 1 : 0
        } else {
            conversionRate = min(Double(transactionCount) / Double(attendedAppointments.count), 1)
        }

        let targetRevenue = resolvedMonthlyTarget(for: store)
        let sales = ManagerDashboardSalesMetrics(
            actualRevenue: actualRevenue,
            targetRevenue: targetRevenue,
            transactions: transactionCount,
            averageTicket: averageTicket,
            conversionRate: conversionRate,
            uniqueClients: uniqueClients
        )

        let historicalAppointments = monthAppointments.filter { $0.scheduledAt <= now }
        let completedCount = monthAppointments.filter { normalizedStatus($0.status) == "completed" }.count
        let completionBase = max(historicalAppointments.count, 1)
        let appointmentsSummary = ManagerDashboardAppointmentMetrics(
            totalBooked: monthAppointments.count,
            confirmed: monthAppointments.filter { ["scheduled", "confirmed"].contains(normalizedStatus($0.status)) }.count,
            completed: completedCount,
            cancelled: monthAppointments.filter { normalizedStatus($0.status) == "cancelled" }.count,
            noShow: monthAppointments.filter { normalizedStatus($0.status) == "no_show" }.count,
            upcomingToday: futureAppointments(from: appointments, now: now, withinDays: 1),
            upcomingThisWeek: futureAppointments(from: appointments, now: now, withinDays: 7),
            completionRate: Double(completedCount) / Double(completionBase)
        )

        let rankedStaff = buildStaffRanking(staff: staff, orders: monthOrders, appointments: monthAppointments)

        return ManagerDashboardSnapshot(
            storeId: storeId,
            syncedAt: now,
            periodStart: monthInterval.start,
            sales: sales,
            appointments: appointmentsSummary,
            staffRanking: rankedStaff,
            operationalSignals: buildSignals(sales: sales, appointments: appointmentsSummary, staffRanking: rankedStaff)
        )
    }

    private func buildStaffRanking(
        staff: [UserDTO],
        orders: [OrderDTO],
        appointments: [AppointmentDTO]
    ) -> [ManagerDashboardStaffPerformance] {
        let eligibleRoles: Set<UserRole> = [.salesAssociate, .serviceTechnician, .boutiqueManager]
        let eligibleStaff = staff
            .filter { $0.isActive && eligibleRoles.contains($0.userRole) }

        let rankingSource = eligibleStaff.isEmpty ? staff.filter(\ .isActive) : eligibleStaff

        return rankingSource
            .map { user in
                let userOrders = orders.filter { $0.associateId == user.id }
                let relevantAppointments = appointments.filter {
                    $0.associateId == user.id && normalizedStatus($0.status) != "cancelled"
                }
                let conversionRate: Double
                if relevantAppointments.isEmpty {
                    conversionRate = userOrders.isEmpty ? 0 : 1
                } else {
                    conversionRate = min(Double(userOrders.count) / Double(relevantAppointments.count), 1)
                }

                return ManagerDashboardStaffPerformance(
                    id: user.id,
                    name: user.fullName,
                    role: user.userRole.rawValue,
                    revenue: userOrders.reduce(0) { $0 + $1.grandTotal },
                    transactions: userOrders.count,
                    appointmentsHandled: relevantAppointments.count,
                    conversionRate: conversionRate
                )
            }
            .sorted {
                if $0.revenue != $1.revenue { return $0.revenue > $1.revenue }
                if $0.transactions != $1.transactions { return $0.transactions > $1.transactions }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func buildSignals(
        sales: ManagerDashboardSalesMetrics,
        appointments: ManagerDashboardAppointmentMetrics,
        staffRanking: [ManagerDashboardStaffPerformance]
    ) -> [ManagerDashboardOperationalSignal] {
        var signals: [ManagerDashboardOperationalSignal] = []

        if sales.targetProgress < 0.8 {
            signals.append(
                ManagerDashboardOperationalSignal(
                    id: "revenue-gap",
                    title: "Revenue pace is behind target",
                    detail: "Close \(currency(abs(sales.revenueGap))) this month by prioritizing high-intent clients and same-day follow-ups.",
                    severity: .warning
                )
            )
        } else {
            signals.append(
                ManagerDashboardOperationalSignal(
                    id: "revenue-pace",
                    title: "Revenue pace is healthy",
                    detail: "The boutique is tracking at \(percent(sales.targetProgress)) of target with \(sales.transactions) closed transactions.",
                    severity: .positive
                )
            )
        }

        if sales.conversionRate < 0.35 {
            signals.append(
                ManagerDashboardOperationalSignal(
                    id: "conversion",
                    title: "Conversion is soft",
                    detail: "Review appointment handoffs and elevate top-ranked advisors on high-value consultations.",
                    severity: .attention
                )
            )
        }

        let noShowRate = appointments.totalBooked == 0 ? 0 : Double(appointments.noShow) / Double(appointments.totalBooked)
        if noShowRate > 0.15 {
            signals.append(
                ManagerDashboardOperationalSignal(
                    id: "no-show",
                    title: "No-show rate needs attention",
                    detail: "\(appointments.noShow) no-shows this month. Trigger confirmation reminders for upcoming appointments.",
                    severity: .attention
                )
            )
        }

        if let topPerformer = staffRanking.first, topPerformer.revenue > 0 {
            signals.append(
                ManagerDashboardOperationalSignal(
                    id: "top-performer",
                    title: "Top performer this month",
                    detail: "\(topPerformer.name) has generated \(currency(topPerformer.revenue)) across \(topPerformer.transactions) transactions.",
                    severity: .positive
                )
            )
        }

        return Array(signals.prefix(3))
    }

    private func resolvedMonthlyTarget(for store: StoreDTO) -> Double {
        return 300_000
    }

    private func futureAppointments(from appointments: [AppointmentDTO], now: Date, withinDays days: Int) -> Int {
        guard let endDate = calendar.date(byAdding: .day, value: days, to: now) else { return 0 }
        return appointments.filter {
            let status = normalizedStatus($0.status)
            return $0.scheduledAt >= now && $0.scheduledAt <= endDate && ["scheduled", "confirmed"].contains(status)
        }.count
    }

    private func normalizedStatus(_ status: String) -> String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func cacheKey(for storeId: UUID) -> String {
        "manager.dashboard.snapshot.\(storeId.uuidString.lowercased())"
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}