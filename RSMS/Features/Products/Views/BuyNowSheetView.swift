//
//  BuyNowSheetView.swift
//  RSMS
//
//  Direct-purchase sheet: product summary → address → payment → place order.
//  Bypasses the shopping bag entirely.
//

import SwiftUI
import SwiftData

struct BuyNowSheetView: View {
    let product: Product
    let selectedColor: String
    let selectedSize: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query private var allAddresses: [SavedAddress]
    @Query private var pricingPolicies: [PricingPolicySettings]
    @Query private var taxRules: [IndianTaxRule]
    @Query private var regionalPriceRules: [RegionalPriceRule]

    @State private var currentStep = 0            // 0 = address, 1 = payment, 2 = review
    @State private var selectedAddress: SavedAddress? = nil
    @State private var showAddressManager = false
    @State private var showAddNewAddress  = false

    // Inline address fallback (used when savedAddresses is empty)
    @State private var inlineAddressLine1 = ""
    @State private var inlineAddressLine2 = ""
    @State private var inlineCity         = ""
    @State private var inlineAddrState    = ""
    @State private var inlineZip          = ""

    // Payment
    @State private var selectedPayment: BuyNowPayment = .applePay
    @State private var cardNumber  = ""
    @State private var cardExpiry  = ""
    @State private var cardCVV     = ""

    // Order result
    @State private var placedOrder: Order? = nil
    @State private var showConfirmation    = false
    @State private var isPlacing           = false
    @State private var orderError: String? = nil
    @State private var showOrderError      = false

    private var savedAddresses: [SavedAddress] {
        allAddresses
            .filter { $0.customerEmail == appState.currentUserEmail }
            .sorted { $0.isDefault && !$1.isDefault }
    }

