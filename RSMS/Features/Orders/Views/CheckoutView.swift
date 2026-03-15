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

    // Payment
    @State private var selectedPayment: CheckoutPayment = .applePay
    @State private var cardNumber  = ""
    @State private var cardExpiry  = ""
    @State private var cardCVV     = ""

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

    private var subtotal: Double { cartItems.reduce(0) { $0 + $1.lineTotal } }
    private var tax:      Double { subtotal * 0.08 }
    private var shipping: Double { selectedFulfillment == .bopis ? 0 : (subtotal > 500 ? 0 : 25) }
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
        .onAppear {
            selectedAddress = savedAddresses.first(where: { $0.isDefault }) ?? savedAddresses.first
        }
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
                fulfillmentOption(.standard, title: "Standard Delivery",   subtitle: subtotal > 500 ? "Free · 5–7 days" : "$25 · 5–7 days", icon: "shippingbox.fill")
                fulfillmentOption(.bopis,    title: "Pick Up In Store",     subtitle: "Free · Ready in 2 hours", icon: "building.2.fill")
            }

            // Address section (delivery only)
            if selectedFulfillment == .standard {
                sectionHeader("SHIPPING ADDRESS")

                if savedAddresses.isEmpty {
                    // Inline form
                    VStack(spacing: AppSpacing.sm) {
                        LuxuryTextField(placeholder: "Address Line 1*", text: $addressLine1)
                        LuxuryTextField(placeholder: "Address Line 2 (optional)", text: $addressLine2)
                        HStack(spacing: AppSpacing.sm) {
                            LuxuryTextField(placeholder: "City*", text: $city)
                            LuxuryTextField(placeholder: "State*", text: $addrState).frame(maxWidth: 90)
                        }
                        LuxuryTextField(placeholder: "ZIP*", text: $zip).keyboardType(.numberPad)

                        Button("Save this address") { showAddNewAddress = true }
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity, alignment: .trailing)
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
                            Text("Maison Luxe Flagship")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text("123 Luxury Avenue, New York, NY 10001")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                            Text("Ready within 2 hours")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.success)
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.cardPadding)
                }
            }
        }
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
                        Text(item.formattedLineTotal)
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
                    Text("Pick Up In Store — Maison Luxe Flagship")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
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
                summaryRow("Subtotal",   value: formatCurrency(subtotal))
                summaryRow("Tax (8%)",   value: formatCurrency(tax))
                summaryRow("Shipping",   value: shipping == 0 ? "Free" : formatCurrency(shipping))
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
                    withAnimation(.spring(response: 0.3)) { currentStep += 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
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

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle  = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }

    // MARK: - Place Order

    private func placeOrder() {
        isPlacing = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

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
            if selectedFulfillment == .standard && !addressLine1.isEmpty {
                let d: [String: String] = [
                    "line1": addressLine1, "line2": addressLine2,
                    "city": city, "state": addrState, "zip": zip, "country": "US"
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: d),
                      let s = String(data: data, encoding: .utf8) else { return "{}" }
                return s
            }
            return "{}"
        }()

        let itemsArr: [[String: Any]] = cartItems.map { item in
            ["name": item.productName, "brand": item.productBrand,
             "qty": item.quantity, "price": item.unitPrice, "image": item.productImageName]
        }
        let itemsJSON: String = {
            guard let data = try? JSONSerialization.data(withJSONObject: itemsArr),
                  let s = String(data: data, encoding: .utf8) else { return "[]" }
            return s
        }()

        let df = DateFormatter(); df.dateFormat = "yyyy"
        let num = "ML-ORD-\(df.string(from: Date()))-\(String(format: "%04d", Int.random(in: 1000...9999)))"

        let order = Order(
            orderNumber: num,
            customerEmail: appState.currentUserEmail,
            status: .confirmed,
            orderItems: itemsJSON,
            subtotal: subtotal,
            tax: tax,
            total: total,
            shippingAddress: addrJSON,
            fulfillmentType: selectedFulfillment,
            paymentMethod: selectedPayment.title
        )
        modelContext.insert(order)
        for item in cartItems { modelContext.delete(item) }
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            createdOrder    = order
            isPlacing       = false
            showConfirmation = true
        }
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
