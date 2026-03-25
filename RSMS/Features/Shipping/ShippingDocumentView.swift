//
//  ShippingDocumentView.swift
//  RSMS
//
//  On-screen packing slip detail sheet — luxury card layout matching InvoiceDetailSheetView.
//

import SwiftUI

struct ShippingDocumentView: View {
    let document: ShippingDocument
    let onDownload: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        headerCard
                        shipToCard
                        itemsCard
                        summaryCard
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .navigationTitle("Packing Slip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.doc")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                    Spacer()
                    Text("PACKING SLIP")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }

                GoldDivider()

                row("Order", document.orderNumber)
                row("Date", dateTime(document.createdAt))
                row("Fulfillment", document.fulfillmentType)
                row("Customer", document.customerName)
                row("Email", document.customerEmail)
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Ship To Card

    private var shipToCard: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("SHIP TO")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)

                Text(document.shippingAddress)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineSpacing(4)

                GoldDivider()

                Text("FROM")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)

                Text(document.originStoreName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(document.originStoreAddress)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Items Card

    private var itemsCard: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("ITEMS TO PACK")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)

                ForEach(Array(document.items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if !item.brand.isEmpty {
                                Text(item.brand.uppercased())
                                    .font(AppTypography.pico)
                                    .foregroundColor(AppColors.accent)
                            }
                            Text(item.name)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            HStack(spacing: AppSpacing.sm) {
                                Text("SKU: \(item.sku)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                Text("Qty: \(item.quantity)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }
                        Spacer()
                        Text(formatCurrency(item.lineTotal))
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    if index < document.items.count - 1 {
                        GoldDivider()
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        LuxuryCardView {
            VStack(spacing: AppSpacing.xs) {
                HStack {
                    Text("Total Items")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                    Text("\(document.totalQuantity)")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                }

                if !document.notes.isEmpty {
                    GoldDivider()
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("NOTES")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        Text(document.notes)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .multilineTextAlignment(.trailing)
        }
    }

    private func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }
}
