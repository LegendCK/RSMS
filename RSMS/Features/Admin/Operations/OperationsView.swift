//
//  OperationsView.swift
//  infosys2
//
//  Enterprise operations hub — global inventory, distribution centers, stock transfers.
//

import SwiftUI
import SwiftData
import Supabase

private struct ReplenishmentRequest: Identifiable, Decodable {
    let id: UUID
    let transferNumber: String
    let productId: String?
    let quantity: Int
    let fromBoutiqueId: String?
    let toBoutiqueId: String?
    let status: String
    let requestedAt: String?
    let updatedAt: String?

    // Joined relations
    let products: ProductRef?
    let fromStore: StoreRef?
    let toStore: StoreRef?

    struct ProductRef: Decodable { let name: String }
    struct StoreRef: Decodable { let name: String }

    var productName: String? { products?.name }
    var fromStoreName: String? { fromStore?.name }
    var toStoreName: String? { toStore?.name }

    enum CodingKeys: String, CodingKey {
        case id
        case transferNumber = "transfer_number"
        case productId      = "product_id"
        case quantity
        case fromBoutiqueId = "from_boutique_id"
        case toBoutiqueId   = "to_boutique_id"
        case status
        case requestedAt    = "requested_at"
        case updatedAt      = "updated_at"
        case products
        case fromStore      = "from_store"
        case toStore        = "to_store"
    }
}

struct OperationsView: View {
    @Query(sort: \Product.stockCount, order: .forward) private var allProducts: [Product]
    @State private var selectedSection = 0

    // Live replenishment requests from Supabase
    @State private var replenishmentRequests: [ReplenishmentRequest] = []
    @State private var isLoadingRequests = false
    @State private var approvingId: UUID? = nil
    @State private var selectedRequest: ReplenishmentRequest? = nil

