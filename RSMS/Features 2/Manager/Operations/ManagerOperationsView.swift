//
//  ManagerOperationsView.swift
//  infosys2
//
//  Boutique Manager store operations — sales transactions, discrepancies, VIP events, activity log.
//

import SwiftUI
import SwiftData

struct ManagerOperationsView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Sales").tag(0)
                        Text("Discrepancies").tag(1)
                        Text("VIP Events").tag(2)
                        Text("Activity").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: salesSection
                    case 1: discrepanciesSection
                    case 2: vipEventsSection
                    case 3: activitySection
                    default: salesSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Operations").font(AppTypography.navTitle).foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }

    // MARK: - Sales Transactions

    private var salesSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                // Today summary
                HStack(spacing: AppSpacing.sm) {
                    miniStat(value: "$42.8K", label: "Today", color: AppColors.accent)
                    miniStat(value: "7", label: "Txns", color: AppColors.purple)
                    miniStat(value: "$6.1K", label: "Avg", color: AppColors.success)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, AppSpacing.sm)

                sLabel("RECENT TRANSACTIONS")

                txnRow(id: "TXN-4821", customer: "Mrs. Eleanor Voss", items: "Perpetual Chronograph", amount: "$12,500", time: "11:42 AM", associate: "Alexander C.")
                txnRow(id: "TXN-4820", customer: "Mr. James Liu", items: "Classic Flap Bag, Silk Scarf", amount: "$5,740", time: "10:15 AM", associate: "Isabella M.")
                txnRow(id: "TXN-4819", customer: "Ms. Priya Kapoor", items: "Diamond Bezel Watch", amount: "$8,900", time: "9:38 AM", associate: "Alexander C.")
                txnRow(id: "TXN-4818", customer: "Mr. David Park", items: "Gold Bracelet", amount: "$7,500", time: "Yesterday", associate: "Isabella M.")
                txnRow(id: "TXN-4817", customer: "Mrs. Sofia Andersson", items: "Pearl Earrings, Leather Belt", amount: "$4,850", time: "Yesterday", associate: "Alexander C.")
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func txnRow(id: String, customer: String, items: String, amount: String, time: String, associate: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(id).font(AppTypography.monoID).foregroundColor(AppColors.neutral500)
                Spacer()
                Text(time).font(AppTypography.caption).foregroundColor(AppColors.neutral500)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text(items).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark).lineLimit(1)
                    Text(associate).font(AppTypography.micro).foregroundColor(AppColors.purple)
                }
                Spacer()
                Text(amount).font(AppTypography.label).foregroundColor(AppColors.accent)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Discrepancies

    private var discrepanciesSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    miniStat(value: "2", label: "Pending", color: AppColors.warning)
                    miniStat(value: "5", label: "Resolved", color: AppColors.success)
                    miniStat(value: "0", label: "Escalated", color: AppColors.error)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, AppSpacing.sm)

                sLabel("PENDING REVIEW")

                discrepancyCard(sku: "Pearl Earrings", system: 6, counted: 5, flaggedBy: "Daniel Park", time: "2h ago", status: "Pending")
                discrepancyCard(sku: "Leather Belt", system: 20, counted: 18, flaggedBy: "Daniel Park", time: "5h ago", status: "Pending")

                sLabel("RECENTLY RESOLVED")

                discrepancyCard(sku: "Silk Scarf", system: 14, counted: 15, flaggedBy: "Daniel Park", time: "1d ago", status: "Resolved")
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func discrepancyCard(sku: String, system: Int, counted: Int, flaggedBy: String, time: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(sku).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                let statusColor = status == "Pending" ? AppColors.warning : AppColors.success
                Text(status.uppercased()).font(AppTypography.nano).foregroundColor(statusColor)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(statusColor.opacity(0.12)).cornerRadius(4)
            }
            HStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                    Text("\(system)").font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Counted").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                    Text("\(counted)").font(AppTypography.label).foregroundColor(system != counted ? AppColors.error : AppColors.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Variance").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                    Text("\(counted - system)").font(AppTypography.label).foregroundColor(AppColors.error)
                }
            }
            HStack {
                Text("Flagged by \(flaggedBy)").font(AppTypography.caption).foregroundColor(AppColors.purple)
                Text("•").foregroundColor(AppColors.neutral600)
                Text(time).font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                Spacer()
                if status == "Pending" {
                    Button(action: {}) {
                        Text("Approve").font(AppTypography.actionSmall).foregroundColor(AppColors.accent)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(AppColors.accent.opacity(0.12)).cornerRadius(6)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - VIP Events

    private var vipEventsSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                sLabel("TODAY")

                vipCard(client: "Mrs. Eleanor Chen", type: "Private Viewing", time: "3:00 PM", associate: "Alexander C.", items: "Limited Ed. Collection", status: "Confirmed")
                vipCard(client: "Mr. Robert Thornton", type: "Purchase Consultation", time: "5:30 PM", associate: "Isabella M.", items: "Perpetual Chronograph", status: "Confirmed")

                sLabel("UPCOMING")

                vipCard(client: "Ms. Aiko Tanaka", type: "Styling Session", time: "Tomorrow 11:00 AM", associate: "Alexander C.", items: "Spring 2026 Collection", status: "Pending")
                vipCard(client: "Mr. François Dubois", type: "Anniversary Gift", time: "Mar 12 2:00 PM", associate: "Isabella M.", items: "Diamond Pendant", status: "Confirmed")
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func vipCard(client: String, type: String, time: String, associate: String, items: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(client).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text(type).font(AppTypography.caption).foregroundColor(AppColors.purple)
                }
                Spacer()
                let sc = status == "Confirmed" ? AppColors.success : AppColors.warning
                Text(status.uppercased()).font(AppTypography.nano).foregroundColor(sc)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(sc.opacity(0.12)).cornerRadius(4)
            }
            Divider().background(AppColors.border)
            HStack(spacing: AppSpacing.xl) {
                Label(time, systemImage: "clock").font(AppTypography.caption).foregroundColor(AppColors.accent)
                Label(associate, systemImage: "person").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Text("Items: \(items)").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Activity Log

    private var activitySection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                activityRow(action: "Sale Completed", detail: "TXN-4821 — Perpetual Chronograph — $12,500", by: "Alexander C.", time: "11:42 AM")
                Divider().background(AppColors.border)
                activityRow(action: "Inventory Count", detail: "Pearl Earrings — discrepancy flagged (6→5)", by: "Daniel Park", time: "10:30 AM")
                Divider().background(AppColors.border)
                activityRow(action: "Sale Completed", detail: "TXN-4820 — Classic Flap, Silk Scarf — $5,740", by: "Isabella M.", time: "10:15 AM")
                Divider().background(AppColors.border)
                activityRow(action: "Store Opened", detail: "Fifth Avenue Boutique — daily check complete", by: "James Beaumont", time: "9:00 AM")
                Divider().background(AppColors.border)
                activityRow(action: "VIP Confirmed", detail: "Mrs. Chen — private viewing 3:00 PM", by: "Alexander C.", time: "8:45 AM")
                Divider().background(AppColors.border)
                activityRow(action: "Transfer Received", detail: "Sport Diver ×2 from Newark DC", by: "Daniel Park", time: "Yesterday")
            }
            .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func activityRow(action: String, detail: String, by: String, time: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(AppColors.accent).frame(width: 5, height: 5)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(action).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    Text(time).font(AppTypography.iconCompact).foregroundColor(AppColors.neutral500)
                }
                Text(detail).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark).lineLimit(1)
                Text(by).font(AppTypography.micro).foregroundColor(AppColors.purple)
            }
        }
        .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs + 2)
    }

    // MARK: - Helpers

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(AppTypography.heading2).foregroundColor(color)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    ManagerOperationsView()
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
