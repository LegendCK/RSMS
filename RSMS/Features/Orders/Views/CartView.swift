//
//  CartView.swift
//  RSMS
//
//  Premium shopping bag — larger thumbnails, swipe-to-delete, order summary, checkout CTA.
//

import SwiftUI
import SwiftData

struct CartView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCartItems: [CartItem]

    @State private var navigateToCheckout = false
    @State private var showGuestAuthGate  = false

    private var cartItems: [CartItem] {
        allCartItems.filter { $0.customerEmail == appState.currentUserEmail }
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var subtotal: Double { cartItems.reduce(0) { $0 + $1.lineTotal } }
    private var tax:      Double { subtotal * 0.08 }
    private var shipping: Double { subtotal > 500 ? 0 : 25 }
    private var total:    Double { subtotal + tax + shipping }
    private var itemCount: Int   { cartItems.reduce(0) { $0 + $1.quantity } }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if appState.isGuest {
                guestState
            } else if cartItems.isEmpty {
                emptyState
            } else {
                cartContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Shopping Bag")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                    if itemCount > 0 {
                        Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                            .font(AppTypography.pico)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToCheckout) {
            CheckoutView()
        }
        .sheet(isPresented: $showGuestAuthGate) {
            GuestAuthGateView(pendingAction: "Add to Bag")
                .presentationDetents([.large])
        }
        .onChange(of: appState.shouldNavigateHome) { _, newValue in
            guard newValue else { return }
            print("[CartView] shouldNavigateHome detected, resetting navigateToCheckout and showCart")
            navigateToCheckout = false
            appState.showCart = false
        }
    }

    // MARK: - Guest State

    private var guestState: some View {
        VStack(spacing: AppSpacing.xl) {
            Image(systemName: "lock")
                .font(AppTypography.iconDecorative)
                .foregroundColor(AppColors.neutral600)
            VStack(spacing: AppSpacing.xs) {
                Text("Sign In to Shop")
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Create an account or sign in to add\nitems to your bag and checkout.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            VStack(spacing: AppSpacing.sm) {
                PrimaryButton(title: "Sign In") { showGuestAuthGate = true }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                SecondaryButton(title: "Create Account") { showGuestAuthGate = true }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
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
            SecondaryButton(title: "Continue Shopping") { dismiss() }
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .padding(.horizontal, AppSpacing.xxl)
    }

    // MARK: - Cart Content

    private var cartContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sm) {
                    // Items
                    ForEach(cartItems) { item in
                        cartItemRow(item)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    }

                    // Free shipping progress
                    if subtotal < 500 {
                        freeShippingBanner
                    }

                    // Order summary
                    orderSummary
                        .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, 130)
            }

            checkoutBar
        }
    }

    // MARK: - Cart Item Row

    private func cartItemRow(_ item: CartItem) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Larger thumbnail
            ProductArtworkView(
                imageSource: item.productImageName,
                fallbackSymbol: "bag.fill",
                cornerRadius: AppSpacing.radiusMedium
            )
            .frame(width: 100, height: 100)

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

                // Quantity stepper
                HStack(spacing: AppSpacing.sm) {
                    Button {
                        if item.quantity > 1 {
                            item.quantity -= 1
                            try? modelContext.save()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
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
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(item.quantity < 10 ? AppColors.accent : AppColors.neutral600)
                    }
                    .disabled(item.quantity >= 10)

                    Spacer()
                }
            }

            // Remove
            Button {
                withAnimation(.spring(response: 0.3)) {
                    modelContext.delete(item)
                    try? modelContext.save()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.neutral600)
                    .padding(8)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(Circle())
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    modelContext.delete(item)
                    try? modelContext.save()
                }
            } label: {
                Label("Remove", systemImage: "trash.fill")
            }
            .tint(AppColors.error)
        }
    }

    // MARK: - Free Shipping Banner

    private var freeShippingBanner: some View {
        let remaining = 500.0 - subtotal
        let progress  = subtotal / 500.0
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(AppColors.accent)
                Text("Add \(formatCurrency(remaining)) more for free shipping")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule()
                        .fill(AppColors.accent)
                        .frame(width: geo.size.width * min(progress, 1.0))
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
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

                summaryRow("Subtotal",          value: formatCurrency(subtotal))
                summaryRow("Tax (8%)",            value: formatCurrency(tax))
                summaryRow("Shipping",            value: subtotal > 500 ? "Free" : formatCurrency(shipping))

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
    }

    // MARK: - Checkout Bar

    private var checkoutBar: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.xs) {
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
                    Button(action: { navigateToCheckout = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Checkout")
                                .font(AppTypography.buttonPrimary)
                        }
                        .foregroundColor(AppColors.textPrimaryLight)
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(height: AppSpacing.touchTarget)
                        .background(AppColors.accent)
                        .cornerRadius(AppSpacing.radiusMedium)
                    }
                }

                Text("Estimated delivery: 5–7 business days")
                    .font(AppTypography.pico)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
            .background(
                AppColors.backgroundPrimary
                    .shadow(color: .black.opacity(0.25), radius: 12, y: -6)
            )
        }
    }

    // MARK: - Helpers

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

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle  = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
