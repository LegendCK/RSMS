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
    @Environment(\.modelContext) private var modelContext
    @Query private var stores: [StoreLocation]
    @Query private var pricingPolicies: [PricingPolicySettings]
    let order: Order
    @State private var showInvoiceSheet = false
    @State private var statusSyncError = ""
    @State private var shareFile: ShareFile?
    @State private var invoiceError = ""
    @State private var showInvoiceError = false
    @State private var checkingWarrantyItemId: String?
    @State private var warrantyResultsByItem: [String: WarrantyLookupResult] = [:]
    @State private var warrantyErrorsByItem: [String: String] = [:]
    @State private var selectedExchangeItemId: String?
    @State private var exchangeReason: String = ""
    @State private var isSubmittingExchangeRequest = false
    @State private var exchangeRequestTicketNumber: String?
    @State private var exchangeRequestError: String?

    private let statusFlow: [OrderStatus] = [
        .pending, .confirmed, .processing, .shipped, .delivered
    ]

    private let bopisStatusFlow: [OrderStatus] = [
        .pending, .confirmed, .processing, .readyForPickup, .completed
    ]

    private var activeFlow: [OrderStatus] {
        order.fulfillmentType == .bopis ? bopisStatusFlow : statusFlow
    }

    private var timelineStatus: OrderStatus {
        if activeFlow.contains(order.status) {
            return order.status
        }
        // Standard/ship-from-store/in-store flows may end at Delivered even when backend marks Completed.
        if order.status == .completed {
            return activeFlow.last ?? .pending
        }
        return .pending
    }

    private var currentStepIndex: Int {
        activeFlow.firstIndex(of: timelineStatus) ?? 0
    }

    private var policy: PricingPolicySettings {
        pricingPolicies.first ?? PricingPolicySettings()
    }

    var body: some View {
        List {
            // ── Header card ────────────────────────────────────────────
            Section {
                orderHeaderCard
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // ── Status timeline ────────────────────────────────────────
            Section {
                statusTimeline
                    .padding(.vertical, AppSpacing.sm)
            } header: {
                Label("Order Status", systemImage: "shippingbox")
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }

            // ── Items ──────────────────────────────────────────────────
            Section {
                ForEach(parsedItems) { item in
                    itemRow(item)
                }
            } header: {
                Label("Items", systemImage: "bag")
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }

            // ── Financial summary ──────────────────────────────────────
            Section {
                summaryRow(label: "Subtotal", value: formatCurrency(order.subtotal))
                summaryRow(label: "Tax", value: formatCurrency(order.tax))
                if order.discount > 0 {
                    summaryRow(label: "Discount", value: "-\(formatCurrency(order.discount))")
                }
                summaryRow(label: "Shipping", value: "Free")
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(order.formattedTotal)
                        .font(.headline)
                        .foregroundColor(AppColors.accent)
                }
            } header: {
                Label("Summary", systemImage: "indianrupeesign.circle")
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }

            // ── Delivery ───────────────────────────────────────────────
            Section {
                fulfillmentRow
            } header: {
                Label("Delivery", systemImage: "shippingbox.fill")
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }

            // ── Payment ────────────────────────────────────────────────
            Section {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: paymentIcon)
                        .font(.title3)
                        .foregroundColor(AppColors.accent)
                        .frame(width: 32)
                    Text(order.paymentMethod)
                        .font(.body)
                }
            } header: {
                Label("Payment", systemImage: "creditcard")
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }

            // ── Exchange Request ───────────────────────────────────────
            Section {
                exchangeRequestContent
            } header: {
                Label("Exchange Request", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            } footer: {
                Text("Submit a request to our after-sales team for size or item exchanges.")
                    .font(.footnote)
            }

            // ── Invoice ────────────────────────────────────────────────
            Section {
                Button {
                    showInvoiceSheet = true
                } label: {
                    Label("View Invoice", systemImage: "doc.text")
                }
                Button(action: downloadInvoice) {
                    Label("Download PDF", systemImage: "arrow.down.doc")
                }
            } header: {
                Label("Invoice", systemImage: "doc.plaintext")
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
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
        .task { await syncStatus() }
        .refreshable { await syncStatus() }
        .onAppear {
            if selectedExchangeItemId == nil {
                selectedExchangeItemId = parsedItems.first?.id
            }
        }
    }

    // MARK: - Sync Status

    @MainActor
    private func syncStatus() async {
        do {
            try await OrderStatusSyncService.shared.syncSingleOrder(order, modelContext: modelContext)
        } catch {
            print("[OrderDetailView] Status sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Order Header Card

    private var orderHeaderCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.sm) {
                Text(order.orderNumber)
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("Placed \(formattedDate(order.createdAt))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(order.status))
                        .frame(width: 8, height: 8)
                    Text(order.status.rawValue.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(statusColor(order.status))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(statusColor(order.status).opacity(0.12))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    // MARK: - Status Timeline

    private var statusTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(activeFlow.enumerated()), id: \.offset) { index, status in
                HStack(alignment: .top, spacing: 14) {
                    // Dot + connector
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(index < currentStepIndex
                                      ? AppColors.accent
                                      : index == currentStepIndex
                                        ? AppColors.accent
                                        : Color(uiColor: .systemFill))
                                .frame(width: 22, height: 22)

                            if index < currentStepIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            } else if index == currentStepIndex {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        if index < activeFlow.count - 1 {
                            Rectangle()
                                .fill(index < currentStepIndex ? AppColors.accent : Color(uiColor: .separator))
                                .frame(width: 2, height: 36)
                        }
                    }

                    // Label
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.rawValue.capitalized)
                            .font(index == currentStepIndex ? .subheadline.weight(.semibold) : .subheadline)
                            .foregroundColor(index <= currentStepIndex ? .primary : .secondary)

                        if index == currentStepIndex {
                            Text(statusDescription(status))
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.top, 2)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: ParsedItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                ProductArtworkView(
                    imageSource: item.image,
                    fallbackSymbol: "bag.fill",
                    cornerRadius: AppSpacing.radiusSmall
                )
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.brand)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.accent)

                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text("Qty \(item.qty)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatCurrency(item.price * Double(item.qty)))
                    .font(.subheadline.weight(.semibold))
            }

            // Warranty row
            HStack {
                if let result = warrantyResultsByItem[item.id] {
                    Label {
                        Text("Warranty \(result.status.rawValue) · \(result.coveragePeriodText)")
                            .font(.caption)
                    } icon: {
                        Circle()
                            .fill(warrantyStatusColor(result.status))
                            .frame(width: 7, height: 7)
                    }
                    .foregroundColor(.secondary)
                } else if let error = warrantyErrorsByItem[item.id] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                } else {
                    Spacer()
                }

                Spacer()

                Button {
                    Task { await lookupWarranty(for: item) }
                } label: {
                    if checkingWarrantyItemId == item.id {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Label("Warranty", systemImage: "checkmark.shield")
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .disabled(checkingWarrantyItemId == item.id)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Fulfillment Row

    private var fulfillmentRow: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: order.fulfillmentType == .bopis ? "building.2.fill" : "shippingbox.fill")
                .font(.title3)
                .foregroundColor(AppColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(order.fulfillmentType.rawValue)
                    .font(.subheadline.weight(.semibold))

                if order.fulfillmentType == .bopis {
                    Text(matchedStore?.name ?? "Boutique Store")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if let store = matchedStore {
                        Text("\(store.addressLine1), \(store.city), \(store.country)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(parsedAddress)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Exchange Request Content

    private var exchangeRequestContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if parsedItems.count > 1 {
                Picker("Item", selection: Binding(
                    get: { selectedExchangeItemId ?? parsedItems.first?.id ?? "" },
                    set: { selectedExchangeItemId = $0 }
                )) {
                    ForEach(parsedItems) { item in
                        Text("\(item.name) · Qty \(item.qty)").tag(item.id)
                    }
                }
            } else if let selectedItem = selectedExchangeItem {
                Text("\(selectedItem.name) · Qty \(selectedItem.qty)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $exchangeReason)
                .frame(minHeight: 80)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await submitExchangeRequest() }
            } label: {
                HStack(spacing: 8) {
                    if isSubmittingExchangeRequest {
                        ProgressView().tint(.white)
                        Text("Submitting…")
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Submit Exchange Request")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(canSubmitExchangeRequest ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmitExchangeRequest)

            if let exchangeRequestTicketNumber {
                Label("Submitted · Ticket: \(exchangeRequestTicketNumber)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.success)
            }

            if let exchangeRequestError {
                Label(exchangeRequestError, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundColor(AppColors.error)
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
        let productId: String?

        var productUUID: UUID? {
            guard let productId else { return nil }
            return UUID(uuidString: productId)
        }
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
                image: dict["image"] as? String ?? "bag.fill",
                productId: (dict["productId"] as? String) ?? (dict["product_id"] as? String)
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
            discountTotal: order.discount,
            taxBreakdown: InvoiceTaxBreakdown(cgst: cgst, sgst: sgst, igst: igst, cess: 0, other: 0),
            total: order.total,
            isTaxFree: order.isTaxFree,
            taxFreeReason: order.taxFreeReason
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
        let payment = order.paymentMethod.lowercased()
        if payment.contains("split:") { return "rectangle.3.group.fill" }
        if payment.contains("cash") { return "banknote.fill" }
        if payment.contains("bank") || payment.contains("transfer") { return "building.columns.fill" }
        if payment.contains("apple") { return "apple.logo" }
        if payment.contains("complimentary") || payment.contains("voucher") { return "gift.fill" }
        if payment.contains("card") { return "creditcard.fill" }
        return "creditcard"
    }

    private var selectedExchangeItem: ParsedItem? {
        if let selectedExchangeItemId,
           let match = parsedItems.first(where: { $0.id == selectedExchangeItemId }) {
            return match
        }
        return parsedItems.first
    }

    private var canSubmitExchangeRequest: Bool {
        !isSubmittingExchangeRequest
            && selectedExchangeItem != nil
            && !exchangeReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Helpers

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
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

    @MainActor
    private func lookupWarranty(for item: ParsedItem) async {
        guard checkingWarrantyItemId == nil else { return }

        checkingWarrantyItemId = item.id
        warrantyErrorsByItem[item.id] = nil

        do {
            var result: WarrantyLookupResult
            if let productUUID = item.productUUID {
                result = try await WarrantyService.shared.lookupWarranty(
                    mode: .productId,
                    query: productUUID.uuidString
                )
            } else {
                result = try await WarrantyService.shared.lookupWarranty(
                    mode: .purchaseRecord,
                    query: order.orderNumber
                )
            }

            // Local fallback: if Supabase has no record (order not synced yet,
            // e.g. historical POS sync failure), derive warranty from local data.
            if result.status == .notFound {
                result = WarrantyService.shared.lookupWarrantyLocally(
                    productId: item.productUUID,
                    productName: item.name,
                    brand: item.brand.isEmpty ? nil : item.brand,
                    purchasedAt: order.createdAt
                )
            }

            warrantyResultsByItem[item.id] = result
        } catch {
            warrantyResultsByItem[item.id] = nil
            warrantyErrorsByItem[item.id] = error.localizedDescription
        }

        checkingWarrantyItemId = nil
    }

    @MainActor
    private func submitExchangeRequest() async {
        guard canSubmitExchangeRequest, let selectedItem = selectedExchangeItem else { return }

        isSubmittingExchangeRequest = true
        exchangeRequestError = nil
        defer { isSubmittingExchangeRequest = false }

        let reason = exchangeReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteContext = try? await ServiceTicketService.shared.resolveOrderContext(orderNumber: order.orderNumber)
        let resolvedStoreId = remoteContext?.storeId ?? matchedStore?.id ?? appState.currentStoreId

        do {
            let ticketNumber = try await ServiceTicketService.shared.submitCustomerExchangeRequest(
                orderNumber: order.orderNumber,
                productId: selectedItem.productUUID,
                itemName: selectedItem.name,
                quantity: selectedItem.qty,
                reason: reason,
                customerEmail: order.customerEmail,
                knownStoreId: resolvedStoreId
            )
            exchangeRequestTicketNumber = ticketNumber ?? "Submitted"
            exchangeReason = ""
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            exchangeRequestError = "Failed to submit exchange request: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func warrantyStatusColor(_ status: WarrantyCoverageStatus) -> Color {
        switch status {
        case .valid: return AppColors.success
        case .expired: return AppColors.warning
        case .notFound: return AppColors.error
        }
    }
}
