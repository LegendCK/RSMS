//
//  AllocationCreationSheet.swift
//  RSMS
//
//  Modal form to create a new stock allocation.
//  Source location is selected from locations with available stock.
//  Validates quantity <= available before enabling submit.
//

import SwiftUI

struct AllocationCreationSheet: View {
    let product: ProductDTO
    let destinationInventory: InventoryDTO
    let sourceOptions: [InventoryDTO]
    let viewModel: AllocationViewModel
    let userId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSourceId: UUID?
    @State private var quantityText = ""
    @State private var showSuccess = false

    // MARK: - Computed

    private var selectedSource: InventoryDTO? {
        guard let id = selectedSourceId else { return nil }
        return sourceOptions.first { $0.id == id }
    }

    private var available: Int {
        let src = selectedSource
        return max((src?.quantity ?? 0) - (src?.reservedQuantity ?? 0), 0)
    }

    private var quantityInt: Int? {
        guard let n = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)), n > 0 else { return nil }
        return n
    }

    private var validationError: String? {
        guard let qty = quantityInt else {
            return quantityText.isEmpty ? nil : "Enter a valid quantity"
        }
        if qty > available {
            return "Exceeds available stock (\(available))"
        }
        return nil
    }

    private var canSubmit: Bool {
        selectedSourceId != nil &&
        quantityInt != nil &&
        validationError == nil &&
        !viewModel.isCreating
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if showSuccess {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle("Create Allocation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .onAppear {
            // Pre-select first source with stock
            selectedSourceId = sourceOptions.first?.id
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {

                // Product Info Card
                formCard("Product") {
                    infoRow("Name", product.name)
                    infoRow("SKU", product.sku)
                    if let brand = product.brand {
                        infoRow("Brand", brand)
                    }
                    infoRow("Price", product.formattedPrice)
                }

                // Destination (pre-selected)
                formCard("Destination") {
                    infoRow("Store", destinationInventory.stores?.name ?? "Selected Store")
                    infoRow("Current Stock", "\(destinationInventory.quantity)")
                }

                // Source picker
                formCard("Source Location") {
                    if sourceOptions.isEmpty {
                        Text("No locations have available stock for this product.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.error)
                    } else {
                        Picker("Source", selection: Binding(
                            get: { selectedSourceId },
                            set: { selectedSourceId = $0; quantityText = "" }
                        )) {
                            Text("Select source…").tag(UUID?.none)
                            ForEach(sourceOptions) { inv in
                                Text(sourceLabel(inv)).tag(UUID?.some(inv.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let src = selectedSource {
                            Divider().background(AppColors.border)
                            HStack {
                                statPill("On Hand", value: "\(src.quantity)", color: AppColors.textPrimaryDark)
                                statPill("Reserved", value: "\(src.reservedQuantity)", color: AppColors.warning)
                                statPill("Available", value: "\(max(src.quantity - src.reservedQuantity, 0))", color: AppColors.success)
                            }
                        }
                    }
                }

                // Quantity Input
                formCard("Quantity") {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack {
                            TextField("Enter quantity", text: $quantityText)
                                .keyboardType(.numberPad)
                                .font(AppTypography.heading3)
                                .foregroundStyle(AppColors.textPrimaryDark)

                            if available > 0 {
                                Button("Max") {
                                    quantityText = "\(available)"
                                }
                                .font(AppTypography.actionSmall)
                                .foregroundStyle(AppColors.accent)
                            }
                        }

                        if let err = validationError {
                            Text(err)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.error)
                        } else if let qty = quantityInt {
                            Text("Will reserve \(qty) unit(s) from source")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondaryDark)
                        }
                    }
                }

                // Error Banner
                if let err = viewModel.creationError {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.error)
                        Text(err)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.error)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.error.opacity(0.1))
                    .cornerRadius(AppSpacing.radiusMedium)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Submit Button
                Button {
                    submitAllocation()
                } label: {
                    Group {
                        if viewModel.isCreating {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Creating…")
                            }
                        } else {
                            Text("Create Allocation")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(canSubmit ? AppColors.accent : AppColors.neutral500)
                    .cornerRadius(AppSpacing.radiusMedium)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .onChange(of: viewModel.creationSuccess) { _, success in
            if success { showSuccess = true }
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.success)
            Text("Allocation Created")
                .font(AppTypography.heading2)
                .foregroundStyle(AppColors.textPrimaryDark)
            Text("Stock has been reserved at the source location. Track it in the Transfers tab.")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppColors.accent)
                .cornerRadius(AppSpacing.radiusMedium)
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .padding(.bottom, AppSpacing.xxxl)
    }

    // MARK: - Helpers

    private func submitAllocation() {
        guard let sourceId = selectedSourceId,
              let qty = quantityInt else { return }

        Task {
            await viewModel.createAllocation(
                productId: product.id,
                fromLocationId: sourceId,
                toLocationId: destinationInventory.locationId,
                quantity: qty,
                createdBy: userId
            )
        }
    }

    private func sourceLabel(_ inv: InventoryDTO) -> String {
        let name = inv.stores?.name ?? "Location"
        let avail = max(inv.quantity - inv.reservedQuantity, 0)
        return "\(name) (Avail: \(avail))"
    }

    private func formCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(1.5)
                .foregroundStyle(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimaryDark)
                .lineLimit(1)
        }
    }

    private func statPill(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
    }
}
