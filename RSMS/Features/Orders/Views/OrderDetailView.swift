//
//  OrderDetailView.swift
//  infosys2
//
//  Order detail with status timeline, items, and financial summary.
//

import SwiftUI
import SwiftData

struct OrderDetailView: View {
    @Environment(AppState.self) private var appState
    @Query private var stores: [StoreLocation]
    @Query private var pricingPolicies: [PricingPolicySettings]
    let order: Order
    @State private var showInvoiceSheet = false
    @State private var shareFile: ShareFile?
    @State private var invoiceError = ""
    @State private var showInvoiceError = false

    private let statusFlow: [OrderStatus] = [
        .pending, .confirmed, .processing, .shipped, .delivered
    ]

    private let bopisStatusFlow: [OrderStatus] = [
        .pending, .confirmed, .processing, .readyForPickup, .completed
    ]

    private var activeFlow: [OrderStatus] {
        order.fulfillmentType == .bopis ? bopisStatusFlow : statusFlow
    }

    private var currentStepIndex: Int {
        activeFlow.firstIndex(of: order.status) ?? 0
    }

    private var policy: PricingPolicySettings {
        pricingPolicies.first ?? PricingPolicySettings()
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    // Order header
                    orderHeader

                    // Status timeline
                    statusTimeline
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Order items
                    orderItemsSection
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Financial summary
                    financialSummary
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Fulfillment info
                    fulfillmentSection
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Payment info
                    paymentSection
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Invoice actions
                    invoiceSection
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    Spacer().frame(height: AppSpacing.xxxl)
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInvoiceSheet = true
                } label: {
                    Image(systemName: "doc.text")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showInvoiceSheet) {
            InvoiceDetailSheetView(invoice: invoiceSnapshot, onDownload: downloadInvoice)
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .alert("Invoice Error", isPresented: $showInvoiceError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(invoiceError)
        }
    }

    // MARK: - Order Header

    private var orderHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(order.orderNumber)
                .font(AppTypography.heading2)
                .foregroundColor(AppColors.textPrimaryDark)

