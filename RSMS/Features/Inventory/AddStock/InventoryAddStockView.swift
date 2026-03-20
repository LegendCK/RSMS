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
import SwiftData
import Supabase

// MARK: - Main View

struct InventoryAddStockView: View {
    @Query private var localProducts: [Product]

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddStockViewModel()
    @State private var showProductPicker = false
    @State private var stateVersion = 0
    @FocusState private var quantityFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        formCard

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
            sectionLabel("PRODUCT")
            productSelector
                .padding(.bottom, AppSpacing.xs)

            sectionLabel("QUANTITY")
            quantityField

            submitButton
                .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.cardPadding)
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
    }

    // MARK: - Product Selector

    private var productSelector: some View {
        Button { showProductPicker = true } label: {
            HStack(spacing: AppSpacing.md) {
                if let product = viewModel.selectedProduct {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "bag.fill")
                                .foregroundColor(AppColors.textSecondaryDark)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(AppTypography.label)
                            .foregroundStyle(AppColors.textPrimaryDark)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let brand = product.brand {
                                Text(brand)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondaryDark)
                                Text("•")
                                    .foregroundStyle(AppColors.neutral600)
                            }
                            Text(product.formattedPrice)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                } else {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppColors.accent.opacity(0.8))
                        Text("Search catalog...")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textSecondaryDark)
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.neutral500)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(
                                viewModel.selectedProduct != nil
                                    ? AppColors.accent.opacity(0.3)
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        }
    }

    // MARK: - Quantity Field (improved)

    private let presets = [1, 5, 10, 25, 50]

    private var quantityField: some View {
        VStack(spacing: AppSpacing.md) {

            // ── Preset chips ────────────────────────────────────────────
            HStack(spacing: AppSpacing.xs) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.quantity = preset
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(String(preset))
                            .font(AppTypography.label)
                            .foregroundStyle(viewModel.quantity == preset ? .white : AppColors.textSecondaryDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .fill(viewModel.quantity == preset
                                          ? AppColors.accent
                                          : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: viewModel.quantity)
                }
            }

            // ── Stepper row ─────────────────────────────────────────────
            HStack(spacing: 0) {
                // Minus
                Button(action: decrementQuantity) {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.quantity > 1 ? AppColors.accent : AppColors.neutral600)
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                }
                .disabled(viewModel.quantity <= 1)

                Spacer()

                // ✅ Fixed: use String(viewModel.quantity) — avoids literal-interpolation bug
                VStack(spacing: 2) {
                    Text(String(viewModel.quantity))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimaryDark)
                        .contentTransition(.numericText(value: Double(viewModel.quantity)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.quantity)

                    Text("units")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondaryDark)
                }

                Spacer()

                // Plus
                Button(action: incrementQuantity) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.quantity < 500 ? AppColors.accent : AppColors.neutral600)
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                }
                .disabled(viewModel.quantity >= 500)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )

            // ✅ Fixed: hint text uses String() instead of broken \() interpolation
            let itemWord = viewModel.quantity == 1 ? "item" : "items"
            Text("Creating " + String(viewModel.quantity) + " serialized " + itemWord + " with unique barcodes")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func incrementQuantity() {
        if viewModel.quantity < 500 {
            viewModel.quantity += 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func decrementQuantity() {
        if viewModel.quantity > 1 {
            viewModel.quantity -= 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Submit Button

    @ViewBuilder
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
                    // ✅ Fixed: String() avoids broken \() interpolation in Label titles
                    let itemWord = viewModel.quantity == 1 ? "Item" : "Items"
                    Label(
                        "Generate " + String(viewModel.quantity) + " " + itemWord,
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
        .disabled(!viewModel.canSubmit || localProducts.isEmpty)
        .opacity((viewModel.canSubmit && !localProducts.isEmpty) ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)

        if localProducts.isEmpty {
            Text("No products available. Please add products first.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.error)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, AppSpacing.xs)
        }
    }

    // MARK: - Success Panel

    private func successPanel(count: Int, items: [ProductItemDTO]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(count) + " items created successfully")
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

            Text("GENERATED BARCODES")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundStyle(AppColors.accent)

            LazyVStack(spacing: AppSpacing.xxs) {
                ForEach(items.indices, id: \.self) { index in
                    barcodeRow(index: index + 1, barcode: items[index].barcode, status: items[index].status)
                }
            }

            Button {
                NotificationCenter.default.post(name: Notification.Name("switchToScannerTab"), object: nil)
                dismiss()
            } label: {
                Label("Scan Now", systemImage: "barcode.viewfinder")
                    .font(AppTypography.label)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppColors.accent)
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.cardPadding)
        .managerCardSurface(cornerRadius: AppSpacing.radiusLarge)
    }

    private func barcodeRow(index: Int, barcode: String, status: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(String(index))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textSecondaryDark)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "barcode")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.accent.opacity(0.7))
                    Text(barcode)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimaryDark)
                }
            }

            Spacer()

            Button {
                UIPasteboard.general.string = barcode
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.accent)
                    .padding(8)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(Color.white.opacity(0.05))
        )
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
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
