//
//  OrderFulfillmentView.swift
//  RSMS
//
//  Inventory Controller order fulfillment view — see pending orders, pick/pack items,
//  progress status (confirmed → processing → shipped/ready → delivered/completed),
//  with all changes synced to Supabase in real time.
//

import SwiftUI
import SwiftData

struct OrderFulfillmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var orders: [OrderDTO] = []
    @State private var isLoading = false
    @State private var selectedOrder: OrderDTO? = nil
    @State private var showOrderDetail = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var selectedFilter: FulfillFilter = .pending

    enum FulfillFilter: String, CaseIterable {
        case pending = "New"
        case processing = "Processing"
        case shipped = "Shipped"
        case all = "All"
    }

    private var filteredOrders: [OrderDTO] {
        switch selectedFilter {
        case .pending:
            return orders.filter { ["confirmed", "pending"].contains(OrderStatusMapper.canonical($0.status)) }
        case .processing:
            return orders.filter { OrderStatusMapper.canonical($0.status) == "processing" }
        case .shipped:
            return orders.filter { ["shipped", "ready_for_pickup"].contains(OrderStatusMapper.canonical($0.status)) }
        case .all:
            return orders
        }
    }

    private var pendingCount: Int {
        orders.filter { ["confirmed", "pending"].contains(OrderStatusMapper.canonical($0.status)) }.count
    }
    private var processingCount: Int {
        orders.filter { OrderStatusMapper.canonical($0.status) == "processing" }.count
    }
    private var shippedCount: Int {
        orders.filter { ["shipped", "ready_for_pickup"].contains(OrderStatusMapper.canonical($0.status)) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack(spacing: AppSpacing.sm) {
                statPill(value: "\(pendingCount)", label: "New", color: AppColors.warning)
                statPill(value: "\(processingCount)", label: "Processing", color: AppColors.accent)
                statPill(value: "\(shippedCount)", label: "Shipped", color: AppColors.success)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)

            // Filter
            Picker("", selection: $selectedFilter) {
                ForEach(FulfillFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.sm)

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading orders…")
                    .tint(AppColors.accent)
                Spacer()
            } else if filteredOrders.isEmpty {
                Spacer()
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(AppColors.success)
                    Text("All Caught Up")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("No \(selectedFilter.rawValue.lowercased()) orders to process")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(filteredOrders) { order in
                            OrderFulfillmentCard(
                                order: order,
                                storeId: appState.currentStoreId,
                                onStatusChanged: { await loadOrders() }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .refreshable { await loadOrders() }
            }
        }
        .task { await loadOrders() }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Data

    @MainActor
    private func loadOrders() async {
        guard let storeId = appState.currentStoreId else { return }
        isLoading = orders.isEmpty
        defer { isLoading = false }
        do {
            orders = try await OrderFulfillmentService.shared.fetchFulfillmentOrders(storeId: storeId)
        } catch {
            errorMessage = "Failed to load orders: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Helpers

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
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

// MARK: - Order Fulfillment Card

struct OrderFulfillmentCard: View {
    let order: OrderDTO
    let storeId: UUID?
    let onStatusChanged: () async -> Void

    @State private var isUpdating = false
    @State private var orderItems: [OrderItemWithProduct] = []
    @State private var isExpanded = false
    @State private var isLoadingItems = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var canonicalStatus: String {
        OrderStatusMapper.canonical(order.status)
    }

    private var statusColor: Color {
        switch canonicalStatus {
        case "pending", "confirmed": return AppColors.warning
        case "processing": return AppColors.accent
        case "shipped", "ready_for_pickup": return AppColors.success
        default: return AppColors.neutral600
        }
    }

    private var statusLabel: String {
        switch canonicalStatus {
        case "pending": return "PENDING"
        case "confirmed": return "CONFIRMED"
        case "processing": return "PROCESSING"
        case "shipped": return "SHIPPED"
        case "ready_for_pickup": return "READY FOR PICKUP"
        default: return order.status.uppercased()
        }
    }

    private var nextAction: (label: String, status: String, icon: String)? {
        switch canonicalStatus {
        case "pending", "confirmed":
            return ("Start Processing", "processing", "arrow.triangle.2.circlepath")
        case "processing":
            let isBopis = order.channel == "bopis"
            return isBopis
                ? ("Mark Ready for Pickup", "ready_for_pickup", "building.2.fill")
                : ("Mark as Shipped", "shipped", "shippingbox.fill")
        case "shipped":
            return ("Mark Delivered", "delivered", "checkmark.circle.fill")
        case "ready_for_pickup":
            return ("Complete Order", "completed", "checkmark.seal.fill")
        default:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.orderNumber ?? "—")
                        .font(AppTypography.monoID)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(order.customerName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    if let customerEmail = order.customerEmail, !customerEmail.isEmpty {
                        Text(customerEmail)
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(statusLabel)
                    .font(AppTypography.pico)
                    .tracking(1)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(4)
            }

            // Channel + Total
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: channelIcon)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.neutral500)
                    Text(order.channel.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(order.formattedTotal)
                    .font(AppTypography.priceSmall)
                    .foregroundColor(AppColors.accent)
            }

            HStack(spacing: 4) {
                Image(systemName: "bag")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.neutral500)
                Text("\(max(order.itemCount, 0)) item\(order.itemCount == 1 ? "" : "s") • Qty \(max(order.totalQuantity, 0))")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
            }

            // Expand to show items
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                if isExpanded && orderItems.isEmpty { Task { await loadItems() } }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "Hide Items" : "View Items")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }

            if isExpanded {
                if isLoadingItems {
                    HStack {
                        ProgressView()
                            .tint(AppColors.accent)
                        Text("Loading items…")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(.vertical, AppSpacing.xs)
                } else if orderItems.isEmpty {
                    Text("No items found")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .padding(.vertical, AppSpacing.xs)
                } else {
                    VStack(spacing: AppSpacing.xs) {
                        ForEach(orderItems) { item in
                            HStack(spacing: AppSpacing.sm) {
                                Group {
                                    if let image = item.productPrimaryImage, !image.isEmpty {
                                        ProductArtworkView(
                                            imageSource: image,
                                            fallbackSymbol: "cube.box.fill",
                                            cornerRadius: AppSpacing.radiusSmall
                                        )
                                    } else {
                                        RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                                            .fill(AppColors.backgroundSecondary)
                                            .overlay(
                                                Image(systemName: "cube.box.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(AppColors.accent)
                                            )
                                    }
                                }
                                .frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.productName)
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                        .lineLimit(1)
                                    Text("SKU: \(item.productSku) · Qty: \(item.quantity)")
                                        .font(AppTypography.micro)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                Spacer()
                                Text(formatCurrency(item.line_total))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundTertiary.opacity(0.5))
                    .cornerRadius(AppSpacing.radiusSmall)
                }
            }

            // Action button
            if let action = nextAction {
                Button {
                    Task { await performStatusUpdate(newStatus: action.status) }
                } label: {
                    HStack(spacing: 6) {
                        if isUpdating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: action.icon)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isUpdating ? "Updating…" : action.label)
                            .font(AppTypography.buttonPrimary)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(statusColor)
                    .cornerRadius(AppSpacing.radiusMedium)
                }
                .disabled(isUpdating)
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    @MainActor
    private func performStatusUpdate(newStatus: String) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            // When moving to "processing", decrement Supabase inventory
            if OrderStatusMapper.canonical(newStatus) == "processing" {
                // Load items if not already loaded
                if orderItems.isEmpty {
                    await loadItems()
                }
                // Decrement inventory for each item
                if let sid = storeId {
                    for item in orderItems {
                        if let productId = UUID(uuidString: item.product_id) {
                            try await OrderFulfillmentService.shared.decrementInventory(
                                productId: productId,
                                storeId: sid,
                                quantity: item.quantity
                            )
                        }
                    }
                }
            }

            // Update order status
            try await OrderFulfillmentService.shared.updateOrderStatus(
                orderId: order.id,
                newStatus: newStatus
            )

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await onStatusChanged()
        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
            showError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    private func loadItems() async {
        isLoadingItems = true
        defer { isLoadingItems = false }
        do {
            orderItems = try await OrderFulfillmentService.shared.fetchOrderItems(orderId: order.id)
        } catch {
            print("[OrderFulfillmentCard] Failed to load items: \(error)")
        }
    }

    // MARK: - Helpers

    private var channelIcon: String {
        switch order.channel {
        case "bopis": return "building.2"
        case "ship_from_store": return "shippingbox"
        case "in_store": return "storefront"
        default: return "globe"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = order.currency
        return f.string(from: NSNumber(value: value)) ?? "₹\(value)"
    }
}
