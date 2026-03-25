//
//  SASaleCheckoutView.swift
//  RSMS
//
//  SA POS checkout — 2-step flow:
//    Step 0: Payment method selection + optional notes
//    Step 1: Review everything, then "Complete Sale"
//

import SwiftUI
import SwiftData

struct SASaleCheckoutView: View {

    @Environment(SACartViewModel.self) private var cart
    @Environment(AppState.self)        private var appState
    @Environment(\.modelContext)       private var modelContext
    @Environment(\.dismiss)            private var dismiss

    @State private var step: Int = 0
    @State private var selectedPayment: PaymentMethod = .cardReader
    @State private var notes: String = ""
    @State private var showError = false

    enum PaymentMethod: String, CaseIterable, Identifiable {
        case cardReader  = "Card Reader"
        case cash        = "Cash"
        case bankTransfer = "Bank Transfer"
        case complimentary = "Complimentary"

        var id: Self { self }

        var icon: String {
            switch self {
            case .cardReader:    return "creditcard.fill"
            case .cash:          return "banknote.fill"
            case .bankTransfer:  return "building.columns.fill"
            case .complimentary: return "gift.fill"
            }
        }

        var subtitle: String {
            switch self {
            case .cardReader:    return "Tap, chip, or swipe"
            case .cash:          return "Physical currency"
            case .bankTransfer:  return "Wire or IBAN transfer"
            case .complimentary: return "No charge — gifted or replaced"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    stepIndicator
                    Divider()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.xl) {
                            if step == 0 { paymentStep }
                            else         { reviewStep   }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(step == 0 ? "PAYMENT" : "REVIEW ORDER")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == 0 {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { step = 0 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Back")
                                    .font(.system(size: 15))
                            }
                            .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) { bottomBar }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(cart.errorMessage ?? "Something went wrong.")
            }
            .onChange(of: cart.errorMessage) { _, newVal in
                if newVal != nil { showError = true }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<2) { idx in
                HStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(idx <= step ? AppColors.accent : AppColors.backgroundTertiary)
                            .frame(width: 28, height: 28)
                        if idx < step {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(idx + 1)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(idx <= step ? .white : AppColors.neutral500)
                        }
                    }
                    Text(idx == 0 ? "Payment" : "Review")
                        .font(.system(size: 12, weight: idx == step ? .semibold : .regular))
                        .foregroundColor(idx == step ? AppColors.textPrimaryDark : AppColors.neutral500)
                        .padding(.leading, 6)

                    if idx < 1 {
                        Rectangle()
                            .fill(idx < step ? AppColors.accent : AppColors.border)
                            .frame(height: 1)
                            .padding(.horizontal, 10)
                    }
                }
                if idx < 1 { Spacer() }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, 14)
    }

    // MARK: - Step 0: Payment

    private var paymentStep: some View {
        VStack(spacing: AppSpacing.xl) {
            // Payment method list
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionLabel("PAYMENT METHOD")
                VStack(spacing: 0) {
                    ForEach(PaymentMethod.allCases) { method in
                        Button { selectedPayment = method } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedPayment == method
                                              ? AppColors.accent.opacity(0.12)
                                              : AppColors.backgroundTertiary)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: method.icon)
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(selectedPayment == method
                                                         ? AppColors.accent
                                                         : AppColors.neutral500)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(method.rawValue)
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Text(method.subtitle)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                Spacer()
                                Image(systemName: selectedPayment == method
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedPayment == method
                                                     ? AppColors.accent : AppColors.neutral500)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if method != PaymentMethod.allCases.last {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }

            // Notes field
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionLabel("NOTES (OPTIONAL)")
                TextField("Gift wrap, special instructions…", text: $notes, axis: .vertical)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(3...5)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }

            // Tax-free toggle
            taxFreeSection
        }
    }

    // MARK: - Tax-Free Section

    @State private var showExemptionPicker = false

    @ViewBuilder
    private var taxFreeSection: some View {
        @Bindable var cartBinding = cart
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionLabel("TAX-FREE SALE")
            VStack(spacing: 0) {
                // Toggle row
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(cart.isTaxFree
                                  ? AppColors.success.opacity(0.12)
                                  : AppColors.backgroundTertiary)
                            .frame(width: 40, height: 40)
                        Image(systemName: cart.isTaxFree ? "checkmark.seal.fill" : "percent")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(cart.isTaxFree ? AppColors.success : AppColors.neutral500)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tax-Free Transaction")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text(cart.isTaxFree
                             ? "GST exemption active — verify eligibility below"
                             : "Enable for eligible customers (GST exempt)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Toggle("", isOn: $cartBinding.isTaxFree)
                        .tint(AppColors.success)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 12)

                if cart.isTaxFree {
                    Divider().padding(.leading, 60)

                    // Exemption category selector
                    Button { showExemptionPicker = true } label: {
                        HStack(spacing: AppSpacing.sm) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(AppColors.accent.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: cart.selectedExemptionReason.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("EXEMPTION CATEGORY")
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(1.2)
                                    .foregroundColor(AppColors.accent)
                                Text(cart.selectedExemptionReason.rawValue)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.neutral500)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 60)

                    // Verification hint
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.info)
                            .padding(.top, 1)
                        Text(cart.selectedExemptionReason.verificationHint)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.info)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 8)
                    .background(AppColors.info.opacity(0.06))

                    Divider().padding(.leading, 60)

                    // Document reference input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DOCUMENT / REFERENCE NUMBER")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(AppColors.accent)
                        TextField("e.g. Passport no., LUT ref, PO number…", text: $cartBinding.taxFreeReason)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 10)

                    // Tax savings preview
                    if cart.discountedSubtotal > 0 {
                        Divider().padding(.leading, 60)
                        HStack(spacing: 8) {
                            Image(systemName: "indianrupeesign.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.success)
                            Text("Saving \(cart.fmt(cart.discountedSubtotal * cart.taxRate)) GST")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.success)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                        .background(AppColors.success.opacity(0.06))
                    }
                }
            }
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                    .stroke(cart.isTaxFree ? AppColors.success.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.25), value: cart.isTaxFree)
        }
        .sheet(isPresented: $showExemptionPicker) {
            exemptionPickerSheet
        }
    }

    // MARK: - Exemption Picker Sheet

    private var exemptionPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(TaxExemptionReason.allCases) { reason in
                    Button {
                        cart.selectedExemptionReason = reason
                        showExemptionPicker = false
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(cart.selectedExemptionReason == reason
                                          ? AppColors.accent.opacity(0.12)
                                          : AppColors.backgroundSecondary)
                                    .frame(width: 40, height: 40)
                                Image(systemName: reason.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(cart.selectedExemptionReason == reason
                                                     ? AppColors.accent : AppColors.neutral500)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reason.rawValue)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text(reason.code)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            Spacer()
                            if cart.selectedExemptionReason == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.vertical, AppSpacing.xxs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Exemption Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showExemptionPicker = false }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Step 1: Review

    private var reviewStep: some View {
        VStack(spacing: AppSpacing.xl) {

            // Client card
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionLabel("CLIENT")
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        if let client = cart.selectedClient {
                            Text(client.initials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cart.selectedClient?.fullName ?? "Walk-in Customer")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text(cart.selectedClient?.email ?? "No account linked")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }

            // Items summary
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionLabel("ITEMS (\(cart.itemCount))")
                VStack(spacing: 0) {
                    ForEach(cart.items) { item in
                        HStack {
                            Text("\(item.productName)")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .lineLimit(1)
                            Spacer()
                            Text("×\(item.quantity)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .padding(.trailing, 8)
                            Text(item.formattedLineTotal)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                        if item.id != cart.items.last?.id {
                            Divider().padding(.horizontal, AppSpacing.md)
                        }
                    }
                }
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }

            // Totals
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionLabel("ORDER TOTAL")
                VStack(spacing: 0) {
                    reviewRow("Subtotal",   cart.formattedSubtotal)
                    if cart.discountAmount > 0 {
                        Divider().padding(.horizontal, AppSpacing.md)
                        reviewRow("Discount", "−\(cart.formattedDiscount)", color: AppColors.success)
                    }
                    Divider().padding(.horizontal, AppSpacing.md)
                    if cart.isTaxFree {
                        HStack {
                            Text("Tax")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                            Text("EXEMPT")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.success)
                                .clipShape(Capsule())
                            Spacer()
                            HStack(spacing: 6) {
                                Text(cart.fmt(cart.discountedSubtotal * cart.taxRate))
                                    .font(AppTypography.bodySmall)
                                    .strikethrough(true, color: AppColors.error.opacity(0.6))
                                    .foregroundColor(AppColors.textSecondaryDark.opacity(0.5))
                                Text(cart.formattedTax)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.success)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 12)
                    } else {
                        reviewRow("Tax (\(Int(cart.taxRate * 100))%)", cart.formattedTax)
                    }
                    Divider().padding(.horizontal, AppSpacing.md)
                    reviewRow("Total",      cart.formattedTotal,
                              font: .system(size: 17, weight: .black),
                              color: AppColors.accent)
                }
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }

            // Tax-free verification summary (if applicable)
            if cart.isTaxFree {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    sectionLabel("TAX EXEMPTION")
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.success)
                            Text(cart.selectedExemptionReason.rawValue)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        if !cart.taxFreeReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 6) {
                                Text("Ref:")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                Text(cart.taxFreeReason)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "indianrupeesign.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.success)
                            Text("Saving \(cart.fmt(cart.discountedSubtotal * cart.taxRate)) GST")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.success)
                        }
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.success.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                            .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            // Payment method
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionLabel("PAYMENT")
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: selectedPayment.icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 24)
                    Text(selectedPayment.rawValue)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }

            // Notes (if any)
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    sectionLabel("NOTES")
                    Text(notes)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
                }
            }
        }
    }

    private func reviewRow(
        _ label: String,
        _ value: String,
        font: Font = AppTypography.label,
        color: Color = AppColors.textPrimaryDark
    ) -> some View {
        HStack {
            Text(label).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value).font(font).foregroundColor(color)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppSpacing.md) {
                if step == 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { step = 1 }
                    } label: {
                        Text("Review Order")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        Task {
                            await cart.completeSale(
                                paymentMethod: selectedPayment.rawValue,
                                notes: notes,
                                associateProfile: appState.currentUserProfile,
                                modelContext: modelContext
                            )
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if cart.isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            }
                            Text(cart.isProcessing ? "Processing…" : "Complete Sale")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(cart.isProcessing ? AppColors.accent.opacity(0.6) : AppColors.accent)
                        .clipShape(Capsule())
                    }
                    .disabled(cart.isProcessing)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(.ultraThinMaterial)
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
