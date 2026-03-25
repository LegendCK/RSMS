//
//  TicketPartsView.swift
//  RSMS
//
//  Spare-part allocation sheet for a service ticket.
//  Shown as a sheet from ServiceTicketDetailView.
//

import SwiftUI

@MainActor
struct TicketPartsView: View {
    @State var vm: TicketPartsViewModel
    @Environment(\.dismiss) private var dismiss

    init(ticketId: UUID, storeId: UUID, allocatedByUserId: UUID?) {
        _vm = State(initialValue: TicketPartsViewModel(
            ticketId: ticketId,
            storeId: storeId,
            allocatedByUserId: allocatedByUserId
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    allocatedPartsCard
                    addPartCard
                    if let msg = vm.successMessage { successBanner(msg) }
                    if let err = vm.errorMessage   { errorBanner(err) }
                    Spacer(minLength: AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Spare Parts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(AppTypography.buttonSecondary)
                }
            }
            .task {
                await vm.loadParts()
                await vm.loadProducts()
            }
        }
    }

    // MARK: - Allocated parts list

    private var allocatedPartsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("ALLOCATED PARTS")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, AppSpacing.md)
            } else if vm.parts.isEmpty {
                Text("No parts allocated yet.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.secondary)
                    .padding(.vertical, AppSpacing.sm)
            } else {
                ForEach(vm.parts) { part in
                    partRow(part)
                    if part.id != vm.parts.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    @ViewBuilder
    private func partRow(_ part: ServiceTicketPartDTO) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(part.product?.name ?? "Unknown Part")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.primary)
                Text("SKU: \(part.product?.sku ?? "—")  ·  Qty: \(part.quantityRequired)")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                if let notes = part.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                statusBadge(part.partStatus)

                if part.partStatus == .reserved {
                    HStack(spacing: AppSpacing.xs) {
                        Button("Use") {
                            Task { await vm.markAsUsed(part) }
                        }
                        .buttonStyle(CompactActionButtonStyle(color: AppColors.accent))

                        Button("Release") {
                            Task { await vm.releasePart(part) }
                        }
                        .buttonStyle(CompactActionButtonStyle(color: AppColors.warning))
                    }
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .opacity(vm.isAllocating ? 0.5 : 1)
        .animation(.easeInOut, value: vm.isAllocating)
    }

    // MARK: - Add part form

    private var addPartCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("ADD PART")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

            // Product search
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Search Product")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Name, SKU, or brand", text: $vm.productSearchText)
                        .autocorrectionDisabled()
                        .onChange(of: vm.productSearchText) { _, _ in
                            if vm.selectedProduct != nil &&
                               vm.productSearchText != vm.selectedProduct?.name {
                                vm.selectedProduct = nil
                                vm.checkedAvailability = nil
                            }
                        }
                    if !vm.productSearchText.isEmpty {
                        Button {
                            vm.resetForm()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

                // Suggestions dropdown
                if vm.selectedProduct == nil && !vm.productSearchText.isEmpty {
                    if vm.isLoadingProducts {
                        HStack { ProgressView().scaleEffect(0.7); Text("Loading…").font(AppTypography.caption) }
                            .padding(AppSpacing.xs)
                    } else if vm.filteredProducts.isEmpty {
                        Text("No products found.")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, AppSpacing.xs)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(vm.filteredProducts.prefix(6)) { product in
                                Button {
                                    vm.selectProduct(product)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(product.name)
                                                .font(AppTypography.bodySmall)
                                                .foregroundColor(.primary)
                                            Text("SKU: \(product.sku)")
                                                .font(AppTypography.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(product.formattedPrice)
                                            .font(AppTypography.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, AppSpacing.xs)
                                    .padding(.horizontal, AppSpacing.sm)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    }
                }
            }

            // Availability indicator
            if let product = vm.selectedProduct {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "cube.box")
                        .foregroundColor(.secondary)
                    Text("Selected: \(product.name)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(.primary)
                    Spacer()
                    if vm.isCheckingAvailability {
                        ProgressView().scaleEffect(0.7)
                    } else if let avail = vm.checkedAvailability {
                        availabilityChip(avail)
                    }
                }
                .padding(AppSpacing.sm)
                .background(AppColors.accent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
            }

            // Quantity stepper
            HStack {
                Text("Quantity")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 0) {
                    Button {
                        if vm.quantityToAllocate > 1 { vm.quantityToAllocate -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 36, height: 36)
                            .foregroundColor(vm.quantityToAllocate <= 1 ? .secondary : .primary)
                    }
                    .disabled(vm.quantityToAllocate <= 1)

                    Text("\(vm.quantityToAllocate)")
                        .font(AppTypography.bodyMedium)
                        .frame(width: 36)
                        .multilineTextAlignment(.center)

                    Button {
                        let max = vm.checkedAvailability ?? 99
                        if vm.quantityToAllocate < max { vm.quantityToAllocate += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 36, height: 36)
                            .foregroundColor(
                                vm.quantityToAllocate >= (vm.checkedAvailability ?? 99)
                                    ? .secondary : .primary
                            )
                    }
                    .disabled(vm.quantityToAllocate >= (vm.checkedAvailability ?? 99))
                }
                .background(Color(.systemFill))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
            }

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes (optional)")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. Replacing broken clasp", text: $vm.allocationNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(AppSpacing.sm)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            }

            // Allocate button
            Button {
                Task { await vm.allocatePart() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if vm.isAllocating {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(vm.isAllocating ? "Reserving…" : "Reserve Part")
                        .font(AppTypography.buttonSecondary)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(vm.canAllocate ? AppColors.accent : Color(.systemGray3))
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.canAllocate)
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    // MARK: - Helpers

    private func statusBadge(_ status: TicketPartStatus) -> some View {
        let color: Color = {
            switch status {
            case .reserved: return .blue
            case .used:     return AppColors.success
            case .released: return .secondary
            }
        }()
        return Text(status.displayName)
            .font(AppTypography.nano)
            .tracking(0.6)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func availabilityChip(_ qty: Int) -> some View {
        let sufficient = qty >= vm.quantityToAllocate
        return HStack(spacing: 3) {
            Image(systemName: sufficient ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text("In stock: \(qty)")
        }
        .font(AppTypography.caption)
        .foregroundColor(sufficient ? AppColors.success : AppColors.error)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill((sufficient ? AppColors.success : AppColors.error).opacity(0.12)))
    }

    private func successBanner(_ msg: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success)
            Text(msg).font(AppTypography.bodySmall)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).fill(AppColors.success.opacity(0.1)))
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
            Text(msg).font(AppTypography.bodySmall)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).fill(AppColors.error.opacity(0.1)))
    }
}

// MARK: - Compact button style used inside part rows

private struct CompactActionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.nano)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(configuration.isPressed ? 0.25 : 0.12)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
