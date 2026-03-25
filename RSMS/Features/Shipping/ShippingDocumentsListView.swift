//
//  ShippingDocumentsListView.swift
//  RSMS
//
//  Lists all ship-from-store orders for the current store with
//  download/print packing slip actions.
//

import SwiftUI
import SwiftData

struct ShippingDocumentsListView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Order.createdAt, order: .reverse) private var allOrders: [Order]
    @Query private var stores: [StoreLocation]

    @State private var selectedDocument: ShippingDocument?
    @State private var shareFile: ShareFile?
    @State private var searchText = ""
    @State private var selectedFilter: ShipFilter = .all

    enum ShipFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case shipped = "Shipped"
        case delivered = "Delivered"
    }

    // Filter to ship-from-store and standard delivery orders
    private var shippableOrders: [Order] {
        allOrders.filter { order in
            order.fulfillmentType == .shipFromStore || order.fulfillmentType == .standard
        }
    }

    private var filteredOrders: [Order] {
        var orders = shippableOrders

        // Status filter
        switch selectedFilter {
        case .all: break
        case .pending:
            orders = orders.filter { [.pending, .confirmed, .processing].contains($0.status) }
        case .shipped:
            orders = orders.filter { $0.status == .shipped }
        case .delivered:
            orders = orders.filter { [.delivered, .completed].contains($0.status) }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            orders = orders.filter {
                $0.orderNumber.lowercased().contains(query) ||
                $0.customerEmail.lowercased().contains(query)
            }
        }

        return orders
    }

    private var currentStore: StoreLocation? {
        guard let sid = appState.currentStoreId else { return stores.first }
        return stores.first(where: { $0.id == sid }) ?? stores.first
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ShipFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.sm)

                if filteredOrders.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(filteredOrders) { order in
                                orderShipRow(order)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
        }
        .navigationTitle("Shipping Documents")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search orders…")
        .sheet(item: $selectedDocument) { doc in
            ShippingDocumentView(document: doc, onDownload: { downloadPDF(for: doc) })
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(activityItems: [file.url])
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.backgroundSecondary)
                    .frame(width: 100, height: 100)
                Image(systemName: "shippingbox")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundColor(AppColors.neutral600)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("No Shipping Orders")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Ship-from-store orders will appear here")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Order Row

    private func orderShipRow(_ order: Order) -> some View {
        Button {
            let store = currentStore
            let doc = ShippingDocumentService.buildDocument(
                from: order,
                storeName: store?.name ?? "Maison Luxe",
                storeAddress: store.map { "\($0.addressLine1), \($0.city), \($0.stateProvince) \($0.postalCode)" } ?? ""
            )
            selectedDocument = doc
        } label: {
            LuxuryCardView {
                VStack(spacing: AppSpacing.sm) {
                    // Top row: order number + status
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.orderNumber)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text(order.customerEmail)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .lineLimit(1)
                        }
                        Spacer()
                        statusBadge(order.status)
                    }

                    GoldDivider()

                    // Middle row: date + items count + fulfillment
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedDate(order.createdAt))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.neutral600)
                            HStack(spacing: 4) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.neutral600)
                                Text(order.fulfillmentType.rawValue)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.neutral600)
                            }
                        }
                        Spacer()

                        // Quick download button
                        Button {
                            let store = currentStore
                            let doc = ShippingDocumentService.buildDocument(
                                from: order,
                                storeName: store?.name ?? "Maison Luxe",
                                storeAddress: store.map { "\($0.addressLine1), \($0.city), \($0.stateProvince) \($0.postalCode)" } ?? ""
                            )
                            downloadPDF(for: doc)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 12, weight: .medium))
                                Text("PDF")
                                    .font(AppTypography.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.accent.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "chevron.right")
                            .font(AppTypography.chevron)
                            .foregroundColor(AppColors.neutral400)
                    }
                }
                .padding(AppSpacing.cardPadding)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func statusBadge(_ status: OrderStatus) -> some View {
        Text(status.rawValue)
            .font(AppTypography.caption)
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
            .cornerRadius(AppSpacing.radiusSmall)
    }

    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .pending: return AppColors.neutral600
        case .confirmed, .processing: return AppColors.accent
        case .shipped, .readyForPickup: return AppColors.secondary
        case .delivered, .completed: return AppColors.success
        case .cancelled: return AppColors.error
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func downloadPDF(for doc: ShippingDocument) {
        do {
            let pdfURL = try ShippingDocumentService.generatePDF(for: doc)
            shareFile = ShareFile(url: pdfURL)
        } catch {
            print("[ShippingDocumentsListView] PDF generation failed: \(error.localizedDescription)")
        }
    }
}
