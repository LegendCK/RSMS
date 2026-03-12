//
//  OrderConfirmationView.swift
//  infosys2
//
//  Success screen shown after placing an order.
//

import SwiftUI

struct OrderConfirmationView: View {
    let order: Order
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    Spacer().frame(height: AppSpacing.xxl)

                    // Success icon
                    ZStack {
                        Circle()
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(AppColors.accent.opacity(0.1))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark")
                            .font(AppTypography.iconProductLarge)
                            .foregroundColor(AppColors.accent)
                    }

                    // Confirmation text
                    VStack(spacing: AppSpacing.sm) {
                        Text("ORDER CONFIRMED")
                            .font(AppTypography.overline)
                            .tracking(3)
                            .foregroundColor(AppColors.accent)

                        Text("Thank You")
                            .font(AppTypography.displaySmall)
                            .foregroundColor(AppColors.textPrimaryDark)

                        Text("Your order has been placed successfully.")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                    }

                    // Order details card
                    LuxuryCardView {
                        VStack(spacing: AppSpacing.md) {
                            detailRow(label: "Order Number", value: order.orderNumber)
                            GoldDivider()
                            detailRow(label: "Date", value: formattedDate)
                            GoldDivider()
                            detailRow(label: "Total", value: order.formattedTotal, isAccent: true)
                            GoldDivider()
                            detailRow(label: "Payment", value: order.paymentMethod)
                            GoldDivider()
                            detailRow(label: "Delivery", value: order.fulfillmentType == .bopis ? "Pick Up In Store" : "Standard Delivery")
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Estimated delivery
                    LuxuryCardView {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: order.fulfillmentType == .bopis ? "building.2.fill" : "shippingbox.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(order.fulfillmentType == .bopis ? "READY FOR PICKUP" : "ESTIMATED DELIVERY")
                                    .font(AppTypography.overline)
                                    .tracking(1)
                                    .foregroundColor(AppColors.accent)

                                Text(order.fulfillmentType == .bopis ? "Within 2 hours at Maison Luxe Flagship" : "5–7 business days")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }
                            Spacer()
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    // Action buttons
                    VStack(spacing: AppSpacing.sm) {
                        NavigationLink(destination: OrderDetailView(order: order)) {
                            Text("View Order Details")
                                .font(AppTypography.buttonPrimary)
                                .foregroundColor(AppColors.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.touchTarget)
                                .background(AppColors.accent)
                                .cornerRadius(AppSpacing.radiusMedium)
                        }

                        Button {
                            // Pop back to root
                            dismiss()
                        } label: {
                            Text("Continue Shopping")
                                .font(AppTypography.buttonSecondary)
                                .foregroundColor(AppColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.touchTarget)
                                .background(AppColors.backgroundSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                        .stroke(AppColors.accent, lineWidth: 1)
                                )
                                .cornerRadius(AppSpacing.radiusMedium)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    Spacer().frame(height: AppSpacing.xxl)
                }
            }
        }
        .navigationTitle("Order Confirmed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: order.createdAt)
    }

    private func detailRow(label: String, value: String, isAccent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(isAccent ? AppTypography.priceSmall : AppTypography.bodyMedium)
                .foregroundColor(isAccent ? AppColors.accent : AppColors.textPrimaryDark)
        }
    }
}
