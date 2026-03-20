//
//  ManagerInventoryView.swift
//  infosys2
//
//  Boutique Manager inventory oversight — stock levels, low stock alerts,
//  transfer receiving with ASN matching, and flagged items.
//

import SwiftUI
import SwiftData

struct ManagerInventoryView: View {
    @State private var selectedSection = 0
    @State private var showTransferRequest = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Stock").tag(0)
                        Text("Alerts").tag(1)
                        Text("Transfers").tag(2)
                        Text("Flagged").tag(3)
                        Text("Requests").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: InvStockSubview()
                    case 1: InvAlertsSubview()
                    case 2: InvTransfersSubview()
                    case 3: InvFlaggedSubview()
                    case 4: InvDiscrepanciesSubview()
                    default: InvStockSubview()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Inventory")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showTransferRequest = true }) { Label("Request Transfer", systemImage: "arrow.left.arrow.right") }
                        Button(action: {}) { Label("Start Count", systemImage: "checklist") }
                        Button(action: {}) { Label("Flag Item", systemImage: "exclamationmark.bubble") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(AppTypography.iconMedium)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showTransferRequest) {
                TransferRequestSheet(isPresented: $showTransferRequest)
            }
        }
    }
}

// MARK: - Stock Levels

struct InvStockSubview: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryByLocation.productName) private var allInventory: [InventoryByLocation]

    @State private var searchText = ""
    @State private var isSyncing = false

    // Filter to the current store only
    private var storeInventory: [InventoryByLocation] {
        guard let storeId = appState.currentStoreId else { return [] }
        return allInventory.filter { $0.locationId == storeId }
    }

    private var filtered: [InventoryByLocation] {
        guard !searchText.isEmpty else { return storeInventory }
        return storeInventory.filter {
            $0.productName.localizedCaseInsensitiveContains(searchText) ||
            $0.categoryName.localizedCaseInsensitiveContains(searchText) ||
            $0.sku.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalUnits: Int { storeInventory.reduce(0) { $0 + $1.quantity } }
    private var lowCount: Int  { storeInventory.filter { $0.quantity > 0 && $0.quantity <= $0.reorderPoint }.count }
    private var outCount: Int  { storeInventory.filter { $0.quantity == 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack(spacing: AppSpacing.sm) {
                invStat(value: isSyncing ? "…" : "\(totalUnits)", label: "Units",  color: AppColors.accent)
                invStat(value: "\(storeInventory.count)",          label: "SKUs",   color: AppColors.secondary)
                invStat(value: "\(lowCount)",                      label: "Low",    color: AppColors.warning)
                invStat(value: "\(outCount)",                      label: "Out",    color: AppColors.error)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.sm)

            // Search bar
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.neutral500)
                TextField("Search inventory...", text: $searchText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.neutral500)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xs)

            // Content
            if isSyncing && storeInventory.isEmpty {
                Spacer()
                ProgressView("Syncing inventory…").tint(AppColors.accent).padding(.top, 60)
                Spacer()
            } else if storeInventory.isEmpty {
                Spacer()
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(AppColors.neutral500)
                    Text("No inventory records")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("Pull down to refresh or check your store assignment.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xxxl)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(filtered) { item in
                            invRow(item)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .refreshable { await syncInventory() }
            }
        }
        .task { await syncInventory() }
    }

    private func invRow(_ item: InventoryByLocation) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 40, height: 40)
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.neutral500)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(item.categoryName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            stockBadge(item.quantity, reorderPoint: item.reorderPoint)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func stockBadge(_ count: Int, reorderPoint: Int) -> some View {
        let color: Color = count == 0 ? AppColors.error
                         : count <= reorderPoint ? AppColors.warning
                         : AppColors.success
        let label = count == 0 ? "OUT" : "\(count)"
        return Text(label)
            .font(AppTypography.editLink)
            .foregroundColor(color)
            .frame(width: 36)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private func invStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(AppTypography.heading3).foregroundColor(color)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    @MainActor
    private func syncInventory() async {
        guard let storeId = appState.currentStoreId else { return }
        isSyncing = true
        defer { isSyncing = false }
        try? await StoreAndInventorySyncService.shared.syncInventoryToLocal(
            storeId: storeId,
            modelContext: modelContext
        )
    }
}

// MARK: - Alerts

struct InvAlertsSubview: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allInventory: [InventoryByLocation]

    @State private var showTransferRequest = false
    @State private var isSyncing = false

    // Only this store's inventory
    private var storeInventory: [InventoryByLocation] {
        guard let storeId = appState.currentStoreId else { return [] }
        return allInventory.filter { $0.locationId == storeId }
    }

    // Low stock = at or below reorderPoint; sort by quantity asc (worst first)
    private var lowStock: [InventoryByLocation] {
        storeInventory
            .filter { $0.quantity > 0 && $0.quantity <= $0.reorderPoint }
            .sorted { $0.quantity < $1.quantity }
    }

    private var outOfStock: [InventoryByLocation] {
        storeInventory.filter { $0.quantity == 0 }
    }

    private var critical: [InventoryByLocation] { outOfStock + lowStock }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if isSyncing && storeInventory.isEmpty {
                    ProgressView("Syncing…").tint(AppColors.accent).padding(.top, 60)
                } else if critical.isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer().frame(height: 60)
                        Image(systemName: "checkmark.circle")
                            .font(AppTypography.emptyStateIcon)
                            .foregroundColor(AppColors.success)
                        Text("All stock levels healthy")
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("No items are below their reorder threshold.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                } else {
                    // Out-of-stock section
                    if !outOfStock.isEmpty {
                        alertSectionHeader("OUT OF STOCK — \(outOfStock.count) ITEM\(outOfStock.count == 1 ? "" : "S")", color: AppColors.error)
                        ForEach(outOfStock) { item in alertRow(item) }
                    }

                    // Low-stock section
                    if !lowStock.isEmpty {
                        alertSectionHeader("LOW STOCK — \(lowStock.count) ITEM\(lowStock.count == 1 ? "" : "S")", color: AppColors.warning)
                        ForEach(lowStock) { item in alertRow(item) }
                    }
                }
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .refreshable { await syncInventory() }
        .task { await syncInventory() }
        .sheet(isPresented: $showTransferRequest) {
            TransferRequestSheet(isPresented: $showTransferRequest)
        }
    }

    private func alertSectionHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func alertRow(_ item: InventoryByLocation) -> some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.quantity == 0 ? AppColors.error : AppColors.warning)
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.categoryName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    if item.reorderPoint > 0 {
                        Text("· reorder at \(item.reorderPoint)")
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.neutral500)
                    }
                }
            }
            Spacer()
            Text(item.quantity == 0 ? "OUT" : "\(item.quantity) left")
                .font(AppTypography.statSmall)
                .foregroundColor(item.quantity == 0 ? AppColors.error : AppColors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((item.quantity == 0 ? AppColors.error : AppColors.warning).opacity(0.12))
                .cornerRadius(4)

            Button(action: { showTransferRequest = true }) {
                Text("Request")
                    .font(AppTypography.actionLink)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    @MainActor
    private func syncInventory() async {
        guard let storeId = appState.currentStoreId else { return }
        isSyncing = true
        defer { isSyncing = false }
        try? await StoreAndInventorySyncService.shared.syncInventoryToLocal(
            storeId: storeId,
            modelContext: modelContext
        )
    }
}

// MARK: - Transfers / ASN Matching

struct InvTransfersSubview: View {
    @Environment(AppState.self) private var appState

    @Query(sort: \Transfer.updatedAt, order: .reverse) private var allTransfers: [Transfer]
    @Query(sort: \StoreLocation.name) private var allStores: [StoreLocation]

    @State private var transferToMatch: Transfer?
    @State private var resultMessage = ""
    @State private var showResultMessage = false

    private var currentStoreCode: String? {
        guard let storeId = appState.currentStoreId else { return nil }
        return allStores.first(where: { $0.id == storeId })?.code
    }

    private var outboundTransfers: [Transfer] {
        allTransfers
            .filter { [TransferStatus.requested, .approved, .picking, .packed, .inTransit, .partiallyReceived].contains($0.status) }
            .filter { belongsToCurrentStore(code: $0.fromBoutiqueId) }
    }

    private var inboundTransfers: [Transfer] {
        allTransfers
            .filter { [.approved, .picking, .packed, .inTransit, .partiallyReceived, .delivered].contains($0.status) }
            .filter { belongsToCurrentStore(code: $0.toBoutiqueId) }
    }

    private var pendingInboundTransfers: [Transfer] {
        inboundTransfers
            .filter { $0.status != .cancelled }
            .filter { $0.missingQuantity > 0 || $0.extraQuantity > 0 || $0.status != .delivered }
    }

    private var matchedInboundTransfers: [Transfer] {
        inboundTransfers
            .filter { $0.status == .delivered && $0.missingQuantity == 0 && $0.extraQuantity == 0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                sLabel("REQUESTS FROM OTHER STORES")
                if outboundTransfers.isEmpty {
                    emptyState(
                        title: "No incoming requests",
                        subtitle: "No other stores have requested items from you right now."
                    )
                } else {
                    ForEach(outboundTransfers) { transfer in
                        outboundTransferCard(transfer)
                    }
                }

                sLabel("INBOUND SHIPMENTS TO RECEIVE")
                if pendingInboundTransfers.isEmpty {
                    emptyState(
                        title: "No inbound shipments to match",
                        subtitle: "All inbound ASN records are currently reconciled."
                    )
                } else {
                    ForEach(pendingInboundTransfers) { transfer in
                        inboundTransferCard(transfer)
                    }
                }

                if !matchedInboundTransfers.isEmpty {
                    sLabel("RECENTLY MATCHED")
                    ForEach(Array(matchedInboundTransfers.prefix(5))) { transfer in
                        inboundTransferCard(transfer, canMatch: false)
                    }
                }
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .sheet(item: $transferToMatch) { transfer in
            ShipmentMatchSheet(transfer: transfer) { result in
                var lines: [String] = []
                lines.append("ASN \(result.asnNumber) processed.")
                lines.append("Expected: \(result.expectedQuantity)")
                lines.append("Received this check: \(result.receivedThisCheck)")
                lines.append("Cumulative received: \(result.cumulativeReceivedQuantity)")

                if result.missingQuantity > 0 {
                    lines.append("Missing: \(result.missingQuantity)")
                }
                if result.extraQuantity > 0 {
                    lines.append("Extra: \(result.extraQuantity)")
                }
                if !result.warnings.isEmpty {
                    lines.append(contentsOf: result.warnings.map { "Warning: \($0)" })
                }

                resultMessage = lines.joined(separator: "\n")
                showResultMessage = true
            }
        }
        .alert("Shipment Matching", isPresented: $showResultMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }

    private func outboundTransferCard(_ transfer: Transfer) -> some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.productName.isEmpty ? "Unmapped Product" : transfer.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)

                HStack(spacing: 4) {
                    Text(getStoreName(for: transfer.fromBoutiqueId))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Image(systemName: "arrow.right")
                        .font(AppTypography.arrowInline)
                        .foregroundColor(AppColors.neutral500)
                    Text(getStoreName(for: transfer.toBoutiqueId))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
            Spacer()
            Text("×\(transfer.expectedQuantity)")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            statusPill(transfer.status)
        }
        .padding(AppSpacing.sm)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func inboundTransferCard(_ transfer: Transfer, canMatch: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transfer.productName.isEmpty ? "Unmapped Product" : transfer.productName)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("ASN: \(transfer.asnNumber) · Transfer: \(transfer.transferNumber)")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                statusPill(transfer.status)
            }

            HStack(spacing: AppSpacing.md) {
                metricBadge(title: "Expected", value: "\(transfer.expectedQuantity)", color: AppColors.info)
                metricBadge(title: "Received", value: "\(transfer.receivedQuantity)", color: AppColors.success)
                metricBadge(
                    title: "Missing",
                    value: "\(transfer.missingQuantity)",
                    color: transfer.missingQuantity > 0 ? AppColors.warning : AppColors.success
                )
                if transfer.extraQuantity > 0 {
                    metricBadge(title: "Extra", value: "\(transfer.extraQuantity)", color: AppColors.error)
                }
            }

            HStack {
                Text("\(getStoreName(for: transfer.fromBoutiqueId)) → \(getStoreName(for: transfer.toBoutiqueId))")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()

                if canMatch {
                    Button {
                        transferToMatch = transfer
                    } label: {
                        Text("Match Shipment")
                            .font(AppTypography.actionSmall)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.accent.opacity(0.12))
                            .cornerRadius(6)
                    }
                } else {
                    Text("Verified")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.success)
                }
            }
        }
        .padding(AppSpacing.sm)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func statusPill(_ status: TransferStatus) -> some View {
        let color = statusColor(status)
        return Text(status.rawValue.uppercased())
            .font(AppTypography.nano)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private func metricBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.nano)
                .foregroundColor(AppColors.textSecondaryDark)
            Text(value)
                .font(AppTypography.caption)
                .foregroundColor(color)
        }
    }

    private func statusColor(_ status: TransferStatus) -> Color {
        switch status {
        case .requested:
            return AppColors.warning
        case .approved, .picking, .packed, .inTransit:
            return AppColors.info
        case .partiallyReceived:
            return AppColors.warning
        case .delivered:
            return AppColors.success
        case .cancelled:
            return AppColors.error
        }
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "shippingbox")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(AppColors.neutral500)
            Text(title)
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func belongsToCurrentStore(code: String) -> Bool {
        guard let currentStoreId = appState.currentStoreId else { return true }

        if code.caseInsensitiveCompare(currentStoreId.uuidString) == .orderedSame {
            return true
        }

        if let currentStoreCode,
           code.caseInsensitiveCompare(currentStoreCode) == .orderedSame {
            return true
        }

        return false
    }

    private func sLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func getStoreName(for boutiqueId: String) -> String {
        // Try to match by code first (case-insensitive)
        if let store = allStores.first(where: { $0.code.caseInsensitiveCompare(boutiqueId) == .orderedSame }) {
            return store.name
        }
        // Try to match by UUID string
        if let store = allStores.first(where: { $0.id.uuidString.caseInsensitiveCompare(boutiqueId) == .orderedSame }) {
            return store.name
        }
        // If still no match, try partial match for codes (in case of prefix variations)
        if let store = allStores.first(where: { boutiqueId.caseInsensitiveCompare($0.code) == .orderedSame }) {
            return store.name
        }
        // Fallback: show a formatted version of the ID with a note
        return "Store: \(boutiqueId)"
    }
}

