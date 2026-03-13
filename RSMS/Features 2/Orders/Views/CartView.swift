//
//  CartView.swift
//  infosys2
//
//  Shopping bag — displays cart items with quantity controls, summary, and checkout CTA.
//

import SwiftUI
import SwiftData

struct CartView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allCartItems: [CartItem]

    @State private var navigateToCheckout = false

    private var cartItems: [CartItem] {
        allCartItems.filter { $0.customerEmail == appState.currentUserEmail }
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var subtotal: Double { cartItems.reduce(0) { $0 + $1.lineTotal } }
    private var tax: Double { subtotal * 0.08 }
    private var total: Double { subtotal + tax }
    private var itemCount: Int { cartItems.reduce(0) { $0 + $1.quantity } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if cartItems.isEmpty {
                    emptyState
                } else {
                    cartContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Shopping Bag")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
            .navigationDestination(isPresented: $navigateToCheckout) {
                CheckoutView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "bag")
                .font(AppTypography.iconDecorative)
                .foregroundColor(AppColors.neutral600)

            VStack(spacing: AppSpacing.xs) {
                Text("Your Bag is Empty")
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text("Browse our collections and add items to your bag")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
    }

    // MARK: - Cart Content

    private var cartContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {
                    // Item count
                    HStack {
                        Text("\(itemCount) \(itemCount == 1 ? "item" : "items") in your bag")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)

                    // Cart items
                    ForEach(cartItems) { item in
                        cartItemRow(item)
                    }

                    // Order summary
                    orderSummary
                        .padding(.top, AppSpacing.sm)
                }
                .padding(.bottom, 120)
            }

            // Bottom checkout bar
            checkoutBar
        }
    }

    // MARK: - Cart Item Row

    private func cartItemRow(_ item: CartItem) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Product image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 80, height: 80)

                Image(systemName: item.productImageName)
                    .font(AppTypography.iconProductSmall)
                    .foregroundColor(AppColors.neutral600)
            }

            // Product details
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(item.productBrand.uppercased())
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(AppColors.accent)

                Text(item.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(2)

                Text(item.formattedLineTotal)
                    .font(AppTypography.priceSmall)
                    .foregroundColor(AppColors.textSecondaryDark)

                // Quantity controls
                HStack(spacing: AppSpacing.sm) {
                    Button {
                        if item.quantity > 1 {
                            item.quantity -= 1
                            try? modelContext.save()
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(item.quantity > 1 ? AppColors.accent : AppColors.neutral600)
                    }
                    .disabled(item.quantity <= 1)

                    Text("\(item.quantity)")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .frame(minWidth: 24)

                    Button {
                        if item.quantity < 10 {
                            item.quantity += 1
                            try? modelContext.save()
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(item.quantity < 10 ? AppColors.accent : AppColors.neutral600)
                    }
                    .disabled(item.quantity >= 10)

                    Spacer()

                    // Remove button
                    Button {
                        withAnimation {
                            modelContext.delete(item)
                            try? modelContext.save()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(AppTypography.alertIcon)
                            .foregroundColor(AppColors.error)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Order Summary

    private var orderSummary: some View {
        LuxuryCardView {
            VStack(spacing: AppSpacing.sm) {
                Text("ORDER SUMMARY")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GoldDivider()

                summaryRow(label: "Subtotal", value: formatCurrency(subtotal))
                summaryRow(label: "Tax (8%)", value: formatCurrency(tax))

                GoldDivider()

                HStack {
                    Text("Total")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    Text(formatCurrency(total))
                        .font(AppTypography.priceDisplay)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
            .padding(AppSpacing.cardPadding)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
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

    // MARK: - Checkout Bar

    private var checkoutBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(formatCurrency(total))
                        .font(AppTypography.priceDisplay)
                        .foregroundColor(AppColors.textPrimaryDark)
                }

                Spacer()

                PrimaryButton(title: "Checkout") {
                    navigateToCheckout = true
                }
                .frame(width: 160)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
            .background(
                AppColors.backgroundPrimary
                    .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
            )
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
