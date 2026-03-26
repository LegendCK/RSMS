//
//  SACartViewModel.swift
//  RSMS
//
//  SA POS cart — manages in-memory items, discount logic (loyalty tier + manual override),
//  tax calculation, and completes the sale (local SwiftData save + Supabase edge-function sync
//  + inventory decrement).
//

import Foundation
import SwiftData
import Supabase

@Observable
final class SACartViewModel {

    // MARK: - Cart items
    var items: [SACartItem] = []

    // MARK: - Associated client (optional — walk-in sales allowed)
    var selectedClient: ClientDTO? = nil

    // MARK: - Discount
    enum DiscountMode: String, CaseIterable, Identifiable {
        case percent     = "% Off"
        case flat        = "$ Off"
        var id: Self { self }
    }
    var discountMode: DiscountMode = .percent
    var discountInput: String = ""        // raw text from the field

    // MARK: - Tax-free sale
    var isTaxFree: Bool    = false
    var taxFreeReason: String = ""   // e.g. document reference number
    var selectedExemptionReason: TaxExemptionReason = .diplomaticMission

    // MARK: - Fulfillment mode (in-stock hand-over vs order for delivery)
    /// When true the item is in stock and handed to the customer on the spot.
    /// When false the SA creates an order that will be shipped to the customer.
    var isHandoverNow: Bool = true

    // MARK: - Checkout flow state
    var showCart        = false
    var showCheckout    = false
    var showConfirmation = false
    var isProcessing    = false
    var errorMessage: String? = nil
    var completedOrderNumber: String? = nil
    var completedPaymentMethod: String = ""
    var completedIsHandover: Bool = true

    // MARK: - Computed: counts & subtotal

    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var isEmpty:   Bool { items.isEmpty }
    var subtotal:  Double { items.reduce(0) { $0 + $1.lineTotal } }
    var hasOutOfStockItems: Bool { items.contains { !$0.isInStockAtAdd } }

    // MARK: - Discount logic

    /// Auto-discount percentage driven by the selected client's loyalty segment.
    var loyaltyDiscountPercent: Double {
        switch selectedClient?.segment {
        case "silver":    return 0.03
        case "gold":      return 0.05
        case "vip":       return 0.10
        case "ultra_vip": return 0.15
        default:          return 0.00
        }
    }

    /// Human-readable label for the loyalty tier benefit.
    var loyaltyLabel: String? {
        guard loyaltyDiscountPercent > 0, let seg = selectedClient?.segment else { return nil }
        let pct = Int(loyaltyDiscountPercent * 100)
        return "\(seg.capitalized.replacingOccurrences(of: "_", with: " ")) tier — \(pct)% auto-applied"
    }

    /// Manual discount amount computed from the SA's input.
    private var manualDiscountAmount: Double {
        let value = Double(discountInput) ?? 0
        guard value > 0 else { return 0 }
        switch discountMode {
        case .percent: return subtotal * min(value / 100.0, 1.0)
        case .flat:    return min(value, subtotal)
        }
    }

    /// Effective discount = whichever is larger: loyalty tier or manual override.
    var discountAmount: Double {
        max(subtotal * loyaltyDiscountPercent, manualDiscountAmount)
    }

    var discountedSubtotal: Double { max(0, subtotal - discountAmount) }

    /// Tax rate fetched from Supabase via TaxService (no hardcoded fallback).
    var taxRate: Double { TaxService.shared.rate() }
    /// Tax is zero for tax-free transactions; otherwise calculated from discounted subtotal.
    var tax:   Double { isTaxFree ? 0 : discountedSubtotal * taxRate }
    var total: Double { discountedSubtotal + tax }

    // MARK: - Formatted strings

    var formattedSubtotal:  String { fmt(subtotal)  }
    var formattedDiscount:  String { fmt(discountAmount) }
    var formattedTax:       String { fmt(tax) }
    var formattedTotal:     String { fmt(total) }

