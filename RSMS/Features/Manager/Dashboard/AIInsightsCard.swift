//
//  AIInsightsCard.swift
//  RSMS
//
//  Reusable AI Insights card for manager/admin dashboards.
//  Displays on-device generated insights with expand/collapse.
//

import SwiftUI

struct AIInsightsCard: View {
    let insights: [AIInsightsEngine.DashboardInsight]
    @State private var isExpanded = true
    @State private var showAll = false

    private var displayedInsights: [AIInsightsEngine.DashboardInsight] {
        showAll ? insights : Array(insights.prefix(3))
    }

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.accent)

                        Text("AI INSIGHTS")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .foregroundColor(AppColors.accent)

                        Spacer()

                        Text("On-Device")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(displayedInsights) { insight in
                            insightRow(insight)
                            if insight.id != displayedInsights.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }

                        if insights.count > 3 {
                            Button {
                                withAnimation { showAll.toggle() }
                            } label: {
                                Text(showAll ? "Show Less" : "Show All \(insights.count) Insights")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Insight Row

    private func insightRow(_ insight: AIInsightsEngine.DashboardInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(insightColor(insight.type).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: insight.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(insightColor(insight.type))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(insight.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    insightBadge(insight.type)
                }

                Text(insight.detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func insightBadge(_ type: AIInsightsEngine.InsightType) -> some View {
        Group {
            switch type {
            case .positive:
                Text("GOOD")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            case .warning:
                Text("ALERT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            case .suggestion:
                Text("TIP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppColors.accent.opacity(0.12))
                    .clipShape(Capsule())
            case .neutral:
                EmptyView()
            }
        }
    }

    private func insightColor(_ type: AIInsightsEngine.InsightType) -> Color {
        switch type {
        case .positive: return .green
        case .warning: return .orange
        case .suggestion: return AppColors.accent
        case .neutral: return .blue
        }
    }
}
