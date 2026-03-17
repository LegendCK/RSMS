//
//  OrderConfirmationView.swift
//  RSMS
//
//  Luxe order success screen: animated checkmark, order timeline,
//  items list with thumbnails, delivery address, and payment summary.
//

import SwiftUI

struct OrderConfirmationView: View {
    let order: Order
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var checkmarkScale: CGFloat  = 0.1
    @State private var ringProgress: Double      = 0
    @State private var contentOpacity: Double    = 0
    @State private var showItems                 = false

    // Parse order items from JSON
    private var orderItems: [[String: Any]] {
        guard let data = order.orderItems.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr
    }

    // Parse address from JSON
    private var parsedAddress: [String: String] {
        guard let data = order.shippingAddress.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return dict
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    Spacer().frame(height: AppSpacing.xl)

                    // ── Animated checkmark ─────────────────────────
                    animatedCheckmark

                    // ── Confirmation text ───────────────────────────
                    VStack(spacing: AppSpacing.sm) {
                        Text("ORDER CONFIRMED")
                            .font(AppTypography.overline)
                            .tracking(3)
                            .foregroundColor(AppColors.accent)

                        Text("Thank You")
                            .font(AppTypography.displaySmall)
                            .foregroundColor(AppColors.textPrimaryDark)

                        Text("Order \(order.orderNumber)")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .opacity(contentOpacity)

                    // ── Order summary card ─────────────────────────
                    LuxuryCardView {
                        VStack(spacing: AppSpacing.sm) {
                            detailRow("Order Number", value: order.orderNumber)
                            GoldDivider()
                            detailRow("Date",         value: formattedDate)
                            GoldDivider()
                            detailRow("Payment",      value: order.paymentMethod)
                            GoldDivider()
                            detailRow("Delivery",     value: order.fulfillmentType == .bopis ? "Pick Up In Store" : "Standard Delivery")
                            GoldDivider()
                            HStack {
                                Text("Total")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                Spacer()
                                Text(order.formattedTotal)
                                    .font(AppTypography.priceSmall)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .opacity(contentOpacity)

                    // ── Order timeline ─────────────────────────────
                    orderTimeline
                        .opacity(contentOpacity)

                    // ── Items ──────────────────────────────────────
                    if !orderItems.isEmpty {
                        itemsSection
                            .opacity(contentOpacity)
                    }

                    // ── Delivery address ───────────────────────────
                    if order.fulfillmentType == .standard, !parsedAddress.isEmpty,
                       let line1 = parsedAddress["line1"], !line1.isEmpty {
                        deliveryAddressCard
                            .opacity(contentOpacity)
                    } else if order.fulfillmentType == .bopis {
                        pickupCard
                            .opacity(contentOpacity)
                    }

                    // ── Actions ───────────────────────────────────
                    VStack(spacing: AppSpacing.sm) {
                        NavigationLink(destination: OrderDetailView(order: order)) {
                            Text("View Full Order Details")
                                .font(AppTypography.buttonPrimary)
                                .foregroundColor(AppColors.textPrimaryLight)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.touchTarget)
                                .background(AppColors.accent)
                                .cornerRadius(AppSpacing.radiusMedium)
                        }

                        Button {
                            // Dismiss this view (and any parent sheet), then
                            // reset the home NavigationStack path to root.
                            dismiss()
                            appState.navigateToHome()
                        } label: {
                            Text("Continue Shopping")
                                .font(AppTypography.buttonSecondary)
                                .foregroundColor(AppColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.touchTarget)
                                .background(AppColors.backgroundSecondary)
                                .cornerRadius(AppSpacing.radiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                        .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .opacity(contentOpacity)

                    Spacer().frame(height: AppSpacing.xxl)
                }
            }
        }
        .navigationTitle("Order Confirmed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { runEntryAnimation() }
    }

    // MARK: - Animated Checkmark

    private var animatedCheckmark: some View {
        ZStack {
            // Background ring (growing)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(AppColors.accent.opacity(0.2), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(AppColors.accent.opacity(0.08))
                .frame(width: 90, height: 90)

            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(AppColors.accent)
                .scaleEffect(checkmarkScale)
        }
    }

    // MARK: - Order Timeline

    private var orderTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ORDER STATUS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.md)

            LuxuryCardView {
                VStack(spacing: 0) {
                    timelineRow(icon: "checkmark.circle.fill", title: "Order Confirmed",
                                subtitle: formattedDate, isCompleted: true, isLast: false)
                    timelineRow(icon: "arrow.triangle.2.circlepath.circle",
                                title: order.fulfillmentType == .bopis ? "Preparing for Pickup" : "Processing",
                                subtitle: "1–2 business days", isCompleted: false, isLast: false)
                    if order.fulfillmentType == .bopis {
                        timelineRow(icon: "building.2.circle.fill", title: "Ready for Pickup",
                                    subtitle: "Within 2 hours", isCompleted: false, isLast: true)
                    } else {
                        timelineRow(icon: "shippingbox.circle.fill", title: "Shipped",
                                    subtitle: "2–4 business days", isCompleted: false, isLast: false)
                        timelineRow(icon: "house.circle.fill", title: "Delivered",
                                    subtitle: "5–7 business days", isCompleted: false, isLast: true)
                    }
                }
                .padding(AppSpacing.cardPadding)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func timelineRow(icon: String, title: String, subtitle: String,
                              isCompleted: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isCompleted ? AppColors.accent : AppColors.neutral600)
                    .frame(width: 26)
                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? AppColors.accent.opacity(0.3) : AppColors.neutral700.opacity(0.3))
                        .frame(width: 1.5)
                        .frame(height: 32)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.label)
                    .foregroundColor(isCompleted ? AppColors.textPrimaryDark : AppColors.neutral600)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .padding(.top, 2)
            Spacer()
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("ITEMS ORDERED")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            LuxuryCardView {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(orderItems.indices, id: \.self) { idx in
                        let item = orderItems[idx]
                        HStack(spacing: AppSpacing.md) {
                            if let img = item["image"] as? String {
                                ProductArtworkView(
                                    imageSource: img,
                                    fallbackSymbol: "bag.fill",
                                    cornerRadius: AppSpacing.radiusSmall
                                )
                                .frame(width: 60, height: 60)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                if let brand = item["brand"] as? String {
                                    Text(brand.uppercased())
                                        .font(AppTypography.overline).tracking(1)
                                        .foregroundColor(AppColors.accent)
                                }
                                if let name = item["name"] as? String {
                                    Text(name)
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                        .lineLimit(2)
                                }
                                if let qty = item["qty"] as? Int {
                                    Text("Qty: \(qty)")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                            Spacer()
                            if let price = item["price"] as? Double {
                                Text(formatCurrency(price))
                                    .font(AppTypography.priceSmall)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }
                        }
                        if idx < orderItems.count - 1 { GoldDivider() }
                    }
                }
                .padding(AppSpacing.cardPadding)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    // MARK: - Delivery Address Card

    private var deliveryAddressCard: some View {
        LuxuryCardView {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("DELIVER TO")
                        .font(AppTypography.overline)
                        .tracking(1)
                        .foregroundColor(AppColors.accent)

                    let line1   = parsedAddress["line1"] ?? ""
                    let line2   = parsedAddress["line2"] ?? ""
                    let city    = parsedAddress["city"]  ?? ""
                    let state   = parsedAddress["state"] ?? ""
                    let zip     = parsedAddress["zip"]   ?? ""

                    Text(line2.isEmpty ? line1 : "\(line1), \(line2)")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("\(city), \(state) \(zip)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
            }
            .padding(AppSpacing.cardPadding)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private var pickupCard: some View {
        LuxuryCardView {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("READY FOR PICKUP")
                        .font(AppTypography.overline).tracking(1)
                        .foregroundColor(AppColors.accent)
                    Text("Maison Luxe Flagship")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("123 Luxury Avenue, New York, NY 10001")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
            }
            .padding(AppSpacing.cardPadding)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: order.createdAt)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle  = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }

    private func runEntryAnimation() {
        withAnimation(.easeOut(duration: 0.9)) {
            ringProgress = 1.0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.5)) {
            checkmarkScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
            contentOpacity = 1.0
        }
    }
}
