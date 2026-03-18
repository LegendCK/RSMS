import SwiftUI

struct InvoiceDetailSheetView: View {
    let invoice: InvoiceSnapshot
    let onDownload: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        headerCard
                        productsCard
                        totalsCard
                        metaCard
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .navigationTitle("Invoice")
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

    private var headerCard: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(invoice.storeName)
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(invoice.storeAddress)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)

                GoldDivider()

                row("Invoice", invoice.invoiceNumber)
                row("Order", invoice.orderNumber)
                row("Issued", dateTime(invoice.issuedAt))
                row("Customer", invoice.customerName)
                row("Email", invoice.customerEmail)
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    private var productsCard: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("PRODUCTS")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)

                ForEach(Array(invoice.items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.brand.uppercased())
                                .font(AppTypography.pico)
                                .foregroundColor(AppColors.accent)
                            Text(item.name)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text("Qty: \(item.quantity)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        Spacer()
                        Text(formatCurrency(item.lineTotal))
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    if index < invoice.items.count - 1 {
                        GoldDivider()
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    private var totalsCard: some View {
        LuxuryCardView {
            VStack(spacing: AppSpacing.xs) {
                row("Subtotal", formatCurrency(invoice.subtotal))
                row("CGST", formatCurrency(invoice.taxBreakdown.cgst))
                row("SGST", formatCurrency(invoice.taxBreakdown.sgst))
                if invoice.taxBreakdown.igst > 0 {
                    row("IGST", formatCurrency(invoice.taxBreakdown.igst))
                }
                if invoice.taxBreakdown.cess > 0 {
                    row("Cess", formatCurrency(invoice.taxBreakdown.cess))
                }
                if invoice.taxBreakdown.other > 0 {
                    row("Other Tax", formatCurrency(invoice.taxBreakdown.other))
                }
                GoldDivider()
                row("Grand Total", formatCurrency(invoice.total), emphasized: true)
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    private var metaCard: some View {
        LuxuryCardView {
            VStack(spacing: AppSpacing.xs) {
                row("Fulfillment", invoice.fulfillmentLabel)
                row("Payment", invoice.paymentMethod)
                row("Ship To", invoice.shippingAddress)
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    private func row(_ label: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(emphasized ? AppTypography.label : AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(emphasized ? AppTypography.label : AppTypography.bodySmall)
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
        formatter.currencyCode = invoice.currencyCode
        return formatter.string(from: NSNumber(value: value)) ?? "\(invoice.currencyCode) \(value)"
    }
}
