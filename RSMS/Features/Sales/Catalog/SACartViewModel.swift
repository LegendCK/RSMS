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

    // MARK: - Checkout flow state
    var showCart        = false
    var showCheckout    = false
    var showConfirmation = false
    var isProcessing    = false
    var errorMessage: String? = nil
    var completedOrderNumber: String? = nil

    // MARK: - Computed: counts & subtotal

    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var isEmpty:   Bool { items.isEmpty }
    var subtotal:  Double { items.reduce(0) { $0 + $1.lineTotal } }

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
    var tax:   Double { discountedSubtotal * taxRate }
    var total: Double { discountedSubtotal + tax }

    // MARK: - Formatted strings

    var formattedSubtotal:  String { fmt(subtotal)  }
    var formattedDiscount:  String { fmt(discountAmount) }
    var formattedTax:       String { fmt(tax) }
    var formattedTotal:     String { fmt(total) }

    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle  = .currency
        f.currencyCode = "INR"
        return f.string(from: NSNumber(value: v)) ?? "₹\(v)"
    }

    // MARK: - Cart mutations

    func addItem(_ product: ProductDTO) {
        if let idx = items.firstIndex(where: { $0.productId == product.id }) {
            items[idx].quantity += 1
        } else {
            items.append(SACartItem(
                productId:    product.id,
                productName:  product.name,
                productBrand: product.brand ?? "Maison Luxe",
                unitPrice:    product.price,
                imageURL:     product.resolvedImageURLs.first
            ))
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
        items                 = []
        selectedClient        = nil
        discountInput         = ""
        discountMode          = .percent
        completedOrderNumber  = nil
        showCart              = false
        showCheckout          = false
        showConfirmation      = false
    }

    // MARK: - Complete Sale

    /// Saves locally, syncs to Supabase, decrements inventory, then signals confirmation.
    @MainActor
    func completeSale(
        paymentMethod: String,
        notes: String,
        associateProfile: UserDTO?,
        modelContext: ModelContext
    ) async {
        guard !items.isEmpty else { return }
        isProcessing  = true
        errorMessage  = nil
        defer { isProcessing = false }

        let orderNumber = generateOrderNumber()

        // 1 ── Local SwiftData save (always succeeds)
        let order = Order(
            orderNumber:         orderNumber,
            customerEmail:       selectedClient?.email ?? "walk-in@maisonluxe.com",
            status:              .completed,
            orderItems:          buildItemsJSON(),
            subtotal:            subtotal,
            tax:                 tax,
            discount:            discountAmount,
            total:               total,
            fulfillmentType:     .inStore,
            paymentMethod:       paymentMethod,
            notes:               notes,
            salesAssociateEmail: associateProfile?.email ?? "",
            boutiqueId:          associateProfile?.storeId?.uuidString ?? ""
        )
        modelContext.insert(order)
        try? modelContext.save()

        // 2 ── Supabase edge-function sync (non-fatal)
        if let clientId = selectedClient?.id {
            let payload = items.map { (
                productId:   $0.productId,
                productName: $0.productName,
                quantity:    $0.quantity,
                unitPrice:   $0.unitPrice
            ) }
            do {
                try await OrderService.shared.syncOrder(
                    clientId:      clientId,
                    cartItems:     payload,
                    orderNumber:   orderNumber,
                    subtotal:      subtotal,
                    discountTotal: discountAmount,
                    taxTotal:      tax,
                    grandTotal:    total,
                    channel:       "in_store"
                )
            } catch {
                print("[SACartVM] Supabase sync failed (order saved locally): \(error.localizedDescription)")
            }
        }

        // 3 ── Inventory decrement (non-fatal)
        if let storeId = associateProfile?.storeId {
            await decrementInventory(storeId: storeId)
        }

        completedOrderNumber = orderNumber
        showCheckout         = false
        showConfirmation     = true
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

    /// Decrements each sold item's quantity in the Supabase `inventory` table
    /// for the SA's store. Failures are logged and skipped — the sale still completes.
    @MainActor
    private func decrementInventory(storeId: UUID) async {
        let db = SupabaseManager.shared.client

        struct QtyPatch: Encodable { let quantity: Int }

        for item in items {
            do {
                let rows: [InventoryDTO] = try await db
                    .from("inventory")
                    .select()
                    .eq("store_id",  value: storeId.uuidString.lowercased())
                    .eq("product_id", value: item.productId.uuidString.lowercased())
                    .limit(1)
                    .execute()
                    .value

                guard let current = rows.first else { continue }
                let newQty = max(0, current.quantity - item.quantity)

                try await db
                    .from("inventory")
                    .update(QtyPatch(quantity: newQty))
                    .eq("store_id",  value: storeId.uuidString.lowercased())
                    .eq("product_id", value: item.productId.uuidString.lowercased())
                    .execute()

                print("[SACartVM] Inventory updated: \(item.productName) → \(newQty) remaining")
            } catch {
                print("[SACartVM] Inventory decrement failed for \(item.productName): \(error.localizedDescription)")
            }
        }
    }
}
