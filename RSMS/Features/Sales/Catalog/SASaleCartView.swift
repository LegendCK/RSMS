//
//  SASaleCartView.swift
//  RSMS
//
//  SA POS cart — product rows, client selection, discount input, order totals.
//  Presented as a sheet from the Catalog tab when the SA taps the cart badge.
//

import SwiftUI

struct SASaleCartView: View {

    @Environment(SACartViewModel.self) private var cart
    @Environment(AppState.self)        private var appState
    @Environment(\.modelContext)       private var modelContext
    @Environment(\.dismiss)            private var dismiss

    @State private var showClientPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if cart.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.lg) {
                            itemsSection
                            clientSection
                            discountSection
                            summaryCard
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, 120)   // room for sticky checkout bar
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("SALE CART")
                            .font(AppTypography.navTitle)
                            .foregroundColor(AppColors.textPrimaryDark)
                        if cart.itemCount > 0 {
                            Text("\(cart.itemCount) item\(cart.itemCount == 1 ? "" : "s")")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !cart.isEmpty {
                        Button("Clear") { cart.clearCart(); dismiss() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.error)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !cart.isEmpty { checkoutBar }
            }
            .sheet(isPresented: $showClientPicker) {
                SAClientPickerView { client in
                    cart.selectedClient = client
                    showClientPicker = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { cart.showCheckout },
                set: { cart.showCheckout = $0 }
            )) {
                SASaleCheckoutView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { cart.showConfirmation },
                set: { v in if !v { cart.clearCart(); dismiss() } }
            )) {
                SASaleConfirmationView()
                    .presentationDetents([.large])
                    .interactiveDismissDisabled()
            }
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionLabel("ITEMS")
            VStack(spacing: 0) {
                ForEach(cart.items) { item in
                    cartRow(item)
                    if item.id != cart.items.last?.id {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
        }
    }

    private func cartRow(_ item: SACartItem) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 52, height: 52)
                if let url = item.imageURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                               .frame(width: 52, height: 52)
                               .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Image(systemName: "bag.fill")
                                .foregroundColor(AppColors.neutral600)
                        }
                    }
                } else {
                    Image(systemName: "bag.fill")
                        .foregroundColor(AppColors.neutral600)
                }
            }

            // Name + brand + variant
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(item.productBrand)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                if let variant = item.variantLabel {
                    Text(variant)
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.accent.opacity(0.8))
                }
                Text(item.formattedLineTotal)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.accent)
            }

            Spacer(minLength: 0)

            // Qty stepper
            HStack(spacing: 0) {
                Button {
                    cart.updateQuantity(item, qty: item.quantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(item.quantity <= 1 ? AppColors.neutral500 : AppColors.textPrimaryDark)
                        .frame(width: 32, height: 32)
                }

                Text("\(item.quantity)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimaryDark)
                    .frame(width: 28)

                Button {
                    cart.updateQuantity(item, qty: item.quantity + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textPrimaryDark)
                        .frame(width: 32, height: 32)
                }
            }
            .background(AppColors.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button { cart.removeItem(item) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.neutral500)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    // MARK: - Client Section

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionLabel("CLIENT")
            Button { showClientPicker = true } label: {
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(width: 40, height: 40)
                        if let client = cart.selectedClient {
                            Text(client.initials)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(AppColors.accent)
                        }
                    }

                    if let client = cart.selectedClient {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.fullName)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            HStack(spacing: 6) {
                                Text(client.email)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                    .lineLimit(1)
                                if let seg = client.segment, seg != "standard" {
                                    segmentBadge(seg)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Select Client")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text("Optional — walk-in sales allowed")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AppTypography.chevron)
                        .foregroundColor(AppColors.neutral600)
                }
                .padding(AppSpacing.md)
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }
            .buttonStyle(.plain)

            // Loyalty tier info
            if let label = cart.loyaltyLabel {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.warning)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.warning)
                }
                .padding(.leading, 4)
            }
        }
    }

    private func segmentBadge(_ segment: String) -> some View {
        let label = segment.replacingOccurrences(of: "_", with: " ").uppercased()
        return Text(label)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.accent.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Discount Section

    private var discountSection: some View {
        @Bindable var bindCart = cart

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionLabel("DISCOUNT")

            VStack(spacing: AppSpacing.sm) {
                // Mode picker + input
                HStack(spacing: AppSpacing.sm) {
                    Picker("", selection: $bindCart.discountMode) {
                        ForEach(SACartViewModel.DiscountMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)

                    HStack(spacing: 6) {
                        if cart.discountMode == .flat {
                            Text("$").foregroundColor(AppColors.accent).font(AppTypography.label)
                        }
                        TextField("0", text: $bindCart.discountInput)
                            .keyboardType(.decimalPad)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        if cart.discountMode == .percent {
                            Text("%").foregroundColor(AppColors.accent).font(AppTypography.label)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 10)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
                }

                // Applied discount preview
                if cart.discountAmount > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.success)
                        Text("Saving \(cart.formattedDiscount) on this order")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.success)
                        Spacer()
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow("Subtotal", value: cart.formattedSubtotal)
            if cart.discountAmount > 0 {
                Divider().padding(.horizontal, AppSpacing.md)
                summaryRow("Discount", value: "−\(cart.formattedDiscount)", valueColor: AppColors.success)
            }
            Divider().padding(.horizontal, AppSpacing.md)
            if cart.isTaxFree {
                HStack {
                    HStack(spacing: 4) {
                        Text("Tax")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text("EXEMPT")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.success)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(cart.formattedTax)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.success)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 13)
            } else {
                summaryRow("Tax (\(Int(cart.taxRate * 100))%)", value: cart.formattedTax)
            }
            Divider().padding(.horizontal, AppSpacing.md)
            summaryRow("Total", value: cart.formattedTotal,
                       labelFont: .system(size: 16, weight: .bold),
                       valueFont:  .system(size: 16, weight: .black),
                       valueColor: AppColors.accent)
        }
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
    }

    private func summaryRow(
        _ label: String,
        value: String,
        labelFont: Font = AppTypography.bodySmall,
        valueFont: Font = AppTypography.label,
        valueColor: Color = AppColors.textPrimaryDark
    ) -> some View {
        HStack {
            Text(label).font(labelFont).foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value).font(valueFont).foregroundColor(valueColor)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 13)
    }

    // MARK: - Sticky Checkout Bar

    private var checkoutBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(cart.formattedTotal)
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                Spacer()
                Button { cart.showCheckout = true } label: {
                    Text("Checkout")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(AppColors.accent.opacity(0.35))
            Text("Cart is Empty")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Add products from the Catalog tab")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
    }
}