    func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle  = .currency
        f.currencyCode = "INR"
        return f.string(from: NSNumber(value: v)) ?? "₹\(v)"
    }

    // MARK: - Cart mutations

    func addItem(_ product: ProductDTO, color: String? = nil, size: String? = nil, isInStock: Bool = true) {
        if let idx = items.firstIndex(where: {
            $0.productId == product.id &&
            $0.selectedColor == color &&
            $0.selectedSize == size
        }) {
            items[idx].quantity += 1
        } else {
            items.append(SACartItem(
                productId:     product.id,
                productName:   product.name,
                productBrand:  product.brand ?? "Maison Luxe",
                unitPrice:     product.price,
                imageURL:      product.resolvedImageURLs.first,
                isInStockAtAdd: isInStock,
                selectedColor: color,
                selectedSize:  size
            ))
        }
        if !isInStock {
            isHandoverNow = false
        }
    }

    func removeItem(_ item: SACartItem) {
        items.removeAll { $0.id == item.id }
    }

    func updateQuantity(_ item: SACartItem, qty: Int) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if qty <= 0 { items.remove(at: idx) } else { items[idx].quantity = qty }
    }

    func clearCart() {
        items                  = []
        selectedClient         = nil
        discountInput          = ""
        discountMode           = .percent
        isTaxFree              = false
        taxFreeReason          = ""
        selectedExemptionReason = .diplomaticMission
        isHandoverNow          = true
        completedOrderNumber   = nil
        completedPaymentMethod = ""
        completedIsHandover    = true
        showCart               = false
        showCheckout           = false
        showConfirmation       = false
    }

    // MARK: - Complete Sale

    /// Saves locally, syncs to Supabase, decrements inventory, then signals confirmation.
    @MainActor
    func completeSale(
        paymentSummary: String,
        paymentSplits: [OrderService.PaymentSplitInput],
        notes: String,
        associateProfile: UserDTO?,
        modelContext: ModelContext
    ) async {
        guard !items.isEmpty else { return }
        isProcessing  = true
        errorMessage  = nil
        defer { isProcessing = false }

        let orderNumber = generateOrderNumber()

        // Build formatted tax-free reason with exemption category for audit trail
        let formattedTaxFreeReason: String = {
            guard isTaxFree else { return "" }
            var parts = [selectedExemptionReason.rawValue]
            let ref = taxFreeReason.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ref.isEmpty { parts.append("Ref: \(ref)") }
            if let name = associateProfile?.fullName { parts.append("Verified by: \(name)") }
            return parts.joined(separator: " | ")
        }()

        // Determine fulfillment mode: hand-over (in-store, completed) vs order for delivery (ship, pending)
        let orderStatus: OrderStatus = isHandoverNow ? .completed : .pending
        let fulfillment: FulfillmentType = isHandoverNow ? .inStore : .shipFromStore
        let channel = isHandoverNow ? "in_store" : "ship_from_store"

        // 1 ── Local SwiftData save (always succeeds)
        let order = Order(
            orderNumber:         orderNumber,
            customerEmail:       selectedClient?.email ?? "walk-in@maisonluxe.com",
            status:              orderStatus,
            orderItems:          buildItemsJSON(),
            subtotal:            subtotal,
            tax:                 tax,
            discount:            discountAmount,
            total:               total,
            fulfillmentType:     fulfillment,
            paymentMethod:       paymentSummary,
            notes:               notes,
            salesAssociateEmail: associateProfile?.email ?? "",
            boutiqueId:          associateProfile?.storeId?.uuidString ?? "",
            isTaxFree:           isTaxFree,
            taxFreeReason:       formattedTaxFreeReason
        )
        modelContext.insert(order)
        try? modelContext.save()

        // 2 ── Supabase edge-function sync (required before success confirmation)
        let cartPayload = items.map { (
            productId:   $0.productId,
            productName: $0.productName,
            quantity:    $0.quantity,
            unitPrice:   $0.unitPrice
        ) }
        do {
            // Wrap sync in a 15-second timeout so a dropped/slow connection
            // doesn't leave the UI stuck on "Processing…" indefinitely.
            let syncResult = try await withThrowingTaskGroup(of: OrderService.SyncOrderResult.self) { group in
                group.addTask {
                    try await self.syncOrderWithRetry(
                        clientId: self.selectedClient?.id,
                        cartItems: cartPayload,
                        orderNumber: orderNumber,
                        subtotal: self.subtotal,
                        discountTotal: self.discountAmount,
                        taxTotal: self.tax,
                        grandTotal: self.total,
                        channel: channel,
                        storeId: associateProfile?.storeId,
                        isTaxFree: self.isTaxFree,
                        taxFreeReason: formattedTaxFreeReason,
                        notes: notes,
                        paymentSplits: paymentSplits
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    throw OrderServiceError.edgeFunctionError("Request timed out. Check your connection.")
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            if !isHandoverNow {
                let workflowStoreId = syncResult.storeId ?? associateProfile?.storeId
                let needsClientFallback = syncResult.replenishmentsRequested == 0
                if let storeId = workflowStoreId {
                await triggerOutOfStockWorkflow(
                    orderNumber: orderNumber,
                    storeId: storeId,
                    clientId: selectedClient?.id,
                    createReplenishmentRequests: needsClientFallback
                )
                }
            } else if let clientId = selectedClient?.id {
                await NotificationService.shared.createOrderLifecycleNotification(
                    clientId: clientId,
                    storeId: associateProfile?.storeId,
                    title: "Order Confirmed",
                    message: "Your order \(orderNumber) has been placed successfully.",
                    deepLink: "orders"
                )
            }
        } catch {
            print("[SACartVM] Supabase sync failed (order saved locally): \(error.localizedDescription)")
            errorMessage = "Sale was saved locally, but cloud sync failed. Please try again."
            return
        }

        // 3 ── Inventory decrement (non-fatal, only for hand-over sales where stock leaves now)
        if isHandoverNow, let storeId = associateProfile?.storeId {
            await decrementInventory(storeId: storeId)
        }

        completedOrderNumber   = orderNumber
        completedPaymentMethod = paymentSummary
        completedIsHandover    = isHandoverNow
        showCheckout           = false
        showConfirmation       = true
    }

    // MARK: - Private helpers

    private func generateOrderNumber() -> String {
        let year   = Calendar.current.component(.year, from: Date())
        let random = String(format: "%04d", Int.random(in: 1000...9999))
        return "ML-POS-\(year)-\(random)"
    }

    private func buildItemsJSON() -> String {
        let arr: [[String: Any]] = items.map {
            ["name": $0.productName, "brand": $0.productBrand,
             "qty": $0.quantity, "price": $0.unitPrice]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let str  = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    /// Decrements each sold item's quantity using the SECURITY DEFINER RPC path,
    /// so Sales Associate role permissions do not block inventory sync.
    @MainActor
    private func decrementInventory(storeId: UUID) async {
        for item in items {
            do {
                try await OrderFulfillmentService.shared.decrementInventory(
                    productId: item.productId,
                    storeId: storeId,
                    quantity: item.quantity
                )
                print("[SACartVM] Inventory decremented via RPC: \(item.productName) -\(item.quantity)")
            } catch {
                print("[SACartVM] Inventory decrement failed for \(item.productName): \(error.localizedDescription)")
            }
        }
    }

    private func syncOrderWithRetry(
        clientId: UUID?,
        cartItems: [(productId: UUID, productName: String, quantity: Int, unitPrice: Double)],
        orderNumber: String,
        subtotal: Double,
        discountTotal: Double,
        taxTotal: Double,
        grandTotal: Double,
        channel: String,
        storeId: UUID?,
        isTaxFree: Bool,
        taxFreeReason: String,
        notes: String,
        paymentSplits: [OrderService.PaymentSplitInput]
    ) async throws -> OrderService.SyncOrderResult {
        let maxAttempts = 2
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await OrderService.shared.syncOrder(
                    clientId:      clientId,
                    cartItems:     cartItems,
                    orderNumber:   orderNumber,
                    subtotal:      subtotal,
                    discountTotal: discountTotal,
                    taxTotal:      taxTotal,
                    grandTotal:    grandTotal,
                    channel:       channel,
                    storeId:       storeId,
                    isTaxFree:     isTaxFree,
                    taxFreeReason: taxFreeReason,
                    notes:         notes,
                    paymentSplits: paymentSplits
                )
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            }
        }

        throw lastError ?? OrderServiceError.edgeFunctionError("Unknown sync failure")
    }

    @MainActor
    private func triggerOutOfStockWorkflow(
        orderNumber: String,
        storeId: UUID,
        clientId: UUID?,
        createReplenishmentRequests: Bool
    ) async {
        let outOfStockGrouped = Dictionary(grouping: items.filter { !$0.isInStockAtAdd }, by: \.productId)
            .mapValues { rows in rows.reduce(0) { $0 + $1.quantity } }

        if createReplenishmentRequests {
            for (productId, quantity) in outOfStockGrouped {
                await OrderFulfillmentService.shared.requestReplenishment(
                    productId: productId,
                    storeId: storeId,
                    quantity: quantity,
                    orderNumber: orderNumber
                )
            }
        }

        guard let clientId else { return }
        await NotificationService.shared.createOrderLifecycleNotification(
            clientId: clientId,
            storeId: storeId,
            title: "Order Accepted - Stock Requested",
            message: "Order \(orderNumber) is confirmed. We have requested stock approval and will notify you when it is ready for pickup.",
            deepLink: "orders"
        )
    }
}