    private var lowStockProducts: [Product] { allProducts.filter { $0.stockCount <= 3 && $0.stockCount > 0 } }
    private var outOfStockProducts: [Product] { allProducts.filter { $0.stockCount == 0 } }
    private var healthyProducts: [Product] { allProducts.filter { $0.stockCount > 3 } }
    private var totalUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Segment
                Picker("", selection: $selectedSection) {
                    Text("Inventory").tag(0)
                    Text("Distribution").tag(1)
                    Text("Transfers").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(AppSpacing.sm)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 0.8)
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)

                switch selectedSection {
                case 0: inventorySection
                case 1: distributionSection
                case 2: transfersSection
                default: inventorySection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Operations")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {}) { Label("New Transfer", systemImage: "arrow.left.arrow.right") }
                    Button(action: {}) { Label("Reorder Stock", systemImage: "cart.badge.plus") }
                    Button(action: {}) { Label("Export Inventory", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Global Inventory

    private var inventorySection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                // Summary strip
                HStack(spacing: AppSpacing.sm) {
                    inventoryStat(value: "\(totalUnits)", label: "Total Units", color: AppColors.accent)
                    inventoryStat(value: "\(allProducts.count)", label: "SKUs", color: AppColors.secondary)
                    inventoryStat(value: "\(lowStockProducts.count)", label: "Low", color: AppColors.warning)
                    inventoryStat(value: "\(outOfStockProducts.count)", label: "Out", color: AppColors.error)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                // Critical items
                if !outOfStockProducts.isEmpty || !lowStockProducts.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sectionLabel("REQUIRES ATTENTION")

                        ForEach(outOfStockProducts + lowStockProducts) { product in
                            stockAlertRow(product)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // All inventory
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionLabel("ALL INVENTORY")

                    ForEach(allProducts) { product in
                        inventoryRow(product)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func inventoryStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.heading2)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func stockAlertRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                .frame(width: 3, height: 36)

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

            Text(product.stockCount == 0 ? "OUT" : "\(product.stockCount) left")
                .font(AppTypography.statSmall)
                .foregroundColor(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((product.stockCount == 0 ? AppColors.error : AppColors.warning).opacity(0.12))
                .cornerRadius(4)

            Button(action: {}) {
                Text("Reorder")
                    .font(AppTypography.actionLink)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func inventoryRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: "bag.fill",
                cornerRadius: 6
            )
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.brand + " • " + product.categoryName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()

            stockBadge(product.stockCount)
        }
        .padding(.vertical, AppSpacing.xxs)
        .contentShape(Rectangle())
    }

    private func stockBadge(_ count: Int) -> some View {
        let color = count > 5 ? AppColors.success : count > 0 ? AppColors.warning : AppColors.error
        return Text("\(count)")
            .font(AppTypography.editLink)
            .foregroundColor(color)
            .frame(width: 32)
    }

    // MARK: - Distribution Centers

    private var distributionSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    inventoryStat(value: "2", label: "Centers", color: AppColors.info)
                    inventoryStat(value: "43K", label: "Capacity", color: AppColors.accent)
                    inventoryStat(value: "68%", label: "Utilized", color: AppColors.success)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                dcCard(name: "East Coast Hub", location: "Newark, NJ", capacity: "25,000", used: "18,200", percent: 0.73, status: "Operational")
                dcCard(name: "European Hub", location: "Milan, Italy", capacity: "18,000", used: "11,500", percent: 0.64, status: "Operational")
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func dcCard(name: String, location: String, capacity: String, used: String, percent: Double, status: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(location)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(status.uppercased())
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.success.opacity(0.12))
                    .cornerRadius(4)
            }

            // Utilization bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.backgroundTertiary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(percent > 0.8 ? AppColors.warning : AppColors.accent)
                            .frame(width: geo.size.width * percent)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(used) / \(capacity) units")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                    Text("\(Int(percent * 100))%")
                        .font(AppTypography.statSmall)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Replenishment Requests (live from Supabase)

    private var transfersSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if isLoadingRequests {
                    ProgressView("Loading requests…")
                        .tint(AppColors.accent)
                        .padding(.top, AppSpacing.xxl)
                } else {
                    let pending  = replenishmentRequests.filter { $0.status == "pending_admin_approval" }
                    let approved = replenishmentRequests.filter { $0.status == "approved" }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sectionLabel("PENDING APPROVAL (\(pending.count))")
                        if pending.isEmpty {
                            Text("No pending replenishment requests")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.md)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                        } else {
                            ForEach(pending) { req in
                                replenishmentRow(req)
                                    .onTapGesture { selectedRequest = req }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)

                    if !approved.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sectionLabel("APPROVED")
                            ForEach(approved) { req in
                                replenishmentRow(req)
                                    .onTapGesture { selectedRequest = req }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                }
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
        .task { await loadReplenishmentRequests() }
        .refreshable { await loadReplenishmentRequests() }
        .sheet(item: $selectedRequest) { req in
            ReplenishmentDetailSheet(
                request: req,
                isApproving: approvingId == req.id,
                onApprove: req.status == "pending_admin_approval" ? {
                    Task {
                        await approveReplenishment(req)
                        selectedRequest = replenishmentRequests.first(where: { $0.id == req.id })
                    }
                } : nil
            )
        }
    }

    private func replenishmentRow(_ req: ReplenishmentRequest) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(req.transferNumber)
                        .font(AppTypography.monoID)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    Text(req.productName ?? "Unknown Product")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    Text("Qty \(req.quantity) • To \(req.toStoreName ?? storeLabel(req.toBoutiqueId))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()

                if req.status == "pending_admin_approval" {
                    Button {
                        Task { await approveReplenishment(req) }
                    } label: {
                        if approvingId == req.id {
                            ProgressView().tint(.white).scaleEffect(0.75)
                        } else {
                            Text("Approve")
                                .font(AppTypography.nano)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                    .disabled(approvingId != nil)
                } else {
                    Text("APPROVED")
                        .font(AppTypography.nano)
                        .foregroundColor(AppColors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.success.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let requestedAt = req.requestedAt, !requestedAt.isEmpty {
                Text("Requested \(formatTransferTimestamp(requestedAt))")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.neutral500)
            }
        }
        .padding(AppSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                .stroke(AppColors.border.opacity(0.15), lineWidth: 0.6)
        )
    }

    private func storeLabel(_ storeId: String?) -> String {
        guard let storeId, !storeId.isEmpty else { return "Unknown" }
        return "\(storeId.prefix(8))…"
    }

    @MainActor
    private func loadReplenishmentRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }
        do {
            let client = SupabaseManager.shared.client
            replenishmentRequests = try await client
                .from("transfers")
                .select("id,transfer_number,product_id,quantity,from_boutique_id,to_boutique_id,status,requested_at,updated_at,products(name),from_store:stores!transfers_from_boutique_id_fkey(name),to_store:stores!transfers_to_boutique_id_fkey(name)")
                .in("status", values: ["pending_admin_approval", "approved"])
                .order("requested_at", ascending: false)
                .limit(50)
                .execute()
                .value
        } catch {
            print("[OperationsView] Failed to load replenishment requests: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func approveReplenishment(_ req: ReplenishmentRequest) async {
        approvingId = req.id
        defer { approvingId = nil }
        do {
            struct StatusPatch: Encodable {
                let status: String
                let updated_at: String
            }
            let patch = StatusPatch(status: "approved", updated_at: ISO8601DateFormatter().string(from: Date()))
            try await SupabaseManager.shared.client
                .from("transfers")
                .update(patch)
                .eq("id", value: req.id.uuidString.lowercased())
                .execute()
            await loadReplenishmentRequests()
        } catch {
            print("[OperationsView] Approval failed: \(error.localizedDescription)")
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .padding(.bottom, 2)
    }

}

private func formatTransferTimestamp(_ raw: String) -> String {
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: raw) {
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    let basic = ISO8601DateFormatter()
    basic.formatOptions = [.withInternetDateTime]
    if let date = basic.date(from: raw) {
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    return raw
}

private struct ReplenishmentDetailSheet: View {
    let request: ReplenishmentRequest
    let isApproving: Bool
    let onApprove: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {
                    detailCard(title: "Transfer", rows: [
                        ("Transfer ID", request.transferNumber),
                        ("Status", request.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    ])

                    detailCard(title: "Inventory", rows: [
                        ("Product", request.productName ?? "Unknown"),
                        ("Product ID", request.productId.map { String($0.prefix(8)) + "…" } ?? "—"),
                        ("Quantity", "\(request.quantity)")
                    ])

                    detailCard(title: "Routing", rows: [
                        ("From Store", request.fromStoreName ?? (request.fromBoutiqueId == nil ? "Warehouse" : "—")),
                        ("To Store", request.toStoreName ?? "—")
                    ])

                    detailCard(title: "Audit", rows: [
                        ("Requested At", request.requestedAt.map { formatTransferTimestamp($0) } ?? "—"),
                        ("Updated At", request.updatedAt.map { formatTransferTimestamp($0) } ?? "—")
                    ])
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("Approval Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let onApprove {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            onApprove()
                        } label: {
                            if isApproving {
                                ProgressView()
                            } else {
                                Text("Approve")
                            }
                        }
                        .disabled(isApproving)
                    }
                }
            }
        }
    }

    private func detailCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .frame(width: 100, alignment: .leading)
                    Text(row.1)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if index < rows.count - 1 {
                    Divider().background(AppColors.dividerLight)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

#Preview {
    OperationsView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