private struct ShipmentMatchSheet: View {
    let transfer: Transfer
    let onMatched: (ShipmentMatchResult) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var receivedNowText = ""
    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var receivedNow: Int? {
        Int(receivedNowText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var projectedTotal: Int {
        transfer.receivedQuantity + max(receivedNow ?? 0, 0)
    }

    private var projectedMissing: Int {
        max(transfer.expectedQuantity - projectedTotal, 0)
    }

    private var projectedExtra: Int {
        max(projectedTotal - transfer.expectedQuantity, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(transfer.productName.isEmpty ? "Unmapped Product" : transfer.productName)
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("ASN \(transfer.asnNumber) · Transfer \(transfer.transferNumber)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Record received units for this check")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)

                        TextField("Units received now", text: $receivedNowText)
                            .keyboardType(.numberPad)
                            .font(AppTypography.bodyMedium)
                            .padding(AppSpacing.sm)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)

                        HStack(spacing: AppSpacing.md) {
                            shipmentMetric(title: "Expected", value: "\(transfer.expectedQuantity)", color: AppColors.info)
                            shipmentMetric(title: "Already Received", value: "\(transfer.receivedQuantity)", color: AppColors.secondary)
                        }

                        HStack(spacing: AppSpacing.md) {
                            shipmentMetric(title: "Projected Total", value: "\(projectedTotal)", color: AppColors.success)
                            shipmentMetric(
                                title: "Projected Missing",
                                value: "\(projectedMissing)",
                                color: projectedMissing > 0 ? AppColors.warning : AppColors.success
                            )
                            if projectedExtra > 0 {
                                shipmentMetric(title: "Projected Extra", value: "\(projectedExtra)", color: AppColors.error)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("Match Shipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitMatch()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Process")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("Shipment Matching", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func shipmentMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.nano)
                .foregroundColor(AppColors.textSecondaryDark)
            Text(value)
                .font(AppTypography.caption)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submitMatch() {
        guard let receivedNow, receivedNow > 0 else {
            errorMessage = "Enter a positive received quantity before processing."
            showError = true
            return
        }

        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                let result = try await ShipmentMatchingService.shared.processIncomingShipment(
                    transfer: transfer,
                    receivedThisCheck: receivedNow,
                    receiverEmail: appState.currentUserEmail.isEmpty ? "inventory.controller@local" : appState.currentUserEmail,
                    modelContext: modelContext
                )
                onMatched(result)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Flagged Items

struct InvFlaggedSubview: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allInventory: [InventoryByLocation]

    @State private var isSyncing = false
    @State private var showTransferRequest = false

    // Items completely out of stock for this store — these are the "flagged" critical items
    private var flaggedItems: [InventoryByLocation] {
        guard let storeId = appState.currentStoreId else { return [] }
        return allInventory
            .filter { $0.locationId == storeId && $0.quantity == 0 }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // Items below reorder threshold but still in stock — secondary attention
    private var watchItems: [InventoryByLocation] {
        guard let storeId = appState.currentStoreId else { return [] }
        return allInventory
            .filter { $0.locationId == storeId && $0.quantity > 0 && $0.quantity <= $0.reorderPoint }
            .sorted { $0.quantity < $1.quantity }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if isSyncing && flaggedItems.isEmpty && watchItems.isEmpty {
                    ProgressView("Syncing…").tint(AppColors.accent).padding(.top, 60)

                } else if flaggedItems.isEmpty && watchItems.isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer().frame(height: 60)
                        Image(systemName: "flag.slash")
                            .font(AppTypography.emptyStateIcon)
                            .foregroundColor(AppColors.success)
                        Text("Nothing flagged")
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("All items are above their reorder threshold.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                    }

                } else {
                    // Critical — out of stock
                    if !flaggedItems.isEmpty {
                        sectionLabel("CRITICAL — OUT OF STOCK (\(flaggedItems.count))", color: AppColors.error)
                        ForEach(flaggedItems) { item in
                            flagRow(item, severity: .critical)
                        }
                    }

                    // Watch — below reorder point
                    if !watchItems.isEmpty {
                        sectionLabel("WATCH — BELOW REORDER POINT (\(watchItems.count))", color: AppColors.warning)
                        ForEach(watchItems) { item in
                            flagRow(item, severity: .watch)
                        }
                    }
                }
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .refreshable { await syncInventory() }
        .task { await syncInventory() }
        .sheet(isPresented: $showTransferRequest) {
            TransferRequestSheet(isPresented: $showTransferRequest)
        }
    }

    private enum FlagSeverity { case critical, watch }

    private func flagRow(_ item: InventoryByLocation, severity: FlagSeverity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.productName)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    Text(item.categoryName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                let sc: Color = severity == .critical ? AppColors.error : AppColors.warning
                let label = severity == .critical ? "OUT OF STOCK" : "\(item.quantity) / \(item.reorderPoint) units"
                Text(label)
                    .font(AppTypography.nano)
                    .foregroundColor(sc)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(sc.opacity(0.12))
                    .cornerRadius(4)
            }

            HStack {
                Label("SKU: \(item.sku)", systemImage: "barcode")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text("Updated \(item.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.neutral500)
                Button(action: { showTransferRequest = true }) {
                    Text("Request")
                        .font(AppTypography.reviewButton)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(AppColors.accent.opacity(0.12))
                        .cornerRadius(6)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sectionLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    @MainActor
    private func syncInventory() async {
        guard let storeId = appState.currentStoreId else { return }
        isSyncing = true
        defer { isSyncing = false }
        try? await StoreAndInventorySyncService.shared.syncInventoryToLocal(
            storeId: storeId,
            modelContext: modelContext
        )
    }
}

// MARK: - Transfer Request

private struct TransferRequestSheet: View {
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Product.stockCount, order: .reverse) private var allProducts: [Product]

    @State private var allStores: [StoreLocation] = []
    @State private var selectedProduct: Product?
    @State private var selectedDestinationStore: StoreLocation?
    @State private var quantityText = ""
    @State private var batchReference = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var isLoadingStores = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var currentStore: StoreLocation? {
        guard let storeId = appState.currentStoreId else { return nil }
        return allStores.first(where: { $0.id == storeId })
    }

    private var availableDestinations: [StoreLocation] {
        allStores.filter { $0.id != appState.currentStoreId }
    }

    private var quantity: Int? {
        Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isValid: Bool {
        selectedProduct != nil &&
        selectedDestinationStore != nil &&
        (quantity ?? 0) > 0 &&
        (selectedProduct?.stockCount ?? 0) >= (quantity ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {
                    // Loading indicator
                    if isLoadingStores {
                        ProgressView("Loading stores...")
                            .padding(AppSpacing.md)
                    }

                    // From Store
                    if let currentStore {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("FROM STORE")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(AppColors.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currentStore.name)
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Text(currentStore.code)
                                        .font(AppTypography.micro)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                Spacer()
                            }
                            .padding(AppSpacing.sm)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }
                        .padding(AppSpacing.md)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
                    } else if !isLoadingStores {
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AppColors.warning)
                            Text("Current store not found")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        .padding(AppSpacing.md)
                    }

                    // Product Selection
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("SELECT PRODUCT")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        
                        Picker("Select Product", selection: $selectedProduct) {
                            Text("Choose product...").tag(Product?.none)
                            ForEach(allProducts) { product in
                                HStack {
                                    Text(product.name)
                                    Spacer()
                                    Text("×\(product.stockCount)")
                                }
                                .tag(product as Product?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.sm)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                       
                        if let product = selectedProduct {
                            Text("Available: \(product.stockCount) units")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .padding(.horizontal, AppSpacing.xs)
                        }
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // Quantity
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("QUANTITY")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        TextField("Units to transfer", text: $quantityText)
                            .keyboardType(.numberPad)
                            .font(AppTypography.bodyMedium)
                            .padding(AppSpacing.sm)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        if let product = selectedProduct, let qty = quantity, qty > product.stockCount {
                            Text("Cannot transfer more than available (\(product.stockCount) units)")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.error)
                        }
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // Batch Reference (optional)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("BATCH REFERENCE (OPTIONAL)")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        TextField("Batch / ASN / barcode reference", text: $batchReference)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(AppTypography.bodyMedium)
                            .padding(AppSpacing.sm)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        Text("Item scanning is done at the receiving boutique during shipment confirmation.")
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // Destination Store
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("TO STORE")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        
                        if availableDestinations.isEmpty {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(AppColors.warning)
                                Text("No other stores available")
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            .padding(AppSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        } else {
                            Picker("Select Destination", selection: $selectedDestinationStore) {
                                Text("Choose destination...").tag(StoreLocation?.none)
                                ForEach(availableDestinations) { store in
                                    HStack {
                                        Text(store.name)
                                        Spacer()
                                        Text(store.code)
                                    }
                                    .tag(store as StoreLocation?)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // Notes
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("NOTES (OPTIONAL)")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        TextEditor(text: $notes)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .frame(height: 80)
                            .padding(AppSpacing.xs)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("Request Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitTransferRequest()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Request")
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
            .alert("Transfer Request", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadStoresFromSupabase()
            }
        }
    }

    private func loadStoresFromSupabase() async {
        isLoadingStores = true
        defer { isLoadingStores = false }

        do {
            let stores = try await StoreAndInventorySyncService.shared.fetchStores()
            allStores = stores.sorted { $0.name < $1.name }
        } catch {
            print("Failed to fetch stores from Supabase: \(error)")
            // Fall back to empty list — user will see "no stores available"
            allStores = []
        }
    }

    private func submitTransferRequest() {
        guard let product = selectedProduct,
              let destination = selectedDestinationStore,
              let qty = quantity, qty > 0 else {
            errorMessage = "Please fill in all required fields with valid values."
            showError = true
            return
        }

        guard product.stockCount >= qty else {
            errorMessage = "Not enough inventory. Available: \(product.stockCount) units."
            showError = true
            return
        }

        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }

            let sourceCode = currentStore?.code ?? "UNKNOWN"
            let transferNumber = makeTransferNumber(fromStoreCode: sourceCode)
            let refValue = batchReference.trimmingCharacters(in: .whitespacesAndNewlines)

            var transferNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !refValue.isEmpty {
                let refAudit = "Batch Ref: \(refValue)"
                transferNotes = transferNotes.isEmpty ? refAudit : "\(transferNotes)\n\(refAudit)"
            }

            let transfer = Transfer(
                transferNumber: transferNumber,
                asnNumber: "ASN-\(transferNumber)",
                asnIssuedAt: Date(),
                productId: product.id,
                productName: product.name,
                serialNumber: refValue,
                quantity: qty,
                fromBoutiqueId: currentStore?.code ?? appState.currentStoreId?.uuidString ?? "UNKNOWN",
                toBoutiqueId: destination.code,
                status: .requested,
                requestedByEmail: appState.currentUserEmail.isEmpty ? "manager@local" : appState.currentUserEmail,
                notes: transferNotes
            )

            modelContext.insert(transfer)

            do {
                try modelContext.save()

                var syncWarning = ""
                do {
                    try await TransferSyncService.shared.syncReceipt(for: transfer)
                } catch {
                    syncWarning = "\nWarning: Saved locally, but remote sync failed (\(error.localizedDescription))."
                }

                errorMessage = "Transfer request created successfully.\nTransfer ID: \(transferNumber)\(syncWarning)"
                showError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                errorMessage = "Failed to create transfer: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func makeTransferNumber(fromStoreCode: String) -> String {
        let storeToken = fromStoreCode
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
            .prefix(4)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let ts = formatter.string(from: Date())
        let random = Int.random(in: 100...999)
        return "TRF-\(storeToken)-\(ts)-\(random)"
    }
}

// MARK: - Discrepancy Requests

struct InvDiscrepanciesSubview: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var discrepancies: [InventoryDiscrepancyDTO] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var selectedDiscrepancy: InventoryDiscrepancyDTO?
    @State private var toastMessage: String = ""
    @State private var showToast = false

    private var pending: [InventoryDiscrepancyDTO] {
        discrepancies.filter { $0.status == DiscrepancyStatus.pending.rawValue }
    }

    private var resolved: [InventoryDiscrepancyDTO] {
        discrepancies.filter { $0.status != DiscrepancyStatus.pending.rawValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {

                // ── Pending ────────────────────────────────────────────
                sLabel("PENDING REVIEW (\(pending.count))")

                if isLoading {
                    ProgressView()
                        .padding(.top, AppSpacing.xl)
                } else if pending.isEmpty {
                    discrepancyEmptyState(
                        icon: "checkmark.seal",
                        title: "No pending requests",
                        subtitle: "All discrepancy reports have been reviewed.",
                        color: AppColors.success
                    )
                } else {
                    ForEach(pending) { item in
                        discrepancyRow(item)
                            .onTapGesture { selectedDiscrepancy = item }
                    }
                }

                // ── Resolved ───────────────────────────────────────────
                if !resolved.isEmpty {
                    sLabel("RESOLVED")
                    ForEach(resolved.prefix(10)) { item in
                        discrepancyRow(item, interactive: false)
                    }
                }
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .refreshable { await loadDiscrepancies() }
        .task { await loadDiscrepancies() }
        .sheet(item: $selectedDiscrepancy) { disc in
            DiscrepancyDetailSheet(
                discrepancy: disc,
                onResolved: { message in
                    toastMessage = message
                    showToast = true
                    Task { await loadDiscrepancies() }
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .overlay(alignment: .top) {
            if showToast {
                toastBanner(toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showToast = false }
                        }
                    }
            }
        }
    }

    // MARK: - Row

    private func discrepancyRow(_ item: InventoryDiscrepancyDTO, interactive: Bool = true) -> some View {
        let statusColor = statusColor(for: item.discrepancyStatus)
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.discrepancyStatus == .pending ? AppColors.warning : statusColor)
                    .frame(width: 3, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.productName.isEmpty ? "Unknown Product" : item.productName)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    Text(item.reason.isEmpty ? "No reason provided" : item.reason)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    statusPill(item.discrepancyStatus)
                    Text("\(item.quantityDelta) units \(item.deltaDirection.lowercased())")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            HStack(spacing: AppSpacing.md) {
                discrepancyMetric(label: "Reported", value: "\(item.reportedQuantity)", color: AppColors.info)
                discrepancyMetric(label: "System",   value: "\(item.systemQuantity)",   color: AppColors.secondary)
                discrepancyMetric(label: "Delta",    value: "\(item.quantityDelta)",    color: item.quantityDelta > 0 ? AppColors.warning : AppColors.success)
            }

            HStack {
                Label(item.reportedByName.isEmpty ? "Staff" : item.reportedByName, systemImage: "person")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.neutral500)
                if interactive {
                    Image(systemName: "chevron.right")
                        .font(AppTypography.nano)
                        .foregroundColor(AppColors.neutral500)
                }
            }
        }
        .padding(AppSpacing.sm)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func loadDiscrepancies() async {
        guard let storeId = appState.currentStoreId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            discrepancies = try await DiscrepancyService.shared.fetchDiscrepancies(storeId: storeId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func statusPill(_ status: DiscrepancyStatus) -> some View {
        let color = statusColor(for: status)
        return Text(status.displayName.uppercased())
            .font(AppTypography.nano)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private func statusColor(for status: DiscrepancyStatus) -> Color {
        switch status {
        case .pending:  return AppColors.warning
        case .approved: return AppColors.success
        case .rejected: return AppColors.error
        }
    }

    private func discrepancyMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTypography.nano)
                .foregroundColor(AppColors.textSecondaryDark)
            Text(value)
                .font(AppTypography.caption)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func discrepancyEmptyState(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(color)
            Text(title)
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func toastBanner(_ message: String) -> some View {
        Text(message)
            .font(AppTypography.bodySmall)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.success)
            .clipShape(Capsule())
            .padding(.top, AppSpacing.md)
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Discrepancy Detail Sheet

private struct DiscrepancyDetailSheet: View {
    let discrepancy: InventoryDiscrepancyDTO
    let onResolved: (String) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var managerNotes = ""
    @State private var isSubmitting  = false
    @State private var errorMessage  = ""
    @State private var showError     = false
    @State private var showRejectConfirm = false

    private var reviewerUUID: UUID? {
        appState.currentUserProfile?.id
    }

    private var reviewerName: String {
        appState.currentUserName.isEmpty ? "Manager" : appState.currentUserName
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {

                    // ── Product Info ────────────────────────────────
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(discrepancy.productName.isEmpty ? "Unknown Product" : discrepancy.productName)
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        discrepancyStatus
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // ── Quantity Comparison ─────────────────────────
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("QUANTITY COMPARISON")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)

                        HStack(spacing: AppSpacing.md) {
                            quantityCard(
                                label: "Reported",
                                value: discrepancy.reportedQuantity,
                                color: AppColors.info,
                                icon: "person.crop.rectangle"
                            )
                            quantityCard(
                                label: "System Record",
                                value: discrepancy.systemQuantity,
                                color: AppColors.secondary,
                                icon: "server.rack"
                            )
                        }

                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: discrepancy.reportedQuantity < discrepancy.systemQuantity ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundColor(AppColors.warning)
                            Text("\(discrepancy.quantityDelta) unit\(discrepancy.quantityDelta == 1 ? "" : "s") \(discrepancy.deltaDirection.lowercased()) from system record")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.warning.opacity(0.08))
                        .cornerRadius(AppSpacing.radiusSmall)
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // ── Reason ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("REASON PROVIDED")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        Text(discrepancy.reason.isEmpty ? "No reason provided." : discrepancy.reason)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // ── Reporter ────────────────────────────────────
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("SUBMITTED BY")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        Label(
                            discrepancy.reportedByName.isEmpty ? "Unknown Staff" : discrepancy.reportedByName,
                            systemImage: "person.fill"
                        )
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                        Text(discrepancy.createdAt.formatted(date: .long, time: .shortened))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(AppSpacing.md)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                    // ── Manager Notes (for rejection) ───────────────
                    if discrepancy.discrepancyStatus == .pending {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack {
                                Text("MANAGER NOTES")
                                    .font(AppTypography.overline)
                                    .tracking(2)
                                    .foregroundColor(AppColors.accent)
                                Text("(required to reject)")
                                    .font(AppTypography.micro)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            TextEditor(text: $managerNotes)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(height: 90)
                                .padding(AppSpacing.xs)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }
                        .padding(AppSpacing.md)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)

                        // ── Action Buttons ───────────────────────────
                        HStack(spacing: AppSpacing.md) {
                            // Reject
                            Button {
                                showRejectConfirm = true
                            } label: {
                                Label("Reject", systemImage: "xmark.circle")
                                    .font(AppTypography.label)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(AppColors.error)
                                    .cornerRadius(AppSpacing.radiusMedium)
                            }
                            .disabled(isSubmitting)

                            // Approve
                            Button {
                                Task { await performApprove() }
                            } label: {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, AppSpacing.sm)
                                } else {
                                    Label("Approve", systemImage: "checkmark.circle")
                                        .font(AppTypography.label)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, AppSpacing.sm)
                                }
                            }
                            .background(AppColors.success)
                            .cornerRadius(AppSpacing.radiusMedium)
                            .disabled(isSubmitting)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    } else if let notes = discrepancy.managerNotes, !notes.isEmpty {
                        // Show stored manager notes for resolved discrepancies
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("MANAGER NOTES")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                            Text(notes)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(AppSpacing.md)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("Discrepancy Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Reject Discrepancy", isPresented: $showRejectConfirm) {
                Button("Reject", role: .destructive) {
                    Task { await performReject() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Inventory will remain unchanged. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Status Banner

    private var discrepancyStatus: some View {
        let status = discrepancy.discrepancyStatus
        let color: Color = {
            switch status {
            case .pending:  return AppColors.warning
            case .approved: return AppColors.success
            case .rejected: return AppColors.error
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(status.displayName.uppercased())
                .font(AppTypography.nano)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Quantity Card

    private func quantityCard(label: String, value: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Text("\(value)")
                .font(AppTypography.heading2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(color.opacity(0.07))
        .cornerRadius(AppSpacing.radiusSmall)
    }

    // MARK: - Actions

    private func performApprove() async {
        guard let reviewerId = reviewerUUID else {
            errorMessage = "Your user profile could not be resolved. Please log out and back in."
            showError = true
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await DiscrepancyService.shared.approve(
                discrepancy:  discrepancy,
                reviewedBy:   reviewerId,
                reviewerName: reviewerName,
                modelContext: modelContext
            )
            onResolved("✓ Approved — inventory updated to \(discrepancy.reportedQuantity) units")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performReject() async {
        guard let reviewerId = reviewerUUID else {
            errorMessage = "Your user profile could not be resolved. Please log out and back in."
            showError = true
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await DiscrepancyService.shared.reject(
                discrepancy:  discrepancy,
                reviewedBy:   reviewerId,
                reviewerName: reviewerName,
                notes:        managerNotes
            )
            onResolved("✗ Rejected — inventory unchanged")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    ManagerInventoryView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, Transfer.self, StoreLocation.self, InventoryByLocation.self, InventoryDiscrepancy.self], inMemory: true)
}