    private var policy: PricingPolicySettings {
        pricingPolicies.first ?? PricingPolicySettings()
    }
    private var buyerStateForTax: String {
        if let selectedAddress {
            return selectedAddress.state
        }
        if !inlineAddrState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return inlineAddrState
        }
        return policy.businessState
    }
    private var pricing: PricingComputation {
        IndianPricingEngine.calculate(
            items: [
                TaxableLineItem(
                    productId: product.id,
                    goodsCategory: product.categoryName,
                    baseUnitPrice: product.price,
                    quantity: 1
                )
            ],
            buyerState: buyerStateForTax,
            policy: policy,
            regionalPrices: regionalPriceRules,
            taxRules: taxRules
        )
    }
    private var subtotal: Double { pricing.subtotal }
    private var tax: Double      { pricing.taxBreakdown.totalTax }
    private var total: Double    { subtotal + tax }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Mini step indicator
                    stepBar

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.lg) {
                            // Always-visible product summary card
                            productSummaryCard
                                .padding(.top, AppSpacing.md)

                            // Step content
                            switch currentStep {
                            case 0: addressStep
                            case 1: paymentStep
                            case 2: reviewStep
                            default: EmptyView()
                            }

                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }

                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Quick Purchase")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .sheet(isPresented: $showAddressManager) {
                AddressManagerView(onSelect: { addr in
                    selectedAddress = addr
                })
            }
            .sheet(isPresented: $showAddNewAddress) {
                AddressEditView()
                    .onDisappear {
                        // Auto-select newly added default
                        if selectedAddress == nil {
                            selectedAddress = savedAddresses.first(where: { $0.isDefault }) ?? savedAddresses.first
                        }
                    }
            }
            .navigationDestination(isPresented: $showConfirmation) {
                if let order = placedOrder {
                    OrderConfirmationView(order: order)
                }
            }
            .alert("Order Failed", isPresented: $showOrderError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(orderError ?? "Something went wrong. Please try again.")
            })
            .onAppear {
                selectedAddress = savedAddresses.first(where: { $0.isDefault }) ?? savedAddresses.first
            }
            .onChange(of: appState.shouldNavigateHome) { _, newValue in
                guard newValue else { return }
                // Dismiss this sheet so navigateToHome() reaches HomeView
                appState.shouldNavigateHome = false
                dismiss()
            }
        }
    }

    // MARK: - Step Bar

    private var stepBar: some View {
        let steps = ["Address", "Payment", "Review"]
        return HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { idx in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(idx <= currentStep ? AppColors.accent : AppColors.backgroundSecondary)
                            .frame(width: 26, height: 26)
                        if idx < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColors.textPrimaryLight)
                        } else {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(idx <= currentStep ? AppColors.textPrimaryLight : AppColors.neutral600)
                        }
                    }
                    Text(steps[idx])
                        .font(AppTypography.caption)
                        .foregroundColor(idx <= currentStep ? AppColors.accent : AppColors.neutral600)
                }
                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(idx < currentStep ? AppColors.accent : AppColors.neutral700.opacity(0.4))
                        .frame(height: 1)
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Product Summary Card

    private var productSummaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: "bag.fill",
                cornerRadius: AppSpacing.radiusMedium
            )
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.brand.uppercased())
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(AppColors.accent)
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    variantPill(selectedColor)
                    if let size = selectedSize { variantPill(size) }
                }
            }

            Spacer()

            Text(formatCurrency(pricing.lineItems.first?.unitPrice ?? product.price))
                .font(AppTypography.priceSmall)
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(AppColors.border.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func variantPill(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.pico)
            .foregroundColor(AppColors.textSecondaryDark)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(20)
    }

    // MARK: - Step 0: Address

    private var addressStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("SHIPPING ADDRESS")

            if savedAddresses.isEmpty {
                // No saved addresses — show inline entry form so user can proceed immediately
                VStack(spacing: AppSpacing.sm) {
                    LuxuryTextField(placeholder: "Address Line 1*", text: $inlineAddressLine1)
                    LuxuryTextField(placeholder: "Address Line 2 (optional)", text: $inlineAddressLine2)
                    HStack(spacing: AppSpacing.sm) {
                        LuxuryTextField(placeholder: "City*", text: $inlineCity)
                        LuxuryTextField(placeholder: "State*", text: $inlineAddrState)
                            .frame(maxWidth: 90)
                    }
                    LuxuryTextField(placeholder: "PIN*", text: $inlineZip)
                        .keyboardType(.numberPad)

                    Button("Save this address for next time") { showAddNewAddress = true }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                // Show saved addresses as a selectable list (max 3 shown)
                ForEach(savedAddresses.prefix(3)) { addr in
                    savedAddressRow(addr)
                }
                // Manage all / add new
                HStack(spacing: AppSpacing.lg) {
                    Button("Manage Addresses") { showAddressManager = true }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                    Button("+ Add New") { showAddNewAddress = true }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                }
                .padding(.top, 4)
            }
        }
    }

    private func savedAddressRow(_ addr: SavedAddress) -> some View {
        let isSelected = selectedAddress?.id == addr.id
        return Button(action: { withAnimation { selectedAddress = addr } }) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.neutral600)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(addr.label)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        if addr.isDefault {
                            Text("DEFAULT")
                                .font(AppTypography.pico)
                                .tracking(1)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.accent.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                    Text(addr.shortSummary)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 1: Payment

    private var paymentStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("PAYMENT METHOD")

            ForEach(BuyNowPayment.allCases, id: \.self) { method in
                paymentRow(method)
            }

            if selectedPayment == .creditCard {
                cardFieldsSection
            }
        }
    }

    private func paymentRow(_ method: BuyNowPayment) -> some View {
        let selected = selectedPayment == method
        return Button(action: { withAnimation { selectedPayment = method } }) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? AppColors.accent.opacity(0.1) : AppColors.backgroundSecondary)
                        .frame(width: 44, height: 44)
                    Image(systemName: method.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(selected ? AppColors.accent : AppColors.neutral600)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(method.subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? AppColors.accent : AppColors.neutral600)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(selected ? AppColors.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var cardFieldsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CARD DETAILS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
            LuxuryTextField(placeholder: "Card Number", text: $cardNumber)
                .keyboardType(.numberPad)
            HStack(spacing: AppSpacing.sm) {
                LuxuryTextField(placeholder: "MM / YY", text: $cardExpiry)
                    .keyboardType(.numberPad)
                LuxuryTextField(placeholder: "CVV", text: $cardCVV)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Step 2: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            sectionHeader("ORDER REVIEW")

            LuxuryCardView {
                VStack(spacing: AppSpacing.sm) {
                    // Deliver to
                    if let addr = selectedAddress {
                        reviewRow(icon: "mappin.circle.fill", title: "Deliver to", value: addr.shortSummary)
                        GoldDivider()
                    } else if !inlineAddressLine1.isEmpty {
                        reviewRow(
                            icon: "mappin.circle.fill",
                            title: "Deliver to",
                            value: "\(inlineAddressLine1), \(inlineCity), \(inlineAddrState) \(inlineZip)"
                        )
                        GoldDivider()
                    }
                    reviewRow(icon: paymentIcon, title: "Payment", value: selectedPayment.title)
                    GoldDivider()
                    reviewRow(icon: "shippingbox.fill", title: "Delivery", value: "5–7 business days · Free")
                }
                .padding(AppSpacing.cardPadding)
            }

            // Price breakdown
            LuxuryCardView {
                VStack(spacing: AppSpacing.sm) {
                    priceRow("Subtotal", value: formatCurrency(subtotal))
                    priceRow("CGST", value: formatCurrency(pricing.taxBreakdown.cgst))
                    priceRow("SGST", value: formatCurrency(pricing.taxBreakdown.sgst))
                    if pricing.taxBreakdown.igst > 0 {
                        priceRow("IGST", value: formatCurrency(pricing.taxBreakdown.igst))
                    }
                    if pricing.taxBreakdown.cess > 0 {
                        priceRow("Cess", value: formatCurrency(pricing.taxBreakdown.cess))
                    }
                    if pricing.taxBreakdown.additionalLevy > 0 {
                        priceRow("Other Tax", value: formatCurrency(pricing.taxBreakdown.additionalLevy))
                    }
                    priceRow("Shipping",  value: "Free")
                    GoldDivider()
                    HStack {
                        Text("Total")
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Spacer()
                        Text(formatCurrency(total))
                            .font(AppTypography.priceDisplay)
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(AppSpacing.cardPadding)
            }
        }
    }

    private var paymentIcon: String {
        switch selectedPayment {
        case .applePay:    return "apple.logo"
        case .creditCard:  return "creditcard.fill"
        case .payInStore:  return "banknote.fill"
        case .googlePay:   return "g.circle.fill"
        }
    }

    private func reviewRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            Text(title)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .multilineTextAlignment(.trailing)
        }
    }

    private func priceRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                if currentStep > 0 {
                    SecondaryButton(title: "Back") {
                        withAnimation(.spring(response: 0.3)) { currentStep -= 1 }
                    }
                    .frame(width: 90)
                }

                if currentStep < 2 {
                    PrimaryButton(title: "Continue") {
                        guard canContinue else { return }
                        withAnimation(.spring(response: 0.3)) { currentStep += 1 }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } else {
                    Button(action: placeOrder) {
                        HStack(spacing: 8) {
                            if isPlacing {
                                ProgressView()
                                    .tint(AppColors.textPrimaryLight)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                            }
                            Text(isPlacing ? "Placing Order…" : "Place Order · \(formatCurrency(total))")
                                .font(AppTypography.buttonPrimary)
                        }
                        .foregroundColor(AppColors.textPrimaryLight)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.touchTarget)
                        .background(AppColors.accent)
                        .cornerRadius(AppSpacing.radiusMedium)
                    }
                    .disabled(isPlacing)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
            .background(
                AppColors.backgroundPrimary
                    .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
            )
        }
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0:
            // Either a saved address is selected, or the inline form has the required fields
            if selectedAddress != nil { return true }
            if !savedAddresses.isEmpty { return false }
            return !inlineAddressLine1.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !inlineCity.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !inlineAddrState.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !inlineZip.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            if selectedPayment == .creditCard {
                return !cardNumber.isEmpty && !cardExpiry.isEmpty && !cardCVV.isEmpty
            }
            return true
        default: return true
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle   = .currency
        f.currencyCode  = policy.currencyCode
        return f.string(from: NSNumber(value: v)) ?? "\(policy.currencyCode) \(v)"
    }

    // MARK: - Place Order

    private func placeOrder() {
        isPlacing = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task { await placeOrderAsync() }
    }

    @MainActor
    private func placeOrderAsync() async {
        defer { isPlacing = false }

        // Build address JSON
        let addrJSON: String = {
            if let addr = selectedAddress {
                let d: [String: String] = [
                    "line1": addr.line1, "line2": addr.line2,
                    "city": addr.city, "state": addr.state,
                    "zip": addr.zip, "country": addr.country
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: d),
                      let s = String(data: data, encoding: .utf8) else { return "{}" }
                return s
            }
            // Inline address fallback
            if !inlineAddressLine1.isEmpty {
                let d: [String: String] = [
                    "line1": inlineAddressLine1, "line2": inlineAddressLine2,
                    "city": inlineCity, "state": inlineAddrState,
                    "zip": inlineZip, "country": "IN"
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: d),
                      let s = String(data: data, encoding: .utf8) else { return "{}" }
                return s
            }
            return "{}"
        }()

        let effectiveUnitPrice = pricing.lineItems.first?.unitPrice ?? product.price
        let itemArr: [[String: Any]] = [[
            "name": product.name, "brand": product.brand,
            "qty": 1, "price": effectiveUnitPrice,
            "color": selectedColor,
            "size": selectedSize ?? "",
            "image": product.imageName
        ]]
        let itemsJSON: String = {
            guard let data = try? JSONSerialization.data(withJSONObject: itemArr),
                  let str = String(data: data, encoding: .utf8) else { return "[]" }
            return str
        }()

        let df = DateFormatter(); df.dateFormat = "yyyy"
        let orderNum = "ML-ORD-\(df.string(from: Date()))-\(String(format: "%04d", Int.random(in: 1000...9999)))"

        // 1. Save locally (always — source of truth for customer order history UI)
        let order = Order(
            orderNumber: orderNum,
            customerEmail: appState.currentUserEmail,
            status: .confirmed,
            orderItems: itemsJSON,
            subtotal: subtotal,
            tax: tax,
            total: total,
            shippingAddress: addrJSON,
            fulfillmentType: .standard,
            paymentMethod: selectedPayment.title
        )
        modelContext.insert(order)
        try? modelContext.save()

        // 2. Sync to Supabase so sales associates can see this purchase in client history.
        let resolvedClientId: UUID? = appState.currentUserProfile?.id ?? appState.currentClientProfile?.id
        if let clientId = resolvedClientId {
            print("[BuyNowSheetView] Starting Supabase sync for clientId: \(clientId), order: \(orderNum)")
            do {
                try await OrderService.shared.syncOrder(
                    clientId: clientId,
                    cartItems: [(
                        productId: product.id,
                        productName: product.name,
                        quantity: 1,
                        unitPrice: effectiveUnitPrice
                    )],
                    orderNumber: orderNum,
                    subtotal: subtotal,
                    taxTotal: tax,
                    grandTotal: total,
                    channel: "online"
                )
                print("[BuyNowSheetView] ✅ Supabase sync succeeded for order: \(orderNum)")
            } catch {
                // Non-fatal: local order already saved. Log but don't block the user.
                print("[BuyNowSheetView] ⚠️ Supabase sync failed (order saved locally): \(error)")
            }
        } else {
            print("[BuyNowSheetView] No client UUID in AppState — skipping Supabase sync")
        }

        // 3. Navigate to confirmation
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        placedOrder = order
        showConfirmation = true
    }
}

// MARK: - Payment enum

enum BuyNowPayment: String, CaseIterable {
    case applePay   = "Apple Pay"
    case creditCard = "Credit / Debit Card"
    case googlePay  = "Google Pay"
    case payInStore = "Pay In Store"

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .applePay:   return "Touch ID or Face ID"
        case .creditCard: return "Visa, Mastercard, Amex"
        case .googlePay:  return "Google Wallet"
        case .payInStore: return "Pay at the boutique"
        }
    }

    var icon: String {
        switch self {
        case .applePay:   return "apple.logo"
        case .creditCard: return "creditcard.fill"
        case .googlePay:  return "g.circle.fill"
        case .payInStore: return "banknote.fill"
        }
    }
}
