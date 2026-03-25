//
//  TaxFreeCheckoutSection.swift
//  RSMS
//
//  Tax-free eligibility verification section shown to Sales Associates during checkout.
//  Allows toggling tax-free status, selecting an exemption reason, capturing verification
//  documents, and previewing the tax savings for the customer.
//

import SwiftUI

struct TaxFreeCheckoutSection: View {
    @Binding var verification: TaxExemptionVerification
    let originalTax: Double
    let currencyFormatter: (Double) -> String

    @State private var showReasonPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // ── Toggle ──────────────────────────────────────────────
            taxFreeToggle

            if verification.isEnabled {
                // ── Reason Selector ─────────────────────────────────
                reasonSelector

                // ── Verification Hint ───────────────────────────────
                verificationHintBanner

                // ── Document Reference ──────────────────────────────
                LuxuryTextField(
                    placeholder: "Document / Reference Number *",
                    text: $verification.documentReference,
                    icon: "doc.text.fill"
                )

                // ── Optional Notes ──────────────────────────────────
                LuxuryTextField(
                    placeholder: "Additional Notes (optional)",
                    text: $verification.notes,
                    icon: "note.text"
                )

                // ── Tax Savings Preview ─────────────────────────────
                if originalTax > 0 {
                    taxSavingsBanner
                }

                // ── Validation Warning ──────────────────────────────
                if !verification.isComplete {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.warning)
                        Text("Enter the document reference to proceed with tax-free checkout")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.warning)
                    }
                    .padding(.top, AppSpacing.xxs)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: verification.isEnabled)
        .sheet(isPresented: $showReasonPicker) {
            reasonPickerSheet
        }
    }

    // MARK: - Toggle Row

    private var taxFreeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                verification.isEnabled.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(verification.isEnabled ? AppColors.success.opacity(0.12) : AppColors.backgroundSecondary)
                        .frame(width: 44, height: 44)
                    Image(systemName: verification.isEnabled ? "checkmark.seal.fill" : "percent")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(verification.isEnabled ? AppColors.success : AppColors.neutral600)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tax-Free Transaction")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(verification.isEnabled ? "GST exemption active — verify eligibility" : "Enable for eligible customers (GST exempt)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Spacer()

                Image(systemName: verification.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(verification.isEnabled ? AppColors.success : AppColors.neutral600)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(verification.isEnabled ? AppColors.success.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reason Selector

    private var reasonSelector: some View {
        Button { showReasonPicker = true } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.accent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: verification.reason.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("EXEMPTION CATEGORY")
                        .font(AppTypography.overline)
                        .tracking(1.5)
                        .foregroundColor(AppColors.accent)
                    Text(verification.reason.rawValue)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.neutral600)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Verification Hint

    private var verificationHintBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.info)
                .padding(.top, 2)

            Text(verification.reason.verificationHint)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.info)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.info.opacity(0.08))
        .cornerRadius(AppSpacing.radiusSmall)
    }

    // MARK: - Tax Savings Banner

    private var taxSavingsBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "indianrupeesign.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.success)

            VStack(alignment: .leading, spacing: 2) {
                Text("TAX SAVINGS")
                    .font(AppTypography.overline)
                    .tracking(1.5)
                    .foregroundColor(AppColors.success)
                Text("\(currencyFormatter(originalTax)) GST will be waived")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.success)
            }

            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.success.opacity(0.08))
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Reason Picker Sheet

    private var reasonPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(TaxExemptionReason.allCases) { reason in
                    Button {
                        verification.reason = reason
                        showReasonPicker = false
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(verification.reason == reason ? AppColors.accent.opacity(0.12) : AppColors.backgroundSecondary)
                                    .frame(width: 40, height: 40)
                                Image(systemName: reason.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(verification.reason == reason ? AppColors.accent : AppColors.neutral600)
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

                            if verification.reason == reason {
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
                    Button("Done") { showReasonPicker = false }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}
