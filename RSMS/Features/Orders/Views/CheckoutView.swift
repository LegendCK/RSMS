//
//  CheckoutView.swift
//  RSMS
//
//  Premium multi-step checkout: Delivery (saved addresses) → Payment → Review → Confirmation.
//

import SwiftUI
import SwiftData

struct CheckoutView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCartItems: [CartItem]
    @Query private var allAddresses: [SavedAddress]
    @Query private var allProducts: [Product]
    @Query private var allCategories: [Category]
    @Query private var pricingPolicies: [PricingPolicySettings]
    @Query private var taxRules: [IndianTaxRule]
    @Query private var regionalPriceRules: [RegionalPriceRule]
    @Query private var promotionRules: [PromotionRule]
    @Query private var allInventory: [InventoryByLocation]

    @State private var currentStep = 0

    // Delivery
    @State private var selectedFulfillment: FulfillmentType = .standard
    @State private var selectedAddress:     SavedAddress?   = nil
    @State private var showAddressManager  = false
    @State private var showAddNewAddress   = false

    // Inline address fallback
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city         = ""
    @State private var addrState    = ""
    @State private var zip          = ""
    @State private var saveInlineAddressForFuture = true

    // Payment
    @State private var selectedPayment: CheckoutPayment = .applePay
    @State private var cardNumber  = ""
    @State private var cardExpiry  = ""
    @State private var cardCVV     = ""

    // BOPIS store selection
    @State private var selectedPickupStore: StoreDTO? = nil
    @State private var showStorePicker = false

    // Order
    @State private var createdOrder:      Order? = nil
    @State private var showConfirmation   = false
    @State private var isPlacing          = false

    private let steps = ["Delivery", "Payment", "Review"]

    private var cartItems: [CartItem] {
        allCartItems.filter { $0.customerEmail == appState.currentUserEmail }
    }
    private var savedAddresses: [SavedAddress] {
        allAddresses
            .filter { $0.customerEmail == appState.currentUserEmail }
            .sorted { $0.isDefault && !$1.isDefault }
    }

    private var policy: PricingPolicySettings {
        pricingPolicies.first ?? PricingPolicySettings()
    }
    private var buyerStateForTax: String {
        if selectedFulfillment == .bopis {
            return policy.businessState
        }
        if let selectedAddress {
            return selectedAddress.state
        }
        if !addrState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return addrState
        }
        return policy.businessState
    }
    private var pricing: PricingComputation {
        let lineItems: [TaxableLineItem] = cartItems.map { item in
            let goodsCategory = allProducts.first(where: { $0.id == item.productId })?.categoryName ?? "Default"
            let categoryId = allCategories.first(where: { $0.name == goodsCategory })?.id
            return TaxableLineItem(
                productId: item.productId,
                categoryId: categoryId,
                goodsCategory: goodsCategory,
                baseUnitPrice: item.unitPrice,
                quantity: item.quantity
            )
        }
        return IndianPricingEngine.calculate(
            items: lineItems,
            buyerState: buyerStateForTax,
            policy: policy,
            regionalPrices: regionalPriceRules,
            taxRules: taxRules,
            promotions: promotionRules
        )
    }


    private var merchandiseSubtotal: Double { pricing.merchandiseSubtotal }
    private var subtotal: Double { pricing.subtotal }
    private var discountTotal: Double { pricing.discountTotal }
    private var tax:      Double { pricing.taxBreakdown.totalTax }
    private var shipping: Double {
        selectedFulfillment == .bopis ? 0 : (subtotal >= policy.freeShippingThreshold ? 0 : policy.standardShippingFee)
    }
    private var total:    Double { subtotal + tax + shipping }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                stepIndicator
                    .padding(.vertical, AppSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        switch currentStep {
                        case 0: deliveryStep
                        case 1: paymentStep
                        case 2: reviewStep
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, 110)
                }

                bottomBar
            }

            // Loading overlay — shown while the order is being placed so the review
            // step (which re-renders with an empty cart after items are deleted) is hidden.
            if isPlacing {
                placingOrderOverlay
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showConfirmation) {
            if let order = createdOrder {
                OrderConfirmationView(order: order)
            }
        }
        .sheet(isPresented: $showAddressManager) {
            AddressManagerView(onSelect: { addr in selectedAddress = addr })
        }
        .sheet(isPresented: $showAddNewAddress) {
            AddressEditView()
                .onDisappear {
                    if selectedAddress == nil {
                        selectedAddress = savedAddresses.first(where: { $0.isDefault }) ?? savedAddresses.first
                    }
                }
        }
        .sheet(isPresented: $showStorePicker) {
            BOPISStorePickerSheet(selected: selectedPickupStore) { store in
                selectedPickupStore = store
            }
        }
        .onChange(of: selectedFulfillment) { _, newValue in
            if newValue == .bopis && selectedPickupStore == nil {
                showStorePicker = true
            }
        }
        .onAppear {
            if appState.currentUserRole != .customer && selectedFulfillment == .standard {
                selectedFulfillment = .shipFromStore
            }
            Task { @MainActor in
                if savedAddresses.isEmpty,
                   !appState.isGuest,
                   let clientId = appState.currentUserProfile?.id ?? appState.currentClientProfile?.id {
                    await AddressSyncService.shared.hydrateLocalAddressesIfNeeded(
                        customerEmail: appState.currentUserEmail,
                        clientId: clientId,
                        modelContext: modelContext
                    )
                }
                selectedAddress = savedAddresses.first(where: { $0.isDefault }) ?? savedAddresses.first
            }
        }
        .onChange(of: appState.shouldNavigateHome) { _, newValue in
            guard newValue else { return }
            print("[CheckoutView] shouldNavigateHome detected, resetting showConfirmation")
            showConfirmation = false
        }
        .task { await refreshPromotions() }
    }

    // MARK: - Placing Order Overlay

    private var placingOrderOverlay: some View {
        ZStack {
            AppColors.backgroundPrimary
                .opacity(0.97)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                ProgressView()
                    .tint(AppColors.accent)
                    .scaleEffect(1.6)

                VStack(spacing: AppSpacing.xs) {
                    Text("Placing Your Order")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("Please wait a moment…")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { idx in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(idx <= currentStep ? AppColors.accent : AppColors.backgroundSecondary)
                            .frame(width: 28, height: 28)
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
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Step 0: Delivery

    private var deliveryStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {

            // Fulfillment type
            sectionHeader("FULFILLMENT")
            VStack(spacing: AppSpacing.sm) {
                fulfillmentOption(
                    appState.currentUserRole == .customer ? .standard : .shipFromStore,
                    title: appState.currentUserRole == .customer ? "Standard Delivery" : "Ship From Store",
                    subtitle: subtotal >= policy.freeShippingThreshold ? "Free · 5–7 days" : "\(formatCurrency(policy.standardShippingFee)) · 5–7 days",
                    icon: "shippingbox.fill"
                )
                fulfillmentOption(.bopis,    title: "Pick Up In Store",     subtitle: "Free · Ready within 2 hours", icon: "building.2.fill")
            }

            // Address section (delivery only)
            if selectedFulfillment == .standard || selectedFulfillment == .shipFromStore {
                sectionHeader("SHIPPING ADDRESS")

                if savedAddresses.isEmpty {
                    // Inline form
                    LuxuryCardView(useGlass: false, cornerRadius: AppSpacing.radiusMedium) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            LuxuryTextField(placeholder: "Address Line 1*", text: $addressLine1)
                            LuxuryTextField(placeholder: "Address Line 2 (optional)", text: $addressLine2)
                            HStack(spacing: AppSpacing.sm) {
                                LuxuryTextField(placeholder: "City*", text: $city)
                                LuxuryTextField(placeholder: "State*", text: $addrState).frame(maxWidth: 96)
                            }
                            LuxuryTextField(placeholder: "PIN*", text: $zip).keyboardType(.numberPad)

                            saveAddressCheckboxRow
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                } else {
                    // Saved addresses
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(savedAddresses.prefix(3)) { addr in
                            checkoutAddressRow(addr)
                        }
                        HStack(spacing: AppSpacing.lg) {
                            Button("Manage") { showAddressManager = true }
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.accent)
                            Button("+ Add New") { showAddNewAddress = true }
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }

            if selectedFulfillment == .bopis {
                LuxuryCardView {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accent)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            if let store = selectedPickupStore {
                                Text(store.name)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text("\(store.address ?? ""), \(store.city ?? ""), \(store.country)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(AppColors.success)
                                    Text("Estimated Pickup: \(estimatedPickupTimeString)")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.success)
                                }
                            } else {
                                Text("Select a boutique")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text("Tap to choose your pickup location")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }
                        Spacer()
                        Button {
                            showStorePicker = true
                        } label: {
                            Text(selectedPickupStore == nil ? "Select" : "Change")
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                }
            }
        }
    }

    private var saveAddressCheckboxRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                saveInlineAddressForFuture.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: saveInlineAddressForFuture ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(saveInlineAddressForFuture ? AppColors.accent : AppColors.neutral600)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Save this address for future orders")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("You can edit or remove it anytime")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.xs)
    }

    private func fulfillmentOption(_ type: FulfillmentType, title: String, subtitle: String, icon: String) -> some View {
        Button { selectedFulfillment = type } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedFulfillment == type ? AppColors.accent.opacity(0.1) : AppColors.backgroundSecondary)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(selectedFulfillment == type ? AppColors.accent : AppColors.neutral600)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Image(systemName: selectedFulfillment == type ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedFulfillment == type ? AppColors.accent : AppColors.neutral600)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(selectedFulfillment == type ? AppColors.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func checkoutAddressRow(_ addr: SavedAddress) -> some View {
        let selected = selectedAddress?.id == addr.id
        return Button(action: { withAnimation { selectedAddress = addr } }) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? AppColors.accent : AppColors.neutral600)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(addr.label)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        if addr.isDefault {
                            Text("DEFAULT")
                                .font(AppTypography.pico).tracking(1)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
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
                    .stroke(selected ? AppColors.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 1: Payment

    private var paymentStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            sectionHeader("PAYMENT METHOD")

            VStack(spacing: AppSpacing.sm) {
                ForEach(CheckoutPayment.allCases, id: \.self) { method in
                    checkoutPaymentRow(method)
                }
            }

            if selectedPayment == .creditCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionHeader("CARD DETAILS")
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
        }
    }

    private func checkoutPaymentRow(_ method: CheckoutPayment) -> some View {
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

    // MARK: - Step 2: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            sectionHeader("ORDER REVIEW")

            // Items
            VStack(spacing: AppSpacing.sm) {
                ForEach(cartItems) { item in
                    HStack(spacing: AppSpacing.md) {
                        ProductArtworkView(
                            imageSource: item.productImageName,
                            fallbackSymbol: "bag.fill",
                            cornerRadius: AppSpacing.radiusSmall
                        )
                        .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.productBrand.uppercased())
                                .font(AppTypography.overline).tracking(1)
                                .foregroundColor(AppColors.accent)
                            Text(item.productName)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .lineLimit(2)
                            Text("Qty: \(item.quantity)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        Spacer()
                        Text(formatCurrency(lineTotal(for: item)))
                            .font(AppTypography.priceSmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }

            GoldDivider()

            // Delivery summary
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionHeader("DELIVERY")
                if selectedFulfillment == .bopis {
                Text("Pick Up In Store — \(selectedPickupStore?.name ?? "Boutique")")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    if let store = selectedPickupStore {
                        Text("\(store.address ?? ""), \(store.city ?? "")")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.success)
                        Text("Estimated Pickup: \(estimatedPickupTimeString)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.success)
                    }
                } else if let addr = selectedAddress {
                    Text("Standard Delivery · \(addr.label)")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(addr.fullAddress)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineSpacing(3)
                } else if !addressLine1.isEmpty {
                    Text("Standard Delivery")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("\(addressLine1)\(addressLine2.isEmpty ? "" : ", \(addressLine2)")\n\(city), \(addrState) \(zip)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            GoldDivider()

            // Payment summary
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionHeader("PAYMENT")
                HStack(spacing: 8) {
                    Image(systemName: selectedPayment.icon)
                        .foregroundColor(AppColors.accent)
                    Text(selectedPayment.title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }

            GoldDivider()

            // Price breakdown
            VStack(spacing: AppSpacing.sm) {
                summaryRow("Items", value: formatCurrency(merchandiseSubtotal))
                if discountTotal > 0 {
                    summaryRow("Offer", value: "-\(formatCurrency(discountTotal))")
                }
                summaryRow("Subtotal", value: formatCurrency(subtotal))
                summaryRow("CGST", value: formatCurrency(pricing.taxBreakdown.cgst))
                summaryRow("SGST", value: formatCurrency(pricing.taxBreakdown.sgst))
                if pricing.taxBreakdown.igst > 0 {
                    summaryRow("IGST", value: formatCurrency(pricing.taxBreakdown.igst))
                }
                if pricing.taxBreakdown.cess > 0 {
                    summaryRow("Cess", value: formatCurrency(pricing.taxBreakdown.cess))
                }
                if pricing.taxBreakdown.additionalLevy > 0 {
                    summaryRow("Other Tax", value: formatCurrency(pricing.taxBreakdown.additionalLevy))
                }
                summaryRow("Shipping", value: shipping == 0 ? "Free" : formatCurrency(shipping))
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
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.md) {
            if currentStep > 0 {
                SecondaryButton(title: "Back") {
                    withAnimation(.spring(response: 0.3)) { currentStep -= 1 }
                }
                .frame(width: 90)
            }

            if currentStep < steps.count - 1 {
                PrimaryButton(title: "Continue") {
                    guard canContinue else { return }
                    if currentStep == 0 { persistInlineAddressIfNeeded() }
                    withAnimation(.spring(response: 0.3)) { currentStep += 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.55)
            } else {
                Button(action: placeOrder) {
                    HStack(spacing: 8) {
                        if isPlacing {
                            ProgressView().tint(AppColors.textPrimaryLight).scaleEffect(0.8)
                        } else {
                            Image(systemName: "lock.fill").font(.system(size: 14))
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
                .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
        )
    }

    // MARK: - Helpers

    /// Calculates a human-readable estimated pickup time (now + 2 hours).
    private var estimatedPickupTimeString: String {
        let pickupDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "~\(formatter.string(from: pickupDate))"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
    }

    private func summaryRow(_ label: String, value: String) -> some View {
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

    private func lineTotal(for item: CartItem) -> Double {
        pricing.lineItems.first(where: { $0.productId == item.productId })?.taxableValue ?? item.lineTotal
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0:
            if selectedFulfillment == .bopis { return selectedPickupStore != nil }
            if selectedAddress != nil { return true }
            if !savedAddresses.isEmpty { return false }
            return isInlineAddressComplete
        case 1:
            if selectedPayment == .creditCard {
                return !cardNumber.isEmpty && !cardExpiry.isEmpty && !cardCVV.isEmpty
            }
            return true
        default:
            return true
        }
    }

    private var isInlineAddressComplete: Bool {
        !addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !addrState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !zip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func persistInlineAddressIfNeeded() {
        guard (selectedFulfillment == .standard || selectedFulfillment == .shipFromStore), selectedAddress == nil, saveInlineAddressForFuture, isInlineAddressComplete else { return }

        let trimmedLine1 = addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedState = addrState.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedZip = zip.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = savedAddresses.first(where: {
            $0.line1.caseInsensitiveCompare(trimmedLine1) == .orderedSame &&
            $0.city.caseInsensitiveCompare(trimmedCity) == .orderedSame &&
            $0.state.caseInsensitiveCompare(trimmedState) == .orderedSame &&
            $0.zip.caseInsensitiveCompare(trimmedZip) == .orderedSame
        }) {
            selectedAddress = existing
            return
        }

        let newAddress = SavedAddress(
            customerEmail: appState.currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            label: savedAddresses.isEmpty ? "Home" : "Other",
            line1: trimmedLine1,
            line2: addressLine2.trimmingCharacters(in: .whitespacesAndNewlines),
            city: trimmedCity,
            state: trimmedState,
            zip: trimmedZip,
            country: "IN",
            isDefault: savedAddresses.isEmpty
        )
        modelContext.insert(newAddress)
        try? modelContext.save()
        selectedAddress = newAddress
    }

    private func refreshPromotions() async {
        try? await PromotionSyncService.shared.refreshLocalPromotions(modelContext: modelContext)
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle  = .currency
        f.currencyCode = policy.currencyCode
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
        persistInlineAddressIfNeeded()

        // Snapshot cart items AND prices BEFORE deleting from context.
        // The computed properties subtotal/tax/shipping/total all read from `cartItems`,
        // so they return 0 once the items are deleted — causing incorrect totals in Supabase.
        let snapshot: [(productId: UUID, productName: String, quantity: Int, unitPrice: Double)] =
            cartItems.map { item in
                let effectiveUnitPrice = pricing.lineItems.first(where: { $0.productId == item.productId })?.unitPrice ?? item.unitPrice
                return (item.productId, item.productName, item.quantity, effectiveUnitPrice)
            }
        let snapshotSubtotal = subtotal
        let snapshotDiscount = discountTotal
        let snapshotTax      = tax
        let snapshotTotal    = total

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
            if (selectedFulfillment == .standard || selectedFulfillment == .shipFromStore) && !addressLine1.isEmpty {
                let d: [String: String] = [
                    "line1": addressLine1, "line2": addressLine2,
                    "city": city, "state": addrState, "zip": zip, "country": "IN"
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: d),
                      let s = String(data: data, encoding: .utf8) else { return "{}" }
                return s
            }
            return "{}"
        }()

        let itemsArr: [[String: Any]] = cartItems.map { item in
            let effectiveUnitPrice = pricing.lineItems.first(where: { $0.productId == item.productId })?.unitPrice ?? item.unitPrice
            return ["name": item.productName, "brand": item.productBrand,
                    "qty": item.quantity, "price": effectiveUnitPrice, "image": item.productImageName]
        }
        let itemsJSON: String = {
            guard let data = try? JSONSerialization.data(withJSONObject: itemsArr),
                  let s = String(data: data, encoding: .utf8) else { return "[]" }
            return s
        }()

        let df = DateFormatter(); df.dateFormat = "yyyy"
        let num = "ML-ORD-\(df.string(from: Date()))-\(String(format: "%04d", Int.random(in: 1000...9999)))"

        // 1. Save locally (always — source of truth for the customer order history UI)
        let order = Order(
            orderNumber: num,
            customerEmail: appState.currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            status: .confirmed,
            orderItems: itemsJSON,
            subtotal: snapshotSubtotal,
            tax: snapshotTax,
            discount: snapshotDiscount,
            total: snapshotTotal,
            shippingAddress: addrJSON,
            fulfillmentType: selectedFulfillment,
            paymentMethod: selectedPayment.title
        )
        // Set boutique ID for BOPIS orders so the manager dashboard picks them up
        if selectedFulfillment == .bopis, let store = selectedPickupStore {
            order.boutiqueId = store.code ?? ""
        }
        modelContext.insert(order)

        // Decrement local product stock counts and per-location inventory
        for item in cartItems {
            // Resolve a fulfillment store only from explicit selections; do not fall back to an arbitrary store.
            let resolvedStoreId = selectedPickupStore?.id ?? appState.currentStoreId

            if let product = allProducts.first(where: { $0.id == item.productId }) {
                product.stockCount = max(0, product.stockCount - item.quantity)

                // Update InventoryByLocation for real-time per-store visibility
                if let storeId = resolvedStoreId {
                    if let invRow = allInventory.first(where: { $0.locationId == storeId && $0.productId == item.productId }) {
                        invRow.quantity = max(0, invRow.quantity - item.quantity)
                        invRow.updatedAt = Date()
                        
                        // Force flush this row to Supabase immediately so the next sync doesn't overwrite it
                        let snapshotRow = invRow
                        Task { try? await InventorySyncService.shared.upsertInventory(snapshotRow) }
                    } else {
                        let newRow = InventoryByLocation(
                            locationId: storeId,
                            productId: item.productId,
                            sku: product.sku.isEmpty ? product.id.uuidString : product.sku,
                            productName: product.name,
                            categoryName: product.categoryName,
                            quantity: 0,
                            reorderPoint: 2,
                            updatedAt: Date()
                        )
                        modelContext.insert(newRow)
                        
                        let snapshotRow = newRow
                        Task { try? await InventorySyncService.shared.upsertInventory(snapshotRow) }
                    }
                }
            }
            modelContext.delete(item)
        }
        try? modelContext.save()

        // Notify dashboards that inventory changed
        NotificationCenter.default.post(name: .inventoryStockUpdated, object: nil)

        // 2. Sync to Supabase so sales associates can view purchase history.
        //    Try currentUserProfile.id first (set by Supabase login), fall back to
        //    currentClientProfile.id (set when profile was updated mid-session).
        let resolvedClientId: UUID? = appState.currentUserProfile?.id ?? appState.currentClientProfile?.id

        if let clientId = resolvedClientId {
            let channel: String
            switch selectedFulfillment {
            case .bopis:         channel = "bopis"
            case .shipFromStore: channel = "ship_from_store"
            case .inStore:       channel = "in_store"
            default:             channel = "online"
            }
            // Determine the nearest store for online delivery so the IC can fulfil it.
            // BOPIS already uses the pickup store; for online we resolve by address.
            let nearestStoreId: UUID?
            let deliveryCity: String?
            let deliveryState: String?
            if channel == "online" || channel == "ship_from_store" {
                let cityValue  = selectedAddress?.city  ?? city
                let stateValue = selectedAddress?.state ?? addrState
                deliveryCity = cityValue
                deliveryState = stateValue
                nearestStoreId = try? await StoreAssignmentService.shared.findNearestStore(
                    city: cityValue,
                    state: stateValue
                )
            } else {
                nearestStoreId = selectedPickupStore?.id
                deliveryCity = nil
                deliveryState = nil
            }

            print("[CheckoutView] Starting Supabase sync for clientId: \(clientId), storeId: \(nearestStoreId?.uuidString ?? "none")")
            do {
                try await OrderService.shared.syncOrder(
                    clientId: clientId,
                    cartItems: snapshot,
                    orderNumber: num,
                    subtotal: snapshotSubtotal,
                    discountTotal: snapshotDiscount,
                    taxTotal: snapshotTax,
                    grandTotal: snapshotTotal,
                    channel: channel,
                    storeId: nearestStoreId,
                    deliveryCity: deliveryCity,
                    deliveryState: deliveryState
                )
                print("[CheckoutView] Supabase sync succeeded for order: \(num)")
            } catch {
                // Non-fatal: local order already saved; associate view will be missing this
                // order until next successful sync or manual Supabase insert.
                print("[CheckoutView] Supabase sync failed (order still saved locally): \(error)")
            }
        } else {
            print("[CheckoutView] No client UUID in AppState — skipping Supabase sync (guest/unauthenticated)")
            print("[CheckoutView] currentUserProfile: \(String(describing: appState.currentUserProfile))")
            print("[CheckoutView] currentClientProfile: \(String(describing: appState.currentClientProfile))")
        }

        // 3. Navigate to confirmation
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        createdOrder     = order
        isPlacing        = false
        showConfirmation = true
    }
}

// MARK: - BOPIS Store Picker Sheet

struct BOPISStorePickerSheet: View {
    let selected: StoreDTO?
    let onSelect: (StoreDTO) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stores: [StoreDTO] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading boutiques…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(AppColors.warning)
                        Text(err)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Retry") { Task { await loadStores() } }
                            .foregroundColor(AppColors.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if stores.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(AppColors.neutral300)
                        Text("No boutiques available for pickup")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(stores) { store in
                        Button {
                            onSelect(store)
                            dismiss()
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.accent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.name)
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Text([store.address, store.city].compactMap { $0 }.joined(separator: ", "))
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                Spacer()
                                if selected?.id == store.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .task { await loadStores() }
        }
    }

    private func loadStores() async {
        isLoading = true
        loadError = nil
        do {
            stores = try await StoreSyncService.shared.fetchActiveBoutiques()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Payment enum

enum CheckoutPayment: String, CaseIterable {
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
