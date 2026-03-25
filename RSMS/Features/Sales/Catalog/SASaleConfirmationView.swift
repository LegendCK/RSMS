//
//  SASaleConfirmationView.swift
//  RSMS
//
//  Shown after a successful in-store POS sale.
//  Displays animated confirmation, order summary receipt, and receipt actions
//  (share digital PDF, print, gift receipt).
//

import SwiftUI

struct SASaleConfirmationView: View {

    @Environment(SACartViewModel.self) private var cart
    @Environment(\.dismiss)           private var dismiss

    @State private var ringScale:  CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var checkScale: CGFloat = 0.2
    @State private var contentOpacity: Double = 0

    // Receipt state
    @State private var receiptURL: URL?     = nil
    @State private var giftReceiptURL: URL? = nil
    @State private var showShareSheet       = false
    @State private var showGiftShareSheet   = false
    @State private var showPrintDialog      = false
    @State private var receiptError: String? = nil

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {

                    // Animated check mark
                    ZStack {
                        Circle()
                            .stroke(AppColors.success.opacity(0.25), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(ringScale)
                            .opacity(ringOpacity)

                        Circle()
                            .fill(AppColors.success.opacity(0.12))
                            .frame(width: 90, height: 90)

                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(AppColors.success)
                            .scaleEffect(checkScale)
                    }
                    .padding(.top, 48)

                    // Title
                    VStack(spacing: 6) {
                        Text("Sale Complete")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(AppColors.textPrimaryDark)

                        if let num = cart.completedOrderNumber {
                            Text(num)
                                .font(.system(size: 13, weight: .medium))
                                .tracking(1)
                                .foregroundColor(AppColors.accent)
                        }

                        if cart.isTaxFree {
                            Label("Tax-Free Sale", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.warning)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.warning.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .opacity(contentOpacity)

                    // Receipt card
                    receiptCard
                        .opacity(contentOpacity)

                    // Receipt actions
                    receiptActions
                        .opacity(contentOpacity)

                    // Navigation actions
                    VStack(spacing: AppSpacing.sm) {
                        Button {
                            cart.clearCart()
                        } label: {
                            Text("New Sale")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.accent)
                                .clipShape(Capsule())
                        }

                        Button {
                            cart.clearCart()
                        } label: {
                            Text("Done")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .opacity(contentOpacity)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
        .onAppear {
            runEntryAnimation()
            buildReceipt()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = receiptURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showGiftShareSheet) {
            if let url = giftReceiptURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Receipt Error", isPresented: .constant(receiptError != nil)) {
            Button("OK") { receiptError = nil }
        } message: {
            Text(receiptError ?? "")
        }
    }

    // MARK: - Receipt Card

    private var receiptCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ORDER SUMMARY")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                    if let num = cart.completedOrderNumber {
                        Text(num)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
                Spacer()
                Text(Date(), style: .date)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .padding(AppSpacing.md)

            Divider().padding(.horizontal, AppSpacing.md)

            // Items
            ForEach(cart.items) { item in
                HStack {
                    Text(item.productName)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(1)
                    Spacer()
                    Text("×\(item.quantity)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .padding(.trailing, 8)
                    Text(item.formattedLineTotal)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 8)
            }

            Divider().padding(.horizontal, AppSpacing.md)

            // Totals
            receiptRow("Subtotal", cart.formattedSubtotal)
            if cart.discountAmount > 0 {
                receiptRow("Discount", "−\(cart.formattedDiscount)", color: AppColors.success)
            }
            if cart.isTaxFree {
                HStack {
                    Text("Tax")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("TAX-FREE")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.warning)
                        .clipShape(Capsule())
                    Spacer()
                    Text(cart.formattedTax) // "₹0.00"
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 8)
            } else {
                receiptRow("Tax (\(Int(cart.taxRate * 100))%)", cart.formattedTax)
            }

            Divider().padding(.horizontal, AppSpacing.md)

            receiptRow("Total", cart.formattedTotal,
                       font: .system(size: 18, weight: .black),
                       color: AppColors.accent)
                .padding(.bottom, 4)
        }
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                .stroke(AppColors.success.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Receipt Actions

    private var receiptActions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("RECEIPT")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            HStack(spacing: AppSpacing.sm) {
                // Share digital receipt
                receiptActionButton(
                    icon: "square.and.arrow.up",
                    label: "Share"
                ) {
                    showShareSheet = true
                }

                // Print
                receiptActionButton(
                    icon: "printer",
                    label: "Print"
                ) {
                    printReceipt()
                }

                // Gift receipt
                receiptActionButton(
                    icon: "gift",
                    label: "Gift"
                ) {
                    buildGiftReceipt()
                    showGiftShareSheet = true
                }
            }
        }
    }

    private func receiptActionButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.accent.opacity(0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(AppColors.accent)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Receipt Generation

    private func buildReceipt() {
        let snapshot = makeSnapshot(isGift: false)
        receiptURL = try? InvoicePDFService.generatePOSReceipt(for: snapshot, isGift: false)
    }

    private func buildGiftReceipt() {
        let snapshot = makeSnapshot(isGift: true)
        giftReceiptURL = try? InvoicePDFService.generatePOSReceipt(for: snapshot, isGift: true)
    }

    private func makeSnapshot(isGift: Bool) -> InvoiceSnapshot {
        let lineItems = cart.items.map {
            InvoiceLineItem(
                name:      $0.productName,
                brand:     $0.productBrand,
                quantity:  $0.quantity,
                unitPrice: $0.unitPrice
            )
        }
        let taxTotal = cart.tax
        let taxBreakdown = InvoiceTaxBreakdown(
            cgst: taxTotal / 2,
            sgst: taxTotal / 2,
            igst: 0,
            cess: 0,
            other: 0
        )
        return InvoiceSnapshot(
            invoiceNumber:  cart.completedOrderNumber ?? "—",
            orderNumber:    cart.completedOrderNumber ?? "—",
            issuedAt:       Date(),
            customerName:   cart.selectedClient?.fullName ?? "Walk-in Customer",
            customerEmail:  cart.selectedClient?.email   ?? "—",
            storeName:      "Maison Luxe",
            storeAddress:   "In-Store Purchase",
            shippingAddress: "—",
            fulfillmentLabel: "In-Store",
            paymentMethod:  cart.completedPaymentMethod,
            currencyCode:   "INR",
            items:          lineItems,
            subtotal:       cart.subtotal,
            discountTotal:  cart.discountAmount,
            taxBreakdown:   taxBreakdown,
            total:          cart.total,
            isTaxFree:      cart.isTaxFree,
            taxFreeReason:  cart.taxFreeReason
        )
    }

    private func printReceipt() {
        guard let url = receiptURL else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Receipt \(cart.completedOrderNumber ?? "")"
        printController.printInfo = printInfo
        printController.printingItem = url
        printController.present(animated: true)
    }

    // MARK: - Helpers

    private func receiptRow(
        _ label: String,
        _ value: String,
        font: Font = AppTypography.caption,
        color: Color = AppColors.textPrimaryDark
    ) -> some View {
        HStack {
            Text(label).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value).font(font).foregroundColor(color)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 8)
    }

    // MARK: - Animation

    private func runEntryAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            ringScale   = 1.0
            ringOpacity = 1.0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.25)) {
            checkScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
            contentOpacity = 1.0
        }
    }
}

