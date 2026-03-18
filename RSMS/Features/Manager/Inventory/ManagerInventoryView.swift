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
    @Query(sort: \Product.stockCount, order: .forward) private var allProducts: [Product]
    @State private var searchText = ""

    private var filtered: [Product] {
        searchText.isEmpty ? allProducts : allProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var totalUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }
    private var lowCount: Int { allProducts.filter { $0.stockCount > 0 && $0.stockCount <= 3 }.count }
    private var outCount: Int { allProducts.filter { $0.stockCount == 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                invStat(value: "\(totalUnits)", label: "Units", color: AppColors.accent)
                invStat(value: "\(allProducts.count)", label: "SKUs", color: AppColors.secondary)
                invStat(value: "\(lowCount)", label: "Low", color: AppColors.warning)
                invStat(value: "\(outCount)", label: "Out", color: AppColors.error)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.sm)

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.neutral500)
                TextField("Search inventory...", text: $searchText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xs)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(filtered) { product in
                        invRow(product)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func invRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: "bag.fill",
                cornerRadius: 6
            )
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.categoryName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            stockBadge(product.stockCount)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func stockBadge(_ count: Int) -> some View {
        let color = count > 5 ? AppColors.success : count > 0 ? AppColors.warning : AppColors.error
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
            Text(value)
                .font(AppTypography.heading3)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }
}

// MARK: - Alerts

struct InvAlertsSubview: View {
    @Query(sort: \Product.stockCount) private var allProducts: [Product]

    private var critical: [Product] { allProducts.filter { $0.stockCount <= 3 } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if critical.isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer().frame(height: 60)
                        Image(systemName: "checkmark.circle")
                            .font(AppTypography.emptyStateIcon)
                            .foregroundColor(AppColors.success)
                        Text("All stock levels healthy")
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                } else {
                    Text("ITEMS REQUIRING ACTION")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    ForEach(critical) { product in
                        HStack(spacing: AppSpacing.sm) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                                .frame(width: 3, height: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text(product.categoryName)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            Spacer()
                            Text(product.stockCount == 0 ? "OUT" : "\(product.stockCount) left")
                                .font(AppTypography.statSmall)
                                .foregroundColor(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((product.stockCount == 0 ? AppColors.error : AppColors.warning).opacity(0.12))
                                .cornerRadius(4)

                            Button(action: {}) {
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
                }
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
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
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                Text("FLAGGED FOR REVIEW")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                flagRow(item: "Classic Flap Bag #ML-0042", reason: "Minor scratch on hardware", flaggedBy: "Alexander Chase", time: "Today", severity: "Low")
                flagRow(item: "Diamond Bezel Watch #ML-0118", reason: "Display case damaged", flaggedBy: "Daniel Park", time: "Yesterday", severity: "Medium")
                flagRow(item: "Gold Bracelet #ML-0205", reason: "Clasp mechanism stiff", flaggedBy: "Marcus Webb", time: "2d ago", severity: "Low")
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func flagRow(item: String, reason: String, flaggedBy: String, time: String, severity: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(item)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Spacer()
                let sc = severity == "Low" ? AppColors.warning : AppColors.error
                Text(severity.uppercased())
                    .font(AppTypography.nano)
                    .foregroundColor(sc)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(sc.opacity(0.12))
                    .cornerRadius(4)
            }
            Text(reason)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
            HStack {
                Text(flaggedBy)
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.secondary)
                Text("•")
                    .foregroundColor(AppColors.neutral600)
                Text(time)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.neutral500)
                Spacer()
                Button(action: {}) {
                    Text("Review")
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
        quantity ?? 0 > 0 &&
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

            let transferNumber = "TRF-\(UUID().uuidString.prefix(8).uppercased())"

            let transfer = Transfer(
                transferNumber: transferNumber,
                asnNumber: "ASN-\(transferNumber)",
                asnIssuedAt: Date(),
                productId: product.id,
                productName: product.name,
                quantity: qty,
                fromBoutiqueId: currentStore?.code ?? appState.currentStoreId?.uuidString ?? "UNKNOWN",
                toBoutiqueId: destination.code,
                status: .requested,
                requestedByEmail: appState.currentUserEmail.isEmpty ? "manager@local" : appState.currentUserEmail,
                notes: notes
            )

            modelContext.insert(transfer)

            do {
                try modelContext.save()
                errorMessage = "Transfer request created successfully!"
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
}

#Preview {
    ManagerInventoryView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, Transfer.self, StoreLocation.self, InventoryByLocation.self], inMemory: true)
}
