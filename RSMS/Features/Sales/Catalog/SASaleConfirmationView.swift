//
//  SASaleConfirmationView.swift
//  RSMS
//
//  Shown after a successful in-store POS sale is completed.
//  Displays order number, totals, and lets the SA start a new sale.
//

import SwiftUI

struct SASaleConfirmationView: View {

    @Environment(SACartViewModel.self) private var cart
    @Environment(\.dismiss)           private var dismiss

    @State private var ringScale:  CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var checkScale: CGFloat = 0.2
    @State private var contentOpacity: Double = 0

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
                    }
                    .opacity(contentOpacity)

                    // Receipt card
                    receiptCard
                        .opacity(contentOpacity)

                    // Actions
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
        .onAppear { runEntryAnimation() }
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
            receiptRow("Tax (8%)", cart.formattedTax)

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
