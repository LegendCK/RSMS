//
//  CheckoutView.swift
//  infosys2
//
//  Multi-step checkout: Fulfillment → Payment → Review → Confirmation.
//

import SwiftUI
import SwiftData

struct CheckoutView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCartItems: [CartItem]

    @State private var currentStep = 0
    @State private var selectedFulfillment: FulfillmentType = .standard
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var selectedPayment = "Credit Card"
    @State private var createdOrder: Order?
    @State private var showConfirmation = false

    private let steps = ["Delivery", "Payment", "Review"]
    private let paymentOptions = ["Credit Card", "Apple Pay", "Pay In Store"]

    private var cartItems: [CartItem] {
        allCartItems.filter { $0.customerEmail == appState.currentUserEmail }
    }

    private var subtotal: Double { cartItems.reduce(0) { $0 + $1.lineTotal } }
    private var tax: Double { subtotal * 0.08 }
    private var total: Double { subtotal + tax }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.vertical, AppSpacing.md)

                // Step content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        switch currentStep {
                        case 0: fulfillmentStep
                        case 1: paymentStep
                        case 2: reviewStep
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, 100)
                }

                // Navigation buttons
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
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(0..<steps.count, id: \.self) { index in
                HStack(spacing: AppSpacing.xxs) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? AppColors.accent : AppColors.neutral700)
                            .frame(width: 28, height: 28)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(AppTypography.trendArrow)
                                .foregroundColor(AppColors.primary)
                        } else {
                            Text("\(index + 1)")
                                .font(AppTypography.caption)
                                .foregroundColor(index <= currentStep ? AppColors.primary : AppColors.textSecondaryDark)
                        }
                    }

                    Text(steps[index])
                        .font(AppTypography.caption)
                        .foregroundColor(index <= currentStep ? AppColors.accent : AppColors.textSecondaryDark)
                }

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? AppColors.accent : AppColors.neutral700)
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Step 1: Fulfillment

    private var fulfillmentStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("DELIVERY METHOD")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            // Fulfillment options
            fulfillmentOption(type: .standard, title: "Standard Delivery", subtitle: "5-7 business days", icon: "shippingbox.fill")
            fulfillmentOption(type: .bopis, title: "Pick Up In Store", subtitle: "Ready within 2 hours", icon: "building.2.fill")

            // Address form (for delivery)
            if selectedFulfillment == .standard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("SHIPPING ADDRESS")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                        .padding(.top, AppSpacing.md)

                    LuxuryTextField(placeholder: "Address Line 1", text: $addressLine1)
                    LuxuryTextField(placeholder: "Address Line 2 (Optional)", text: $addressLine2)

                    HStack(spacing: AppSpacing.sm) {
                        LuxuryTextField(placeholder: "City", text: $city)
                        LuxuryTextField(placeholder: "State", text: $state)
                            .frame(width: 80)
                    }
                    LuxuryTextField(placeholder: "ZIP Code", text: $zip)
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
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.cardPadding)
                }
            }
        }
    }

    private func fulfillmentOption(type: FulfillmentType, title: String, subtitle: String, icon: String) -> some View {
        Button {
            selectedFulfillment = type
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(selectedFulfillment == type ? AppColors.accent : AppColors.neutral600)

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
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(selectedFulfillment == type ? AppColors.accent : Color.clear, lineWidth: 1)
            )
            .cornerRadius(AppSpacing.radiusMedium)
        }
    }

    // MARK: - Step 2: Payment

    private var paymentStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("PAYMENT METHOD")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            ForEach(paymentOptions, id: \.self) { option in
                Button {
                    selectedPayment = option
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: paymentIcon(for: option))
                            .font(.title2)
                            .foregroundColor(selectedPayment == option ? AppColors.accent : AppColors.neutral600)

                        Text(option)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)

                        Spacer()

                        Image(systemName: selectedPayment == option ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedPayment == option ? AppColors.accent : AppColors.neutral600)
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(selectedPayment == option ? AppColors.accent : Color.clear, lineWidth: 1)
                    )
                    .cornerRadius(AppSpacing.radiusMedium)
                }
            }

            if selectedPayment == "Credit Card" {
                LuxuryCardView {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(AppColors.accent)
                        Text("Visa ending in 4242")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Spacer()
                    }
                    .padding(AppSpacing.cardPadding)
                }
            }
        }
    }

    private func paymentIcon(for option: String) -> String {
        switch option {
        case "Credit Card": return "creditcard.fill"
        case "Apple Pay": return "apple.logo"
        case "Pay In Store": return "banknote.fill"
        default: return "creditcard"
        }
    }

    // MARK: - Step 3: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("REVIEW YOUR ORDER")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            // Items
            VStack(spacing: AppSpacing.sm) {
                ForEach(cartItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.productName)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
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

            // Delivery info
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("DELIVERY")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)

                Text(selectedFulfillment == .bopis ? "Pick Up In Store — Maison Luxe Flagship" : "Standard Delivery")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)

                if selectedFulfillment == .standard && !addressLine1.isEmpty {
                    Text("\(addressLine1)\(addressLine2.isEmpty ? "" : ", \(addressLine2)")")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("\(city), \(state) \(zip)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            GoldDivider()

            // Payment
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("PAYMENT")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)

                Text(selectedPayment)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
            }

            GoldDivider()

            // Totals
            VStack(spacing: AppSpacing.sm) {
                summaryRow(label: "Subtotal", value: formatCurrency(subtotal))
                summaryRow(label: "Tax (8%)", value: formatCurrency(tax))
                summaryRow(label: "Shipping", value: selectedFulfillment == .bopis ? "Free" : "Free")

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

    private func summaryRow(label: String, value: String) -> some View {
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
        HStack(spacing: AppSpacing.md) {
            if currentStep > 0 {
                SecondaryButton(title: "Back") {
                    withAnimation { currentStep -= 1 }
                }
            }

            if currentStep < steps.count - 1 {
                PrimaryButton(title: "Continue") {
                    withAnimation { currentStep += 1 }
                }
            } else {
                PrimaryButton(title: "Place Order") {
                    placeOrder()
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.md)
        .background(
            AppColors.backgroundPrimary
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }

    // MARK: - Place Order

    private func placeOrder() {
        // Build address JSON
        let addressJSON: String
        if selectedFulfillment == .standard {
            let addr: [String: String] = [
                "line1": addressLine1,
                "line2": addressLine2,
                "city": city,
                "state": state,
                "zip": zip,
                "country": "US"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: addr),
               let str = String(data: data, encoding: .utf8) {
                addressJSON = str
            } else {
                addressJSON = "{}"
            }
        } else {
            addressJSON = "{}"
        }

        // Build order items JSON
        let itemsArray: [[String: Any]] = cartItems.map { item in
            [
                "name": item.productName,
                "brand": item.productBrand,
                "qty": item.quantity,
                "price": item.unitPrice,
                "image": item.productImageName
            ]
        }
        let itemsJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: itemsArray),
           let str = String(data: data, encoding: .utf8) {
            itemsJSON = str
        } else {
            itemsJSON = "[]"
        }

        // Generate order number
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        let year = dateFormatter.string(from: Date())
        let random = String(format: "%04d", Int.random(in: 1000...9999))
        let orderNumber = "ML-ORD-\(year)-\(random)"

        let order = Order(
            orderNumber: orderNumber,
            customerEmail: appState.currentUserEmail,
            status: .confirmed,
            orderItems: itemsJSON,
            subtotal: subtotal,
            tax: tax,
            total: total,
            shippingAddress: addressJSON,
            fulfillmentType: selectedFulfillment,
            paymentMethod: selectedPayment
        )
        modelContext.insert(order)

        // Clear cart
        for item in cartItems {
            modelContext.delete(item)
        }
        try? modelContext.save()

        createdOrder = order
        showConfirmation = true
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