// MARK: - Client Picker Sheet

struct SAClientPickerView: View {

    let onSelect: (ClientDTO) -> Void

    @State private var clients: [ClientDTO] = []
    @State private var searchText = ""
    @State private var isLoading  = false
    @Environment(\.dismiss) private var dismiss

    private var filtered: [ClientDTO] {
        guard !searchText.isEmpty else { return clients }
        let q = searchText.lowercased()
        return clients.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q) ||
            ($0.phone?.contains(q) == true)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(AppColors.accent)
                } else if filtered.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Spacer()
                        Image(systemName: "person.slash")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(AppColors.neutral500)
                        Text(searchText.isEmpty ? "No clients found" : "No match for \"\(searchText)\"")
                            .lineLimit(2)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                    }
                } else {
                    List(filtered) { client in
                        Button { onSelect(client) } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Text(client.initials)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.accent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(client.fullName)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                        if let seg = client.segment, seg != "standard" {
                                            Text(seg.replacingOccurrences(of: "_", with: " ").uppercased())
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(AppColors.accent)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(AppColors.accent.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(client.email)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }
                        .listRowBackground(AppColors.backgroundSecondary)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SELECT CLIENT")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Name, email, or phone…"
            )
            .task { await loadClients() }
        }
    }

    private func loadClients() async {
        isLoading = true
        defer { isLoading = false }
        clients = (try? await ClientService.shared.fetchAllClients()) ?? []
    }
}

