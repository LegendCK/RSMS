import SwiftUI

struct ManagerOrderDetailSheet: View {
    let order: OrderDTO
    let events: [EventDTO]
    let onTagged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showTagSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {

                        // ── Channel + Status ─────────────────────────────────
                        HStack(spacing: AppSpacing.md) {
                            VStack(spacing: AppSpacing.xs) {
                                Image(systemName: channelIcon)
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(AppColors.accent)
                                Text(channelLabel)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.sm)
                            .background(AppColors.accent.opacity(0.07))
                            .cornerRadius(AppSpacing.radiusMedium)

                            VStack(spacing: AppSpacing.xs) {
                                Text(order.status.capitalized)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(statusColor)
                                Text("Status")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.sm)
                            .background(statusColor.opacity(0.08))
                            .cornerRadius(AppSpacing.radiusMedium)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.sm)

                        // ── Order Info ───────────────────────────────────────
                        detailCard {
                            row(label: "Order Number", value: order.orderNumber ?? "—")
                            Divider()
                            row(label: "Date", value: order.createdAt.formatted(date: .long, time: .omitted))
                            Divider()
                            row(label: "Time", value: order.createdAt.formatted(date: .omitted, time: .shortened))
                            if !order.isTaxFree {
                                Divider()
                                row(label: "Tax Exempt", value: "No")
                            }
                        }

                        // ── Customer ─────────────────────────────────────────
                        detailCard {
                            row(label: "Customer", value: order.customerName)
                            if let email = order.customerEmail {
                                Divider()
                                row(label: "Email", value: email)
                            }
                        }

                        // ── Financials ────────────────────────────────────────
                        detailCard {
                            row(label: "Subtotal", value: formatted(order.subtotal))
                            Divider()
                            row(label: "Tax", value: formatted(order.taxTotal))
                            Divider()
                            HStack {
                                Text("Total")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Spacer()
                                Text(order.formattedTotal)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.accent)
                            }
                        }

                        // ── Event Tag ─────────────────────────────────────────
                        if order.eventId != nil {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.secondary)
                                Text("Tagged to an Event")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.sm)
                            .background(AppColors.secondary.opacity(0.08))
                            .cornerRadius(AppSpacing.radiusMedium)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        } else if !events.isEmpty {
                            Button {
                                showTagSheet = true
                            } label: {
                                Label("Tag to Event", systemImage: "star")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(AppColors.accent.opacity(0.08))
                                    .cornerRadius(AppSpacing.radiusMedium)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        Spacer().frame(height: AppSpacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ORDER DETAIL")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
        .sheet(isPresented: $showTagSheet) {
            TagOrderToEventSheet(order: order, events: events) {
                onTagged()
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private var channelLabel: String {
        switch order.channel {
        case "bopis":           return "Pick Up In Store"
        case "ship_from_store": return "Ship from Store"
        case "in_store":        return "In-Store"
        case "online":          return "Online"
        default:                return order.channel.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var channelIcon: String {
        switch order.channel {
        case "bopis":           return "building.2"
        case "ship_from_store": return "shippingbox"
        case "in_store":        return "cart"
        case "online":          return "globe"
        default:                return "bag"
        }
    }

    private var statusColor: Color {
        switch order.status {
        case "completed", "delivered":  return AppColors.success
        case "cancelled":               return AppColors.error
        case "shipped", "processing":   return AppColors.accent
        default:                        return AppColors.warning
        }
    }

    private func formatted(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = order.currency
        return fmt.string(from: NSNumber(value: value)) ?? "\(order.currency) \(value)"
    }

    @ViewBuilder
    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: AppSpacing.sm) {
            content()
        }
        .padding(AppSpacing.cardPadding)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .multilineTextAlignment(.trailing)
        }
    }
}
