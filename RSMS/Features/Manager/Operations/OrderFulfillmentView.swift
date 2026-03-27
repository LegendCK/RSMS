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
import Supabase

// MARK: - OrderFulfillmentView

struct OrderFulfillmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var orders: [OrderDTO] = []
    @State private var isLoading = false
    @State private var selectedFilter: FulfillFilter = .pending
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var realtimeChannel: RealtimeChannelV2?

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

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.sm) {
                filterRow
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            // ── Content ────────────────────────────────────────────────
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(AppColors.accent)
                    .scaleEffect(1.1)
                Spacer()
            } else if filteredOrders.isEmpty {
                emptyState
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
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .refreshable { await loadOrders() }
            }
        }
        .task {
            await subscribeToLiveOrders()
            await loadOrders()
        }
        .onDisappear {
            Task { await unsubscribeRealtime() }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Sub-views

    private var filterRow: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(FulfillFilter.allCases, id: \.self) { filter in
                filterPill(filter)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func filterPill(_ filter: FulfillFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedFilter = filter }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .tracking(0.2)
                .foregroundColor(isSelected ? AppColors.textPrimaryLight : AppColors.textPrimaryDark)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accent : AppColors.backgroundSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppColors.accent.opacity(0.65) : AppColors.border.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(AppColors.success)
            }
            Text("All Caught Up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimaryDark)
            Text("No \(selectedFilter.rawValue.lowercased()) orders to process")
                .font(.system(size: 14))
                .foregroundColor(Color(uiColor: .secondaryLabel))
            Spacer()
        }
    }



    private func subscribeToLiveOrders() async {
        await unsubscribeRealtime()
        guard let storeId = appState.currentStoreId else { return }

        let storeFilter = storeId.uuidString.lowercased()
        let channel = SupabaseManager.shared.client
            .realtimeV2
            .channel("order-fulfillment:\(storeFilter)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "orders",
            filter: .eq("store_id", value: storeFilter)
        )
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "orders",
            filter: .eq("store_id", value: storeFilter)
        )
        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "orders",
            filter: .eq("store_id", value: storeFilter)
        )

        do {
            try await channel.subscribeWithError()
            realtimeChannel = channel
        } catch {
            if isExpectedCancellation(error) { return }
            print("[OrderFulfillmentView] Realtime subscribe failed: \(error)")
            return
        }

        Task { @MainActor in
            for await _ in insertions {
                await loadOrders()
            }
        }
        Task { @MainActor in
            for await _ in updates {
                await loadOrders()
            }
        }
        Task { @MainActor in
            for await _ in deletions {
                await loadOrders()
            }
        }
    }

    private func unsubscribeRealtime() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }
    }

    // MARK: - Data

    @MainActor
    private func loadOrders() async {
        guard let storeId = appState.currentStoreId else { return }
        if Task.isCancelled { return }
        isLoading = orders.isEmpty
        defer { isLoading = false }
        do {
            orders = try await OrderFulfillmentService.shared.fetchFulfillmentOrders(storeId: storeId)
        } catch {
            if isExpectedCancellation(error) { return }
            errorMessage = "Failed to load orders: \(error.localizedDescription)"
            showError = true
        }
    }

    private func isExpectedCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let message = error.localizedDescription.lowercased()
        return message == "cancelled" || message.contains("code=-999")
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

    @State private var availability: [InventoryAvailability] = []
    @State private var stockChecked    = false

    @State private var showStockSheet  = false
    @State private var errorMessage    = ""
    @State private var showError       = false
    private let cardRadius: CGFloat = 20

    // MARK: - Computed

    private var canonicalStatus: String { OrderStatusMapper.canonical(order.status) }

    private var isOnlineDelivery: Bool {
        order.channel == "online" || order.channel == "ship_from_store"
    }

    private var insufficientItems: [InventoryAvailability] {
        availability.filter { !$0.isSufficient }
    }

    private var stockOK: Bool {
        stockChecked && !orderItems.isEmpty && insufficientItems.isEmpty
    }

    private var statusColor: Color {
        switch canonicalStatus {
        case "pending", "confirmed":            return Color(hex: "B8860B") // dark gold
        case "processing":                      return AppColors.accent
        case "shipped", "ready_for_pickup":     return AppColors.success
        default:                                return Color(uiColor: .tertiaryLabel)
        }
    }

    private var statusLabel: String {
        switch canonicalStatus {
        case "pending":          return "Pending"
        case "confirmed":        return "Confirmed"
        case "processing":       return "Processing"
        case "shipped":          return "Shipped"
        case "ready_for_pickup": return "Ready for Pickup"
        default:                 return order.status.capitalized
        }
    }

    private var nextAction: (label: String, status: String, icon: String)? {
        switch canonicalStatus {
        case "pending", "confirmed":
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
        VStack(alignment: .leading, spacing: 0) {

            // ── Top meta row: order number · channel · status ──────────
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text(order.orderNumber ?? "—")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                    Text("·")
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                    Text(channelLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                }
                Spacer()
                statusBadge
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)

            // ── Customer (hero) + date ─────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text(order.customerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                if let email = order.customerEmail, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)

            // ── Thin separator ─────────────────────────────────────────
            Rectangle()
                .fill(AppColors.dividerLight.opacity(0.9))
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.md)

            // ── Amount + metadata row ──────────────────────────────────
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                    HStack(spacing: 6) {
                        Image(systemName: channelIcon)
                            .font(.system(size: 11))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                        Text(order.channel.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 12))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                        Text("·")
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                        Text("\(max(order.itemCount, 0)) item\(order.itemCount == 1 ? "" : "s") · Qty \(max(order.totalQuantity, 0))")
                            .font(.system(size: 12))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
                Spacer()
                Text(order.formattedTotal)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accent)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)

            // ── Expand items disclosure ────────────────────────────────
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                if isExpanded && orderItems.isEmpty { Task { await loadItems() } }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "Hide Items" : "View Items")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accent)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                    if stockChecked {
                        Spacer()
                        stockBadge
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, isExpanded ? AppSpacing.sm : AppSpacing.md)
            }

            // ── Expanded items ─────────────────────────────────────────
            if isExpanded {
                expandedItemsSection
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
            }

            // ── Action area ────────────────────────────────────────────
            if let action = nextAction {
                VStack(spacing: AppSpacing.xs) {
                    Rectangle()
                        .fill(AppColors.dividerLight.opacity(0.9))
                        .frame(height: 0.5)

                    VStack(spacing: AppSpacing.xs) {
                        if isOnlineDelivery && ["pending", "confirmed"].contains(canonicalStatus) && !stockChecked {
                            checkStockButton
                        }
                        primaryActionButton(action: action)

                        if stockChecked && orderItems.isEmpty {
                            adminReviewButton
                        }
                        if stockChecked && !orderItems.isEmpty && !insufficientItems.isEmpty {
                            replenishmentButton
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .liquidGlass(
            config: .regular,
            backgroundColor: AppColors.backgroundSecondary,
            cornerRadius: cardRadius
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        )
        .liquidShadow(LiquidShadow.subtle)
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

    // MARK: - Action Buttons

    private var checkStockButton: some View {
        Button {
            Task { await checkStock() }
        } label: {
            HStack(spacing: 8) {
                if isCheckingStock {
                    ProgressView().tint(AppColors.accent).scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "checklist")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isCheckingStock ? "Checking…" : "Check Stock Availability")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(AppColors.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .strokeBorder(AppColors.accent.opacity(0.25), lineWidth: 1)
            )
        }
        .disabled(isCheckingStock)
    }

    private func primaryActionButton(action: (label: String, status: String, icon: String)) -> some View {
        let isInsufficient = stockChecked && !insufficientItems.isEmpty
        return Button {
            Task { await performStatusUpdate(newStatus: action.status) }
        } label: {
            HStack(spacing: 8) {
                if isUpdating {
                    ProgressView().tint(.white).scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: action.icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isUpdating ? "Updating…" : action.label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isInsufficient ? Color(uiColor: .systemGray3) : AppColors.accent
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
        .disabled(isUpdating)
    }

    private var adminReviewButton: some View {
        Button { showStockSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 13, weight: .semibold))
                Text("Request Admin Review")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(AppColors.warning)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(AppColors.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .strokeBorder(AppColors.warning.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var replenishmentButton: some View {
        Button { showStockSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                Text("Request Stock Replenishment")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(AppColors.warning)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(AppColors.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .strokeBorder(AppColors.warning.opacity(0.25), lineWidth: 1)
            )
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Stock Badge

    private var stockBadge: some View {
        HStack(spacing: 4) {
            if orderItems.isEmpty {
                Circle().fill(AppColors.warning).frame(width: 5, height: 5)
                Text("Items Unsynced")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.warning)
            } else if insufficientItems.isEmpty {
                Circle().fill(AppColors.success).frame(width: 5, height: 5)
                Text("Stock OK")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.success)
            } else {
                Circle().fill(AppColors.error).frame(width: 5, height: 5)
                Text("\(insufficientItems.count) item\(insufficientItems.count == 1 ? "" : "s") short")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.error)
            }
        }
    }

    // MARK: - Expanded Items

    @ViewBuilder
    private var expandedItemsSection: some View {
        if isLoadingItems {
            HStack(spacing: 8) {
                ProgressView().tint(AppColors.accent)
                Text("Loading items…")
                    .font(.system(size: 13))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
            }
            .padding(.vertical, AppSpacing.xs)
        } else if orderItems.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.warning)
                Text("Items not synced from database")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.warning)
            }
            .padding(.vertical, AppSpacing.xs)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(orderItems.enumerated()), id: \.element.id) { idx, item in
                    let avail = availability.first(where: {
                        $0.productId.uuidString.lowercased() == item.product_id.lowercased()
                    })
                    itemRow(item: item, avail: avail)
                    if idx < orderItems.count - 1 {
                        Rectangle()
                            .fill(Color(uiColor: .separator).opacity(0.4))
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private func itemRow(item: OrderItemWithProduct, avail: InventoryAvailability?) -> some View {
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
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .overlay(
                            Image(systemName: "cube.box.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.accent.opacity(0.6))
                        )
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text("SKU: \(item.productSku) · Need: \(item.quantity)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                if let avail {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(avail.isSufficient ? AppColors.success : AppColors.error)
                            .frame(width: 5, height: 5)
                        Text(avail.isSufficient
                             ? "In stock (\(avail.available) avail.)"
                             : "Low stock (\(avail.available)/\(avail.required) needed)")
                            .font(.system(size: 11))
                            .foregroundColor(avail.isSufficient ? AppColors.success : AppColors.error)
                    }
                }
            }
            Spacer()
            Text(formatCurrency(item.line_total))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
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

            let needsDecrement = ["processing", "shipped"].contains(targetCanonical)
            if needsDecrement {
                if orderItems.isEmpty { await loadItems() }
                if let sid = storeId {
                    if !stockChecked {
                        availability = (try? await OrderFulfillmentService.shared.checkInventoryAvailability(
                            items: orderItems, storeId: sid)) ?? []
                        stockChecked = true
                    }
                    if !insufficientItems.isEmpty {
                        isUpdating = false
                        showStockSheet = true
                        return
                    }
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

            await sendClientStatusNotification(newStatus: targetCanonical)

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

    @MainActor
    private func sendClientStatusNotification(newStatus: String) async {
        guard let clientId = order.clientId else { return }
        let canonical = OrderStatusMapper.canonical(newStatus)
        let message: String
        let title: String

        switch canonical {
        case "processing":
            title = "Order Processing"
            message = "Order \(order.orderNumber ?? "") is now being prepared by the boutique."
        case "ready_for_pickup":
            let deadline = Calendar.current.date(byAdding: .hour, value: 48, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            title = "Ready for Pickup"
            message = "Order \(order.orderNumber ?? "") is ready for pickup. Please collect by \(formatter.string(from: deadline))."
        case "completed":
            title = "Order Collected"
            message = "Order \(order.orderNumber ?? "") has been marked as collected. Thank you for shopping with Maison Luxe."
        default:
            return
        }

        await NotificationService.shared.createOrderLifecycleNotification(
            clientId: clientId,
            storeId: order.storeId,
            title: title,
            message: message,
            deepLink: "orders"
        )
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
                        }

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
            requestDone = true
            return
        }

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
