//
//  RepairIntakeView.swift
//  RSMS
//
//  Sheet presented from ScannedItemCard when an Inventory Controller
//  taps "Log Repair" after a successful barcode scan.
//
//  On successful submit the view transitions inline to
//  RepairTicketConfirmationView — no extra navigation push needed.
//
//  NEW FILE — place in RSMS/Features/Inventory/Repairs/
//

import SwiftUI

struct RepairIntakeView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // MARK: - ViewModel

    @State private var vm: RepairIntakeViewModel

    // MARK: - Init

    init(scanResult: ScanResult, storeId: UUID, assignedToUserId: UUID?) {
        _vm = State(initialValue: RepairIntakeViewModel(
            scanResult:       scanResult,
            storeId:          storeId,
            assignedToUserId: assignedToUserId
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if let ticket = vm.submittedTicket {
                    // ── Success state ─────────────────────────────────────
                    RepairTicketConfirmationView(ticket: ticket) { dismiss() }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .opacity
                        ))
                } else {
                    // ── Form state ────────────────────────────────────────
                    formBody
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.submittedTicket != nil)
            // FIX: Prevent swipe-to-dismiss while a submit is in progress
            .interactiveDismissDisabled(vm.isSubmitting)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Log Repair Intake")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.submittedTicket == nil {
                        // Disable Cancel while submitting to prevent state corruption
                        Button("Cancel") { dismiss() }
                            .foregroundColor(AppColors.accent)
                            .disabled(vm.isSubmitting)
                    }
                }
            }
        }
    }

    // MARK: - Form Body

    private var formBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {

                productSummaryCard
                serviceTypeSection
                conditionNotesSection
                additionalNotesSection
                estimatedCostSection
                slaDueDateSection

                if let err = vm.errorMessage {
                    errorBanner(err)
                }

                submitButton

                Spacer(minLength: AppSpacing.xxxl)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: - Product Summary Card

    private var productSummaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            productThumbnail

            VStack(alignment: .leading, spacing: 4) {
                if let brand = vm.scanResult.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(AppTypography.nano)
                        .tracking(1.5)
                        .foregroundColor(AppColors.accent)
                }
                Text(vm.scanResult.productName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "barcode")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(vm.scanResult.barcode)
                        .font(AppTypography.monoID)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .fill(AppColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var productThumbnail: some View {
        Group {
            if let urlStr = vm.scanResult.imageUrls?.first,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary)
            Image(systemName: "shippingbox")
                .font(.system(size: 20))
                .foregroundColor(AppColors.textSecondaryDark)
        }
    }

    // MARK: - Service Type Section

    private var serviceTypeSection: some View {
        sectionCard(label: "SERVICE TYPE") {
            VStack(spacing: 2) {
                ForEach(RepairType.allCases) { type in
                    typeRow(type)
                }
            }
        }
    }

    private func typeRow(_ type: RepairType) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) { vm.selectedType = type }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 15))
                    .foregroundColor(vm.selectedType == type ? AppColors.accent : AppColors.textSecondaryDark)
                    .frame(width: 22)

                Text(type.displayName)
                    .font(AppTypography.label)
                    .foregroundColor(vm.selectedType == type ? AppColors.textPrimaryDark : AppColors.textSecondaryDark)

                Spacer()

                if vm.selectedType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(vm.selectedType == type ? AppColors.accent.opacity(0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Condition Notes Section

    private var conditionNotesSection: some View {
        sectionCard(label: "CONDITION AT INTAKE") {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Describe the item's condition *")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)

                TextEditor(text: $vm.conditionNotes)
                    .frame(minHeight: 88)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(AppColors.backgroundTertiary)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .stroke(
                                        vm.conditionNotes.isEmpty
                                            ? AppColors.border
                                            : AppColors.accent.opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
        }
    }

    // MARK: - Additional Notes Section

    private var additionalNotesSection: some View {
        sectionCard(label: "ADDITIONAL NOTES") {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Client requests, special handling (optional)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)

                TextEditor(text: $vm.additionalNotes)
                    .frame(minHeight: 60)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(AppColors.backgroundTertiary)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    )
            }
        }
    }

    // MARK: - Estimated Cost Section

    private var estimatedCostSection: some View {
        sectionCard(label: "ESTIMATED COST") {
            HStack(spacing: AppSpacing.sm) {
                Text("₹")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)

                TextField("0.00  (optional)", text: $vm.estimatedCostText)
                    .keyboardType(.decimalPad)
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(AppColors.backgroundTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - SLA Due Date Section

    private var slaDueDateSection: some View {
        sectionCard(label: "SLA DUE DATE") {
            VStack(spacing: AppSpacing.sm) {
                Toggle("Set a due date", isOn: $vm.includeSLA)
                    .tint(AppColors.accent)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)

                if vm.includeSLA {
                    DatePicker(
                        "Due date",
                        selection: $vm.slaDueDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(AppColors.accent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3), value: vm.includeSLA)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.error.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task { await vm.submit() }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if vm.isSubmitting {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Creating Ticket…")
                } else {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Create Repair Ticket")
                }
            }
            .font(AppTypography.buttonPrimary)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDark],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        )
                    )
            )
            .opacity(vm.isFormValid ? 1 : 0.45)
        }
        .disabled(!vm.isFormValid || vm.isSubmitting)
    }

    // MARK: - Section Card Wrapper

    private func sectionCard<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.overline)
                .tracking(1.5)
                .foregroundColor(AppColors.accent)

            content()
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .fill(AppColors.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                                .stroke(AppColors.border.opacity(0.45), lineWidth: 0.75)
                        )
                )
        }
    }
}
