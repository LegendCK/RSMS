//
//  OrderFulfillmentView.swift
//  RSMS
//
//  Inventory Controller order-fulfilment view.
//
//  Online delivery flow:
//    pending/confirmed → IC checks stock → "Confirm & Dispatch" → shipped
//    shipped + 24 h elapsed → auto-delivered (handled in service layer)
//
//  BOPIS flow (unchanged):
//    pending/confirmed → processing → ready_for_pickup → completed
//
//  No-stock path:
//    IC taps "Confirm & Dispatch" → insufficient stock sheet appears
//    IC taps "Request Replenishment" → transfer record created, IC notified
//    When stock arrives (IC adds via Add Stock) → IC retries dispatch

import SwiftUI
import SwiftData

// MARK: - OrderFulfillmentView

struct OrderFulfillmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var orders: [OrderDTO] = []
    @State private var isLoading = false
    @State private var selectedFilter: FulfillFilter = .pending
    @State private var errorMessage = ""
    @State private var showError = false

    enum FulfillFilter: String, CaseIterable {
        case pending    = "New"
        case processing = "Processing"
        case shipped    = "Shipped"
        case all        = "All"
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
                statPill(value: "\(pendingCount)",    label: "New",        color: AppColors.warning)
                statPill(value: "\(processingCount)", label: "Processing", color: AppColors.accent)
                statPill(value: "\(shippedCount)",    label: "Shipped",    color: AppColors.success)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)

            // Filter
            Picker("", selection: $selectedFilter) {
                ForEach(FulfillFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.sm)

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading orders…").tint(AppColors.accent)
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
            Text(value).font(AppTypography.heading3).foregroundColor(color)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
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

    @State private var isUpdating       = false
    @State private var orderItems: [OrderItemWithProduct] = []
    @State private var isExpanded       = false
    @State private var isLoadingItems   = false
    @State private var isCheckingStock  = false

    // Stock-check result
    @State private var availability: [InventoryAvailability] = []
    @State private var stockChecked    = false

    // Sheets / alerts
    @State private var showStockSheet  = false
    @State private var errorMessage    = ""
    @State private var showError       = false

    // MARK: - Computed

    private var canonicalStatus: String { OrderStatusMapper.canonical(order.status) }

    private var isOnlineDelivery: Bool {
        order.channel == "online" || order.channel == "ship_from_store"
    }

    private var insufficientItems: [InventoryAvailability] {
        availability.filter { !$0.isSufficient }
    }

    /// True once stock has been checked, items loaded, and everything is available.
    private var stockOK: Bool {
        stockChecked && !orderItems.isEmpty && insufficientItems.isEmpty
    }

    private var statusColor: Color {
        switch canonicalStatus {
        case "pending", "confirmed": return AppColors.warning
        case "processing":          return AppColors.accent
        case "shipped", "ready_for_pickup": return AppColors.success
        default:                    return AppColors.neutral600
        }
    }

    private var statusLabel: String {
        switch canonicalStatus {
        case "pending":          return "PENDING"
        case "confirmed":        return "CONFIRMED"
        case "processing":       return "PROCESSING"
        case "shipped":          return "SHIPPED"
        case "ready_for_pickup": return "READY FOR PICKUP"
        default:                 return order.status.uppercased()
        }
    }

    /// Primary action button spec — nil when no action available.
    private var nextAction: (label: String, status: String, icon: String)? {
        switch canonicalStatus {
        case "pending", "confirmed":
            // Online delivery: single-step "Confirm & Dispatch" → ships directly
            if isOnlineDelivery {
                return ("Confirm & Dispatch", "shipped", "shippingbox.fill")
            }
            return ("Start Processing", "processing", "arrow.triangle.2.circlepath")
        case "processing":
            return order.channel == "bopis"
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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {

            // ── Header row ──────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(order.orderNumber ?? "—")
                            .font(AppTypography.monoID)
                            .foregroundColor(AppColors.textPrimaryDark)
                        // Channel badge
                        Text(channelLabel)
                            .font(AppTypography.pico)
                            .tracking(0.8)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.backgroundTertiary)
                            .cornerRadius(4)
                    }
                    Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(order.customerName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    if let email = order.customerEmail, !email.isEmpty {
                        Text(email)
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusLabel)
                        .font(AppTypography.pico)
                        .tracking(1)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(4)
                    // Stock status badge (shown after check)
                    if stockChecked {
                        stockBadge
                    }
                }
            }

            // ── Total + item count ───────────────────────────────────
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
                Text("\(max(order.itemCount, 0)) item\(order.itemCount == 1 ? "" : "s") · Qty \(max(order.totalQuantity, 0))")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
            }

            // ── Expand items ─────────────────────────────────────────
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
                expandedItemsSection
            }

            // ── Action area ───────────────────────────────────────────
            if let action = nextAction {
                VStack(spacing: AppSpacing.xs) {
                    // For online delivery: "Check Stock" helper before dispatching
                    if isOnlineDelivery && ["pending", "confirmed"].contains(canonicalStatus) && !stockChecked {
                        Button {
                            Task { await checkStock() }
                        } label: {
                            HStack(spacing: 6) {
                                if isCheckingStock {
                                    ProgressView().tint(AppColors.accent).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checklist")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(isCheckingStock ? "Checking…" : "Check Stock Availability")
                                    .font(AppTypography.buttonPrimary)
                            }
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColors.accent.opacity(0.1))
                            .cornerRadius(AppSpacing.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .disabled(isCheckingStock)
                    }

                    // Primary action button
                    Button {
                        Task { await performStatusUpdate(newStatus: action.status) }
                    } label: {
                        HStack(spacing: 6) {
                            if isUpdating {
                                ProgressView().tint(.white).scaleEffect(0.8)
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
                        .background(
                            // Dim if stock was checked and is insufficient
                            (stockChecked && !insufficientItems.isEmpty) ? AppColors.neutral500 : statusColor
                        )
                        .cornerRadius(AppSpacing.radiusMedium)
                    }
                    .disabled(isUpdating)

                    // Items not synced — request admin to investigate
                    if stockChecked && orderItems.isEmpty {
                        Button { showStockSheet = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.shield.checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Request Admin Review")
                                    .font(AppTypography.buttonPrimary)
                            }
                            .foregroundColor(AppColors.warning)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColors.warning.opacity(0.1))
                            .cornerRadius(AppSpacing.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .stroke(AppColors.warning.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }

                    // Show "Request Replenishment" when stock is clearly short
                    if stockChecked && !orderItems.isEmpty && !insufficientItems.isEmpty {
                        Button {
                            showStockSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Request Stock Replenishment")
                                    .font(AppTypography.buttonPrimary)
                            }
                            .foregroundColor(AppColors.warning)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColors.warning.opacity(0.1))
                            .cornerRadius(AppSpacing.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .stroke(AppColors.warning.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showStockSheet) {
            InsufficientStockSheet(
                orderNumber: order.orderNumber ?? "—",
                insufficientItems: insufficientItems,
                storeId: storeId,
                onRequested: {
                    showStockSheet = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            )
        }
    }

    // MARK: - Expanded Items

    @ViewBuilder
    private var expandedItemsSection: some View {
        if isLoadingItems {
            HStack {
                ProgressView().tint(AppColors.accent)
                Text("Loading items…")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .padding(.vertical, AppSpacing.xs)
        } else if orderItems.isEmpty {
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.warning)
                    Text("Items not synced from database")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.warning)
                }
                Text("Run the SQL fix in Supabase or request admin to check this order.")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, AppSpacing.xs)
        } else {
            VStack(spacing: AppSpacing.xs) {
                ForEach(orderItems) { item in
                    let avail = availability.first(where: { $0.productId.uuidString.lowercased() == item.product_id.lowercased() })
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
                            Text("SKU: \(item.productSku) · Need: \(item.quantity)")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.textSecondaryDark)
                            // Stock availability inline
                            if let avail {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(avail.isSufficient ? AppColors.success : AppColors.error)
                                        .frame(width: 6, height: 6)
                                    Text(avail.isSufficient
                                         ? "In stock (\(avail.available) avail.)"
                                         : "Low stock (\(avail.available)/\(avail.required) needed)")
                                        .font(AppTypography.micro)
                                        .foregroundColor(avail.isSufficient ? AppColors.success : AppColors.error)
                                }
                            }
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

    // MARK: - Stock badge

    private var stockBadge: some View {
        HStack(spacing: 4) {
            if orderItems.isEmpty {
                Circle().fill(AppColors.warning).frame(width: 6, height: 6)
                Text("Items Unsynced")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.warning)
            } else if insufficientItems.isEmpty {
                Circle().fill(AppColors.success).frame(width: 6, height: 6)
                Text("Stock OK")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.success)
            } else {
                Circle().fill(AppColors.error).frame(width: 6, height: 6)
                Text("\(insufficientItems.count) item\(insufficientItems.count == 1 ? "" : "s") short")
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.error)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func checkStock() async {
        guard let sid = storeId else { return }
        isCheckingStock = true
        defer { isCheckingStock = false }

        if orderItems.isEmpty { await loadItems() }
        do {
            availability = try await OrderFulfillmentService.shared.checkInventoryAvailability(
                items: orderItems,
                storeId: sid
            )
            stockChecked = true
            // Auto-expand so IC can see per-item stock inline
            withAnimation(.spring(response: 0.3)) { isExpanded = true }
        } catch {
            errorMessage = "Stock check failed: \(error.localizedDescription)"
            showError = true
        }
    }

    @MainActor
    private func performStatusUpdate(newStatus: String) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let targetCanonical = OrderStatusMapper.canonical(newStatus)
            let currentCanonical = OrderStatusMapper.canonical(order.status)

            // For transitions that move items off the shelf, decrement inventory
            let needsDecrement = ["processing", "shipped"].contains(targetCanonical)
            if needsDecrement {
                if orderItems.isEmpty { await loadItems() }
                if let sid = storeId {
                    // If stock check hasn't run yet, run it now silently
                    if !stockChecked {
                        availability = (try? await OrderFulfillmentService.shared.checkInventoryAvailability(
                            items: orderItems, storeId: sid)) ?? []
                        stockChecked = true
                    }
                    // If insufficient, show the sheet instead of proceeding
                    if !insufficientItems.isEmpty {
                        isUpdating = false
                        showStockSheet = true
                        return
                    }
                    // Decrement inventory for each item
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

            // Server state machine requires sequential transitions.
            // If order is still "pending" and target skips "confirmed"
            // (e.g. "Confirm & Dispatch" → shipped), advance to confirmed first
            // so the audit trail shows both steps.
            if currentCanonical == "pending" && !["confirmed", "cancelled"].contains(targetCanonical) {
                try await OrderFulfillmentService.shared.updateOrderStatus(
                    orderId: order.id,
                    newStatus: "confirmed",
                    notes: "Auto-confirmed on dispatch"
                )
            }

            try await OrderFulfillmentService.shared.updateOrderStatus(
                orderId: order.id,
                newStatus: newStatus
            )

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            NotificationCenter.default.post(name: .inventoryStockUpdated, object: nil)
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
        case "bopis":           return "building.2"
        case "ship_from_store": return "shippingbox"
        case "in_store":        return "storefront"
        default:                return "globe"
        }
    }

    private var channelLabel: String {
        switch order.channel {
        case "bopis":           return "BOPIS"
        case "ship_from_store": return "SHIP FROM STORE"
        case "in_store":        return "IN-STORE"
        default:                return "ONLINE"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = order.currency
        return f.string(from: NSNumber(value: value)) ?? "₹\(value)"
    }
}

// MARK: - Insufficient Stock Sheet

struct InsufficientStockSheet: View {
    let orderNumber: String
    let insufficientItems: [InventoryAvailability]
    let storeId: UUID?
    let onRequested: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    @State private var requestDone  = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // Warning icon
                        ZStack {
                            Circle()
                                .fill(AppColors.warning.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(AppColors.warning)
                        }
                        .padding(.top, AppSpacing.lg)

                        VStack(spacing: AppSpacing.xs) {
                            Text(insufficientItems.isEmpty ? "Items Not Synced" : "Insufficient Stock")
                                .font(AppTypography.heading2)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text(insufficientItems.isEmpty
                                 ? "Order \(orderNumber) items could not be loaded from the database. Request admin to verify and add stock manually."
                                 : "Order \(orderNumber) cannot be dispatched — the following items are understocked at this boutique.")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, AppSpacing.lg)

                        // Understocked items list (only when we have specific items)
                        if !insufficientItems.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(insufficientItems.enumerated()), id: \.offset) { idx, item in
                                HStack(spacing: AppSpacing.sm) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.error.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppColors.error)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.productName)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                            .lineLimit(2)
                                        Text("Need \(item.required) · Have \(item.available) · Short by \(item.shortfall)")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.error)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.sm)
                                if idx < insufficientItems.count - 1 {
                                    GoldDivider().padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        } // end if !insufficientItems.isEmpty

                        // Info note
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.info)
                            Text(insufficientItems.isEmpty
                                 ? "This request will notify the corporate admin. Once verified and stock is added via Add Stock, the IC can count and dispatch."
                                 : "Requesting replenishment notifies the corporate admin to arrange incoming stock. Once added via Add Stock, you can dispatch this order.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.info.opacity(0.08))
                        .cornerRadius(AppSpacing.radiusMedium)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Actions
                        VStack(spacing: AppSpacing.sm) {
                            if requestDone {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.success)
                                    Text("Request sent to corporate admin")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.success)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColors.success.opacity(0.1))
                                .cornerRadius(AppSpacing.radiusMedium)

                                Button("Done") { onRequested() }
                                    .font(AppTypography.buttonSecondary)
                                    .foregroundColor(AppColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            } else {
                                Button {
                                    Task { await sendReplenishmentRequests() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isRequesting {
                                            ProgressView().tint(.white).scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        Text(isRequesting ? "Sending Request…" : "Request Stock Replenishment")
                                            .font(AppTypography.buttonPrimary)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(AppColors.warning)
                                    .cornerRadius(AppSpacing.radiusMedium)
                                }
                                .disabled(isRequesting)

                                Button("Cancel") { dismiss() }
                                    .font(AppTypography.buttonSecondary)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Stock Alert")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(AppTypography.closeButton)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
        }
    }

    @MainActor
    private func sendReplenishmentRequests() async {
        guard let sid = storeId else { return }
        isRequesting = true
        defer { isRequesting = false }

        if insufficientItems.isEmpty {
            // No-items case: admin is notified via the Fulfillment tab.
            // No transfer record needed — just mark done.
            requestDone = true
            return
        }

        // Create one transfer record per understocked product
        for item in insufficientItems {
            await OrderFulfillmentService.shared.requestReplenishment(
                productId: item.productId,
                storeId: sid,
                quantity: item.shortfall,
                orderNumber: orderNumber
            )
        }
        requestDone = true
    }
}
