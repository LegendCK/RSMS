//
//  ManagerOperationsView.swift
//  RSMS
//
//  Boutique Manager store operations — sales transactions, discrepancies, VIP events, activity log.
//  The Discrepancies tab shows live data from Supabase. Any staff/manager can report a new
//  discrepancy via the "+" button; only managers can approve/reject (in Inventory → Requests).
//

import SwiftUI
import SwiftData

struct ManagerOperationsView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Product.name) private var allProducts: [Product]
    @State private var selectedSection = 0
    @State private var showAddStock = false
    @State private var showInventoryWorkspace = false
    @State private var showReportDiscrepancy = false

    // Live discrepancy data
    @State private var liveDiscrepancies: [InventoryDiscrepancyDTO] = []
    @State private var isLoadingDiscrepancies = false
    @State private var discrepancyLoadError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Sales").tag(0)
                        Text("BOPIS").tag(1)
                        Text("Discrepancies").tag(2)
                        Text("VIP Events").tag(3)
                        Text("Activity").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: salesSection
                    case 1: bopisSection
                    case 2: discrepanciesSection
                    case 3: vipEventsSection
                    case 4: activitySection
                    default: salesSection
                    }
                }

                // ✅ FAB is now inside ZStack so it overlays content correctly
                // instead of stacking vertically and eating half the screen.
                if appState.currentUserRole == .inventoryController {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showAddStock = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(AppColors.accent)
                                    .clipShape(Circle())
                                    .shadow(color: AppColors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .accessibilityLabel("Add Stock")
                            .padding(.trailing, AppSpacing.screenHorizontal)
                            .padding(.bottom, AppSpacing.md)
                        }
                    }
                    // No ignoresSafeArea here — lets SwiftUI respect the tab bar inset
                    // so the FAB sits above the tab bar, not on top of it.
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Operations").font(AppTypography.navTitle).foregroundColor(AppColors.textPrimaryDark)
                }
                // Report Discrepancy button — visible only on the Discrepancies tab
                if selectedSection == 2 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showReportDiscrepancy = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(AppTypography.iconMedium)
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Report Discrepancy")
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showInventoryWorkspace = true
                        } label: {
                            Image(systemName: "shippingbox")
                                .font(AppTypography.iconMedium)
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Open Inventory Workspace")
                    }
                }
            }
            .navigationDestination(isPresented: $showInventoryWorkspace) {
                ManagerInventoryView()
            }
            .sheet(isPresented: $showReportDiscrepancy) {
                ReportDiscrepancySheet(products: allProducts) {
                    // Refresh list after submission
                    Task { await loadLiveDiscrepancies() }
                }
            }
            .task {
                await loadLiveDiscrepancies()
            }
        }
        .sheet(isPresented: $showAddStock) {
            InventoryAddStockView()
        }
    }

    // MARK: - Sales Transactions

    private var salesSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                // Today summary
                HStack(spacing: AppSpacing.sm) {
                    miniStat(value: "$42.8K", label: "Today", color: AppColors.accent)
                    miniStat(value: "7", label: "Txns", color: AppColors.secondary)
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
                    Text(associate).font(AppTypography.micro).foregroundColor(AppColors.secondary)
                }
                Spacer()
                Text(amount).font(AppTypography.label).foregroundColor(AppColors.accent)
            }
        }
        .padding(AppSpacing.sm)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
    
    // MARK: - BOPIS & Ship-from-Store Monitor

    private var bopisSection: some View {
        BOPISOrderMonitorView()
            .environment(appState)
    }

    // MARK: - Discrepancies (Live)

    private var discrepanciesSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                // Summary Stats
                let pending  = liveDiscrepancies.filter { $0.status == "pending" }
                let resolved = liveDiscrepancies.filter { $0.status != "pending" }

                HStack(spacing: AppSpacing.sm) {
                    miniStat(value: "\(pending.count)",  label: "Pending",  color: AppColors.warning)
                    miniStat(value: "\(resolved.count)", label: "Resolved", color: AppColors.success)
                    miniStat(value: "\(liveDiscrepancies.count)", label: "Total", color: AppColors.accent)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                if isLoadingDiscrepancies {
                    ProgressView("Loading...")
                        .padding(.top, AppSpacing.xl)
                } else if let errMsg = discrepancyLoadError {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "wifi.slash").foregroundColor(AppColors.warning)
                        Text(errMsg)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.lg)
                } else if liveDiscrepancies.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(AppColors.success)
                        Text("No discrepancies reported")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("Tap \(Image(systemName: "plus.circle")) in the top-right to file a report.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xxl)
                } else {
                    if !pending.isEmpty {
                        sLabel("PENDING REVIEW")
                        ForEach(pending) { item in
                            liveDiscrepancyCard(item)
                        }
                    }
                    if !resolved.isEmpty {
                        sLabel("RESOLVED")
                        ForEach(resolved.prefix(10)) { item in
                            liveDiscrepancyCard(item)
                        }
                    }
                }
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
        .refreshable { await loadLiveDiscrepancies() }
    }

    private func liveDiscrepancyCard(_ item: InventoryDiscrepancyDTO) -> some View {
        let statusColor: Color = item.status == "pending" ? AppColors.warning :
                                 item.status == "approved" ? AppColors.success : AppColors.error
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(item.productName.isEmpty ? "Unknown Product" : item.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text(item.status.uppercased())
                    .font(AppTypography.nano)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor.opacity(0.12)).cornerRadius(4)
            }
            HStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                    Text("\(item.systemQuantity)").font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reported").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                    Text("\(item.reportedQuantity)").font(AppTypography.label)
                        .foregroundColor(item.systemQuantity != item.reportedQuantity ? AppColors.error : AppColors.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delta").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                    Text("\(item.reportedQuantity - item.systemQuantity)").font(AppTypography.label)
                        .foregroundColor(AppColors.error)
                }
            }
            HStack {
                Label(item.reportedByName.isEmpty ? "Staff" : item.reportedByName, systemImage: "person")
                    .font(AppTypography.caption).foregroundColor(AppColors.secondary)
                Text("·").foregroundColor(AppColors.neutral600)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                Spacer()
                if item.status == "pending" && appState.currentUserRole == .boutiqueManager {
                    Text("Review in Inventory → Requests")
                        .font(AppTypography.nano)
                        .foregroundColor(AppColors.accent)
                        .italic()
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func loadLiveDiscrepancies() async {
        guard let storeId = appState.currentStoreId else { return }
        isLoadingDiscrepancies = true
        discrepancyLoadError = nil
        defer { isLoadingDiscrepancies = false }
        do {
            liveDiscrepancies = try await DiscrepancyService.shared.fetchDiscrepancies(storeId: storeId)
        } catch {
            discrepancyLoadError = error.localizedDescription
        }
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
                    Text(type).font(AppTypography.caption).foregroundColor(AppColors.secondary)
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
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
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
            .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
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
                Text(by).font(AppTypography.micro).foregroundColor(AppColors.secondary)
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
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    ManagerOperationsView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}

// MARK: - Report Discrepancy Sheet

struct ReportDiscrepancySheet: View {
    let products: [Product]
    let onSubmitted: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product? = nil
    @State private var countedQtyText: String = ""
    @State private var reason: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var countedQty: Int? { Int(countedQtyText.trimmingCharacters(in: .whitespacesAndNewlines)) }

    private var isValid: Bool {
        selectedProduct != nil &&
        countedQty != nil &&
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {

                    // Info Banner
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppColors.info)
                        Text("Report a count discrepancy for manager review. They will approve or reject the correction.")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.info.opacity(0.08))
                    .cornerRadius(AppSpacing.radiusSmall)

                    // Product Selection
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("PRODUCT")
                            .font(AppTypography.overline).tracking(2)
                            .foregroundColor(AppColors.accent)

                        if products.isEmpty {
                            Text("No products found. Sync inventory first.")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .padding(AppSpacing.sm)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        } else {
                            Picker("Select Product", selection: $selectedProduct) {
                                Text("Choose product...").tag(Product?.none)
                                ForEach(products) { product in
                                    Text("\(product.name) (System: \(product.stockCount))").tag(product as Product?)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }

                        if let product = selectedProduct {
                            HStack(spacing: 4) {
                                Image(systemName: "server.rack").font(.system(size: 11))
                                    .foregroundColor(AppColors.secondary)
                                Text("System shows \(product.stockCount) units in records")
                                    .font(AppTypography.micro)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // Counted Quantity
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("PHYSICAL COUNT")
                            .font(AppTypography.overline).tracking(2)
                            .foregroundColor(AppColors.accent)
                        TextField("Enter quantity you physically counted", text: $countedQtyText)
                            .keyboardType(.numberPad)
                            .font(AppTypography.bodyMedium)
                            .padding(AppSpacing.sm)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)

                        if let product = selectedProduct, let counted = countedQty {
                            let delta = counted - product.stockCount
                            HStack(spacing: 4) {
                                Image(systemName: delta == 0 ? "checkmark.circle" : (delta < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill"))
                                    .foregroundColor(delta == 0 ? AppColors.success : AppColors.warning)
                                Text(delta == 0 ? "Matches system record" :
                                     "\(abs(delta)) unit\(abs(delta) == 1 ? "" : "s") \(delta < 0 ? "fewer" : "more") than system (\(product.stockCount))")
                                    .font(AppTypography.micro)
                                    .foregroundColor(delta == 0 ? AppColors.success : AppColors.warning)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // Reason
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("REASON / NOTES")
                            .font(AppTypography.overline).tracking(2)
                            .foregroundColor(AppColors.accent)
                        Text("Explain what you found, when you counted, and any relevant context.")
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textSecondaryDark)
                        TextEditor(text: $reason)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .frame(height: 100)
                            .padding(AppSpacing.xs)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // Submit Button
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                        } else {
                            Label("Submit Discrepancy Report", systemImage: "flag.fill")
                                .font(AppTypography.label)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                        }
                    }
                    .background(isValid ? AppColors.accent : AppColors.neutral500)
                    .cornerRadius(AppSpacing.radiusMedium)
                    .disabled(!isValid || isSubmitting)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("Report Discrepancy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Submission Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submit() async {
        guard let product = selectedProduct,
              let counted = countedQty,
              let storeId = appState.currentStoreId,
              let userId = appState.currentUserProfile?.id else {
            errorMessage = "Missing required information. Ensure you are assigned to a store and logged in fully."
            showError = true
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let dto = DiscrepancyInsertDTO(
            storeId:          storeId,
            productId:        product.id,
            productName:      product.name,
            reportedQuantity: counted,
            systemQuantity:   product.stockCount,
            reason:           reason.trimmingCharacters(in: .whitespacesAndNewlines),
            reportedBy:       userId,
            reportedByName:   appState.currentUserName.isEmpty ? "Staff" : appState.currentUserName
        )

        do {
            _ = try await DiscrepancyService.shared.submitDiscrepancy(dto: dto)
            onSubmitted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