            Text("Placed on \(formattedDate(order.createdAt))")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)

            // Large status badge
            Text(order.status.rawValue.uppercased())
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(statusColor(order.status))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(statusColor(order.status).opacity(0.15))
                .cornerRadius(AppSpacing.radiusSmall)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Status Timeline

    private var statusTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ORDER STATUS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.bottom, AppSpacing.md)

            ForEach(Array(activeFlow.enumerated()), id: \.offset) { index, status in
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    // Timeline dot and line
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(index <= currentStepIndex ? AppColors.accent : AppColors.neutral700)
                                .frame(width: 24, height: 24)

                            if index < currentStepIndex {
                                Image(systemName: "checkmark")
                                    .font(AppTypography.trendBadge)
                                    .foregroundColor(AppColors.primary)
                            } else if index == currentStepIndex {
                                Circle()
                                    .fill(AppColors.primary)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        if index < activeFlow.count - 1 {
                            Rectangle()
                                .fill(index < currentStepIndex ? AppColors.accent : AppColors.neutral700)
                                .frame(width: 2, height: 40)
                        }
                    }

                    // Status label
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.rawValue)
                            .font(index == currentStepIndex ? AppTypography.label : AppTypography.bodyMedium)
                            .foregroundColor(index <= currentStepIndex ? AppColors.textPrimaryDark : AppColors.textSecondaryDark)

                        if index == currentStepIndex {
                            Text(statusDescription(status))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.top, 2)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Order Items

    private var orderItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("ITEMS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            ForEach(parsedItems) { item in
                HStack(spacing: AppSpacing.md) {
                    ProductArtworkView(
                        imageSource: item.image,
                        fallbackSymbol: "bag.fill",
                        cornerRadius: AppSpacing.radiusSmall
                    )
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.brand.uppercased())
                            .font(AppTypography.overline)
                            .tracking(1)
                            .foregroundColor(AppColors.accent)

                        Text(item.name)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .lineLimit(1)

                        Text("Qty: \(item.qty)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }

                    Spacer()

                    Text(formatCurrency(item.price * Double(item.qty)))
                        .font(AppTypography.priceSmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }

    // MARK: - Financial Summary

    private var financialSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("SUMMARY")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            summaryRow(label: "Subtotal", value: formatCurrency(order.subtotal))
            summaryRow(label: "Tax", value: formatCurrency(order.tax))

            if order.discount > 0 {
                summaryRow(label: "Discount", value: "-\(formatCurrency(order.discount))")
            }

            summaryRow(label: "Shipping", value: "Free")

            GoldDivider()

            HStack {
                Text("Total")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text(order.formattedTotal)
                    .font(AppTypography.priceDisplay)
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: - Fulfillment

    private var fulfillmentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("DELIVERY")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: order.fulfillmentType == .bopis ? "building.2.fill" : "shippingbox.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.accent)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(order.fulfillmentType.rawValue)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)

                    if order.fulfillmentType == .bopis {
                        Text("Maison Luxe Flagship")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text("123 Luxury Avenue, New York, NY 10001")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    } else {
                        Text(parsedAddress)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PAYMENT")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: paymentIcon)
                    .font(.title2)
                    .foregroundColor(AppColors.accent)

                Text(order.paymentMethod)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)

                Spacer()
            }
        }
    }

    // MARK: - Invoice

    private var invoiceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("INVOICE")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            Text("View a detailed tax invoice or download PDF for records.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            HStack(spacing: AppSpacing.sm) {
                SecondaryButton(title: "View Invoice") {
                    showInvoiceSheet = true
                }
                Button(action: downloadInvoice) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                        Text("Download PDF")
                            .font(AppTypography.buttonPrimary)
                    }
                    .foregroundColor(AppColors.textPrimaryLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.touchTarget)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.radiusMedium)
                }
            }
        }
    }

    // MARK: - Data Parsing

    private struct ParsedItem: Identifiable {
        let id: String
        let name: String
        let brand: String
        let qty: Int
        let price: Double
        let image: String
    }

    private var parsedItems: [ParsedItem] {
        guard let data = order.orderItems.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return items.enumerated().map { offset, dict in
            let name = dict["name"] as? String ?? "Product"
            let qty = dict["qty"] as? Int ?? 1
            let price = dict["price"] as? Double ?? 0
            return ParsedItem(
                id: "\(offset)-\(name)-\(qty)-\(price)",
                name: name,
                brand: dict["brand"] as? String ?? "Maison Luxe",
                qty: qty,
                price: price,
                image: dict["image"] as? String ?? "bag.fill"
            )
        }
    }

    private var parsedAddressDictionary: [String: String] {
        guard let data = order.shippingAddress.data(using: .utf8),
              let addr = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return addr
    }

    private var parsedAddress: String {
        let addr = parsedAddressDictionary
        let line1 = addr["line1"] ?? ""
        let city = addr["city"] ?? ""
        let state = addr["state"] ?? ""
        let zip = addr["zip"] ?? ""
        if line1.isEmpty { return "Address on file" }
        return "\(line1), \(city), \(state) \(zip)"
    }

    private var invoiceSnapshot: InvoiceSnapshot {
        let buyerState = parsedAddressDictionary["state"] ?? policy.businessState
        let intraState = IndianPricingEngine.normalizeState(buyerState) == IndianPricingEngine.normalizeState(policy.businessState)
        let cgst = intraState ? order.tax / 2 : 0
        let sgst = intraState ? order.tax / 2 : 0
        let igst = intraState ? 0 : order.tax
        let customerName = resolvedCustomerName
        let storeName = resolvedStoreName
        let storeAddress = resolvedStoreAddress
        let invoiceItems = parsedItems.map {
            InvoiceLineItem(
                name: $0.name,
                brand: $0.brand,
                quantity: $0.qty,
                unitPrice: $0.price
            )
        }

        return InvoiceSnapshot(
            invoiceNumber: "INV-\(order.orderNumber)",
            orderNumber: order.orderNumber,
            issuedAt: order.createdAt,
            customerName: customerName,
            customerEmail: order.customerEmail,
            storeName: storeName,
            storeAddress: storeAddress,
            shippingAddress: parsedAddress,
            fulfillmentLabel: order.fulfillmentType.rawValue,
            paymentMethod: order.paymentMethod,
            currencyCode: "INR",
            items: invoiceItems,
            subtotal: order.subtotal,
            taxBreakdown: InvoiceTaxBreakdown(cgst: cgst, sgst: sgst, igst: igst, cess: 0, other: 0),
            total: order.total
        )
    }

    private var resolvedStoreName: String {
        if let matched = matchedStore {
            return matched.name
        }
        return "Maison Luxe India"
    }

    private var resolvedStoreAddress: String {
        if let matched = matchedStore {
            return "\(matched.addressLine1), \(matched.city), \(matched.stateProvince) \(matched.postalCode), \(matched.country)"
        }
        return "Mumbai, Maharashtra, India"
    }

    private var matchedStore: StoreLocation? {
        guard !order.boutiqueId.isEmpty else { return nil }
        return stores.first {
            $0.code.caseInsensitiveCompare(order.boutiqueId) == .orderedSame ||
            $0.name.caseInsensitiveCompare(order.boutiqueId) == .orderedSame
        }
    }

    private var resolvedCustomerName: String {
        if order.customerEmail == appState.currentUserEmail, !appState.currentUserName.isEmpty {
            return appState.currentUserName
        }
        let localPart = order.customerEmail.split(separator: "@").first.map(String.init) ?? "Customer"
        let parts = localPart.split(separator: ".").map { $0.capitalized }
        return parts.isEmpty ? "Customer" : parts.joined(separator: " ")
    }

    private var paymentIcon: String {
        switch order.paymentMethod {
        case "Credit Card": return "creditcard.fill"
        case "Apple Pay": return "apple.logo"
        case "Pay In Store": return "banknote.fill"
        default: return "creditcard"
        }
    }

    // MARK: - Helpers

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

    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .pending: return AppColors.neutral600
        case .confirmed, .processing: return AppColors.accent
        case .shipped, .readyForPickup: return AppColors.secondary
        case .delivered, .completed: return AppColors.success
        case .cancelled: return AppColors.error
        }
    }

    private func statusDescription(_ status: OrderStatus) -> String {
        switch status {
        case .pending: return "Awaiting confirmation"
        case .confirmed: return "Your order has been confirmed"
        case .processing: return "Being prepared for shipment"
        case .shipped: return "On its way to you"
        case .delivered: return "Successfully delivered"
        case .readyForPickup: return "Ready at your boutique"
        case .completed: return "Order complete"
        case .cancelled: return "This order was cancelled"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }

    private func downloadInvoice() {
        do {
            let pdfURL = try InvoicePDFService.generatePDF(for: invoiceSnapshot)
            shareFile = ShareFile(url: pdfURL)
        } catch {
            invoiceError = "Unable to generate invoice PDF. Please try again."
            showInvoiceError = true
        }
    }
}
