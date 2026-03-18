//
//  InventoryAddStockView.swift
//  RSMS
//
//  Stock-In screen for Inventory Controllers.
//  Select a product → enter quantity → tap "Generate Items"
//  → barcodes are created server-side and displayed in a scrollable list.
//
//  Architecture: MVVM (@Observable AddStockViewModel → StockService → Supabase RPC)
//  Does NOT touch ScanManager, ScanService, or any scanning pipeline.
//

import SwiftUI
import Supabase

// MARK: - Main View

struct InventoryAddStockView: View {
    @State private var viewModel = AddStockViewModel()
    @State private var showProductPicker = false
    @State private var stateVersion = 0  // incremented on state change to drive animation
    @FocusState private var quantityFocused: Bool

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    // MARK: - Form Card
                    formCard

                    // MARK: - Result Panel
                    if case .success(let count, let items) = viewModel.state {
                        successPanel(count: count, items: items)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if case .failure(let msg) = viewModel.state {
                        errorBanner(msg)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .navigationTitle("Add Stock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .success = viewModel.state {
                    Button("New Batch") { withAnimation { viewModel.reset() } }
                        .font(AppTypography.actionLink)
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        // Drive spring animation from an Int counter — avoids Equatable on AddStockState
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stateVersion)
        .onChange(of: viewModel.canSubmit) { stateVersion += 1 }
        .sheet(isPresented: $showProductPicker) {
            ProductPickerSheet(selectedProduct: $viewModel.selectedProduct)
        }
        .onTapGesture { quantityFocused = false }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            // Section: Product
            sectionLabel("PRODUCT")

            productSelector
                .padding(.bottom, AppSpacing.xs)

            // Section: Quantity
            sectionLabel("QUANTITY")

            quantityField

            // Validation hint
            if let msg = viewModel.validationMessage {
                Text(msg)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.error)
                    .padding(.top, -AppSpacing.xs)
            }

            // Submit Button
            submitButton
                .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.cardPadding)
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
    }

    // MARK: - Product Selector

    private var productSelector: some View {
        Button { showProductPicker = true } label: {
            HStack {
                if let product = viewModel.selectedProduct {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(AppTypography.label)
                            .foregroundStyle(AppColors.textPrimaryDark)
                            .lineLimit(1)
                        Text("SKU: \(product.sku)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondaryDark)
                    }
                } else {
                    Text("Select a product…")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondaryDark)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(
                                viewModel.selectedProduct != nil
                                    ? AppColors.accent.opacity(0.4)
                                    : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    // MARK: - Quantity Field

    private var quantityField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "number")
                .font(AppTypography.iconSmall)
                .foregroundStyle(
                    quantityFocused ? AppColors.accent : AppColors.textSecondaryDark
                )

            TextField("e.g. 10", text: $viewModel.quantityText)
                .keyboardType(.numberPad)
                .focused($quantityFocused)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimaryDark)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(
                            quantityFocused ? AppColors.accent.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: quantityFocused)
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            quantityFocused = false
            Task { await viewModel.createStock() }
        } label: {
            Group {
                if case .loading = viewModel.state {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Generating…")
                    }
                } else {
                    Label(
                        "Generate Items",
                        systemImage: "barcode.viewfinder"
                    )
                }
            }
            .font(AppTypography.label)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(AppColors.accent)
        .disabled(!viewModel.canSubmit)
        .opacity(viewModel.canSubmit ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
    }

    // MARK: - Success Panel

    private func successPanel(count: Int, items: [ProductItemDTO]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) item\(count == 1 ? "" : "s") added successfully")
                        .font(AppTypography.heading3)
                        .foregroundStyle(AppColors.textPrimaryDark)
                    if let product = viewModel.selectedProduct {
                        Text(product.name)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondaryDark)
                    }
                }
                Spacer()
            }

            Divider().background(Color.white.opacity(0.08))

            // Barcode list header
            Text("GENERATED BARCODES")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundStyle(AppColors.accent)

            // Scrollable barcode list
            LazyVStack(spacing: AppSpacing.xxs) {
                ForEach(items.indices, id: \.self) { index in
                    barcodeRow(index: index + 1, barcode: items[index].barcode, status: items[index].status)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
    }

    private func barcodeRow(index: Int, barcode: String, status: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text("\(index)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textSecondaryDark)
                .frame(width: 22, alignment: .trailing)

            Image(systemName: "barcode")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.accent.opacity(0.7))

            Text(barcode)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(AppColors.textPrimaryDark)
                .lineLimit(1)

            Spacer()

            Text(status)
                .font(AppTypography.nano)
                .foregroundStyle(.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .cornerRadius(4)
        }
        .padding(.vertical, AppSpacing.xxs)
        .padding(.horizontal, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppColors.error)
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimaryDark)
                .lineLimit(3)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.error.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Utility

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundStyle(AppColors.textSecondaryDark)
    }
}

// MARK: - Product Picker Sheet

struct ProductPickerSheet: View {
    @Binding var selectedProduct: ProductDTO?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var products: [ProductDTO] = []
    @State private var isLoading = true
    @State private var error: String?

    private var filtered: [ProductDTO] {
        searchText.isEmpty ? products : products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.sku.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                Group {
                    if isLoading {
                        VStack(spacing: AppSpacing.md) {
                            ProgressView().tint(AppColors.accent)
                            Text("Loading products…")
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textSecondaryDark)
                        }
                    } else if let error {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(AppTypography.emptyStateIcon)
                                .foregroundStyle(AppColors.warning)
                            Text(error)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textSecondaryDark)
                                .multilineTextAlignment(.center)
                        }
                        .padding(AppSpacing.screenHorizontal)
                    } else if filtered.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(AppTypography.emptyStateIcon)
                                .foregroundStyle(AppColors.textSecondaryDark)
                            Text("No products found")
                                .font(AppTypography.heading3)
                                .foregroundStyle(AppColors.textPrimaryDark)
                        }
                    } else {
                        List(filtered, id: \.id) { product in
                            productRow(product)
                                .listRowBackground(Color.white.opacity(0.04))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Select Product")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name or SKU")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .task { await loadProducts() }
    }

    private func productRow(_ product: ProductDTO) -> some View {
        Button {
            selectedProduct = product
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.textPrimaryDark)

                    HStack(spacing: AppSpacing.xs) {
                        Text(product.sku)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.accent.opacity(0.8))
                        if let brand = product.brand {
                            Text("·  \(brand)")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondaryDark)
                        }
                    }
                }

                Spacer()

                Text(product.formattedPrice)
                    .font(AppTypography.statSmall)
                    .foregroundStyle(AppColors.textSecondaryDark)

                if selectedProduct?.id == product.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadProducts() async {
        isLoading = true
        error = nil
        do {
            let fetched: [ProductDTO] = try await SupabaseManager.shared.client
                .from("products")
                .select()
                .eq("is_active", value: true)
                .order("name", ascending: true)
                .execute()
                .value
            products = fetched
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        InventoryAddStockView()
    }
    .environment(AppState())
}
