//
//  AIInsightsEngine.swift
//  RSMS
//
//  On-device AI insights engine for manager/admin dashboards.
//  Generates natural language summaries, trend analysis, and actionable
//  suggestions from KPI data. No API keys — pure on-device logic.
//

import Foundation

@MainActor
final class AIInsightsEngine {

    static let shared = AIInsightsEngine()
    private init() {}

    // MARK: - Manager Dashboard Insights

    struct DashboardInsight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let type: InsightType
    }

    enum InsightType {
        case positive
        case warning
        case suggestion
        case neutral
    }

    /// Generates natural language insights from a manager's dashboard snapshot.
    func generateManagerInsights(snapshot: ManagerDashboardSnapshot) -> [DashboardInsight] {
        var insights: [DashboardInsight] = []

        let sales = snapshot.sales
        let appts = snapshot.appointments
        let staff = snapshot.staffRanking

        // ── Revenue Analysis ─────────────────────────────────────────
        let revenueProgress = sales.targetProgress
        if revenueProgress >= 1.0 {
            let overBy = Int((revenueProgress - 1.0) * 100)
            insights.append(DashboardInsight(
                icon: "chart.line.uptrend.xyaxis",
                title: "Revenue Target Exceeded",
                detail: "Outstanding performance! Revenue is \(overBy)% above target at \(formatCurrency(sales.actualRevenue)). The team is delivering strong results this period.",
                type: .positive
            ))
        } else if revenueProgress >= 0.8 {
            let remaining = formatCurrency(sales.revenueGap)
            insights.append(DashboardInsight(
                icon: "chart.line.uptrend.xyaxis",
                title: "Revenue On Track",
                detail: "Good progress at \(Int(revenueProgress * 100))% of target. \(remaining) remaining — consider promoting high-margin items or running a flash promotion to close the gap.",
                type: .neutral
            ))
        } else if revenueProgress >= 0.5 {
            insights.append(DashboardInsight(
                icon: "exclamationmark.triangle",
                title: "Revenue Below Pace",
                detail: "Revenue is at \(Int(revenueProgress * 100))% of target with \(formatCurrency(sales.revenueGap)) to go. Consider increasing walk-in engagement, upselling premium items, or activating dormant VIP clients.",
                type: .warning
            ))
        } else {
            insights.append(DashboardInsight(
                icon: "exclamationmark.triangle.fill",
                title: "Revenue Significantly Behind",
                detail: "Currently at \(Int(revenueProgress * 100))% of target. Immediate action needed: review staffing levels, plan a promotional event, and reach out to top-spending clients personally.",
                type: .warning
            ))
        }

        // ── Average Ticket Analysis ──────────────────────────────────
        if sales.averageTicket > 0 {
            if sales.transactions > 5 && sales.averageTicket < sales.actualRevenue / Double(max(sales.transactions, 1)) * 0.8 {
                insights.append(DashboardInsight(
                    icon: "indianrupeesign.circle",
                    title: "Boost Average Ticket Value",
                    detail: "Average ticket is \(formatCurrency(sales.averageTicket)). Train staff on pairing techniques — suggesting complementary items like straps with watches or care kits with leather goods can increase basket size by 15-25%.",
                    type: .suggestion
                ))
            }
        }

        // ── Conversion Rate ──────────────────────────────────────────
        if sales.conversionRate > 0 {
            if sales.conversionRate >= 0.4 {
                insights.append(DashboardInsight(
                    icon: "person.fill.checkmark",
                    title: "Strong Conversion Rate",
                    detail: "Conversion rate of \(Int(sales.conversionRate * 100))% is excellent. The team is effectively engaging walk-ins and turning browsers into buyers.",
                    type: .positive
                ))
            } else if sales.conversionRate < 0.2 {
                insights.append(DashboardInsight(
                    icon: "person.fill.questionmark",
                    title: "Low Conversion Rate",
                    detail: "Only \(Int(sales.conversionRate * 100))% of visitors are converting. Consider improving the greeting experience, product merchandising, and having staff proactively approach customers within 30 seconds of entry.",
                    type: .warning
                ))
            }
        }

        // ── Appointment Insights ─────────────────────────────────────
        if appts.totalBooked > 0 {
            if appts.completionRate >= 0.8 {
                insights.append(DashboardInsight(
                    icon: "calendar.badge.checkmark",
                    title: "High Appointment Completion",
                    detail: "\(Int(appts.completionRate * 100))% appointment completion rate — clients are showing up and engaged. This indicates strong pre-visit communication.",
                    type: .positive
                ))
            }

            if appts.noShow > 2 {
                insights.append(DashboardInsight(
                    icon: "calendar.badge.exclamationmark",
                    title: "\(appts.noShow) No-Shows Detected",
                    detail: "Consider sending SMS/email reminders 24 hours and 2 hours before appointments. Offering to reschedule proactively can reduce no-shows by up to 40%.",
                    type: .suggestion
                ))
            }

            if appts.cancelled > appts.completed {
                insights.append(DashboardInsight(
                    icon: "xmark.circle",
                    title: "High Cancellation Rate",
                    detail: "More cancellations (\(appts.cancelled)) than completions (\(appts.completed)). Review if appointment timing options are convenient, and consider follow-up calls to understand cancellation reasons.",
                    type: .warning
                ))
            }
        }

        // ── Staff Performance ────────────────────────────────────────
        if staff.count >= 2 {
            let sorted = staff.sorted { $0.revenue > $1.revenue }
            if let top = sorted.first, let bottom = sorted.last, top.revenue > 0 {
                let ratio = bottom.revenue / max(top.revenue, 1)
                if ratio < 0.3 {
                    insights.append(DashboardInsight(
                        icon: "person.2.wave.2",
                        title: "Staff Performance Gap",
                        detail: "\(top.name) leads with \(formatCurrency(top.revenue)) in revenue. Consider pairing \(bottom.name) (\(formatCurrency(bottom.revenue))) with the top performer for mentoring and product knowledge sharing.",
                        type: .suggestion
                    ))
                }
            }
        }

        // ── Unique Clients ───────────────────────────────────────────
        if sales.uniqueClients > 0 && sales.transactions > 0 {
            let repeatRate = Double(sales.transactions - sales.uniqueClients) / Double(sales.transactions)
            if repeatRate > 0.3 {
                insights.append(DashboardInsight(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Strong Client Loyalty",
                    detail: "\(Int(repeatRate * 100))% repeat purchase rate this period. These loyal clients are your core revenue drivers — consider exclusive previews or early access to new collections.",
                    type: .positive
                ))
            }
        }

        return insights
    }

    // MARK: - Admin Enterprise Insights

    /// Generates enterprise-level insights for the corporate admin dashboard.
    func generateAdminInsights(
        totalRevenue: Double,
        totalOrders: Int,
        totalProducts: Int,
        lowStockCount: Int,
        activeStaff: Int,
        totalClients: Int,
        storeCount: Int
    ) -> [DashboardInsight] {
        var insights: [DashboardInsight] = []

        // Revenue per store
        if storeCount > 0 {
            let revenuePerStore = totalRevenue / Double(storeCount)
            insights.append(DashboardInsight(
                icon: "building.2",
                title: "Revenue Distribution",
                detail: "Average revenue per boutique is \(formatCurrency(revenuePerStore)) across \(storeCount) locations. Monitor underperforming stores for staffing or merchandise mix adjustments.",
                type: .neutral
            ))
        }

        // Inventory Health
        if lowStockCount > 0 {
            let stockPercentage = totalProducts > 0 ? Double(lowStockCount) / Double(totalProducts) * 100 : 0
            if stockPercentage > 20 {
                insights.append(DashboardInsight(
                    icon: "shippingbox.fill",
                    title: "Inventory Alert",
                    detail: "\(lowStockCount) products (\(Int(stockPercentage))% of catalog) are at low or critical stock levels. Prioritize replenishment for fast-moving items to avoid missed sales opportunities.",
                    type: .warning
                ))
            } else {
                insights.append(DashboardInsight(
                    icon: "shippingbox",
                    title: "Inventory Health",
                    detail: "\(lowStockCount) products need restocking. Stock levels are generally healthy with \(Int(100 - stockPercentage))% of catalog well-stocked.",
                    type: .neutral
                ))
            }
        }

        // Staff efficiency
        if activeStaff > 0 && totalOrders > 0 {
            let ordersPerStaff = Double(totalOrders) / Double(activeStaff)
            insights.append(DashboardInsight(
                icon: "person.3",
                title: "Staff Productivity",
                detail: "Average \(String(format: "%.1f", ordersPerStaff)) transactions per staff member this period. \(ordersPerStaff < 5 ? "Consider cross-training staff or reviewing scheduling to improve utilization." : "Solid productivity levels across the team.")",
                type: ordersPerStaff < 5 ? .suggestion : .positive
            ))
        }

        // Client base growth signal
        if totalClients > 0 {
            insights.append(DashboardInsight(
                icon: "person.crop.circle.badge.plus",
                title: "Client Base",
                detail: "\(totalClients) registered clients across all boutiques. Focus on converting walk-in customers to registered profiles — tracked clients spend on average 2.5x more than anonymous visitors.",
                type: .suggestion
            ))
        }

        return insights
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
