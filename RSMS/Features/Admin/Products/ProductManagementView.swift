//
//  ProductManagementView.swift
//  infosys2
//
//  Corporate Admin product catalog management — SKUs, categories, pricing.
//

import SwiftUI
import SwiftData

struct ProductManagementView: View {
    @Query(sort: \Product.createdAt, order: .reverse) private var allProducts: [Product]
    @Query(sort: \Category.displayOrder) private var allCategories: [Category]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateProduct = false
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil

    private var filteredProducts: [Product] {
        var products = allProducts
        if let cat = selectedCategory {
            products = products.filter { $0.categoryName == cat }
        }
        if !searchText.isEmpty {
            products = products.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
        return products
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.neutral500)
                        TextField("Search products...", text: $searchText)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusMedium)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.xs) {
                            categoryChip(name: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(allCategories) { cat in
                                categoryChip(name: cat.name, isSelected: selectedCategory == cat.name) {
                                    selectedCategory = cat.name
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                    .padding(.vertical, AppSpacing.sm)

                    // Stats bar
                    HStack {
                        Text("\(filteredProducts.count) products")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                        Text("\(allCategories.count) categories")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.accent)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.xs)

                    // Product list
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.xs) {
                            ForEach(filteredProducts) { product in
                                productRow(product)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Products")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateProduct = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreateProduct) {
                CreateProductSheet(modelContext: modelContext, categories: allCategories)
            }
        }
    }

    private func categoryChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(AppTypography.caption)
                .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(isSelected ? AppColors.accent : AppColors.backgroundTertiary)
                .cornerRadius(AppSpacing.radiusSmall)
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Image placeholder
            ProductArtworkView(
                imageSource: product.imageName,
                fallbackSymbol: "bag.fill",
                cornerRadius: AppSpacing.radiusSmall
            )
            .frame(width: 50, height: 50)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.xs) {
                    Text(product.categoryName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)

                    if product.isLimitedEdition {
                        Text("LIMITED")
                            .font(AppTypography.pico)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.accent.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            // Price & stock
            VStack(alignment: .trailing, spacing: 2) {
                Text(product.formattedPrice)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)

                HStack(spacing: 3) {
                    Circle()
                        .fill(product.stockCount > 5 ? AppColors.success :
                              product.stockCount > 0 ? AppColors.warning : AppColors.error)
                        .frame(width: 5, height: 5)
                    Text("\(product.stockCount) in stock")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            // Menu
            Menu {
                Button(action: {}) {
                    Label("Edit Product", systemImage: "pencil")
                }
                Button(action: {}) {
                    Label("Update Price", systemImage: "dollarsign.circle")
                }
                Button(action: {}) {
                    Label("Adjust Stock", systemImage: "shippingbox")
                }
                Divider()
                Button(role: .destructive, action: {
                    Task {
                        try? await CatalogService.shared.deleteProduct(id: product.id)
                        modelContext.delete(product)
                        try? modelContext.save()
                    }
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppTypography.alertIcon)
                    .foregroundColor(AppColors.neutral500)
                    .frame(width: 32, height: AppSpacing.touchTarget)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

// MARK: - Create Product Sheet

struct CreateProductSheet: View {
    let modelContext: ModelContext
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = "Maison Luxe"
    @State private var description = ""
    @State private var price = ""
    @State private var stockCount = ""
    @State private var selectedCategory = ""
    @State private var isLimitedEdition = false
    @State private var isFeatured = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppColors.accent.opacity(0.10))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(AppColors.accent)
                            }
                            Text("Add Product")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Create a new SKU in the catalog")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 24)

                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories.filter { !$0.name.isEmpty }) { cat in
                                        Button(action: { selectedCategory = cat.name }) {
                                            Text(cat.name)
                                                .font(.system(size: 13, weight: selectedCategory == cat.name ? .semibold : .regular))
                                                .foregroundColor(selectedCategory == cat.name ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 9)
                                                .background(selectedCategory == cat.name ? AppColors.accent : Color(uiColor: .secondarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(selectedCategory == cat.name ? Color.clear : Color(uiColor: .systemGray4), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Product details
                        productFormSection {
                            fieldRow(label: "Product Name", icon: "tag") {
                                TextField("Required", text: $name)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, 52)
                            fieldRow(label: "Brand", icon: "building") {
                                TextField("Maison Luxe", text: $brand)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, 52)
                            fieldRow(label: "Price (INR)", icon: "indianrupeesign.circle") {
                                TextField("0.00", text: $price)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                            }
                            Divider().padding(.leading, 52)
                            fieldRow(label: "Stock Count", icon: "shippingbox") {
                                TextField("0", text: $stockCount)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                            }
                        }

                        // Description
                        productFormSection {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 15, weight: .light))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 24)
                                    .padding(.top, 2)
                                TextField("Description (optional)", text: $description, axis: .vertical)
                                    .font(.system(size: 15))
                                    .lineLimit(3...6)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        // Toggles
                        productFormSection {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .light))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 24)
                                Text("Limited Edition")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Spacer()
                                Toggle("", isOn: $isLimitedEdition)
                                    .tint(AppColors.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            Divider().padding(.leading, 52)
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 15, weight: .light))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 24)
                                Text("Featured Product")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Spacer()
                                Toggle("", isOn: $isFeatured)
                                    .tint(AppColors.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        // Create button
                        Button {
                            createProduct()
                        } label: {
                            Text("Create Product")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AppColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .principal) {
                    Text("ADD PRODUCT")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private func productFormSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 20)
    }

    private func fieldRow<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            content()
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func createProduct() {
        guard !name.isEmpty, !selectedCategory.isEmpty,
              let priceVal = Double(price), priceVal > 0,
              let stockVal = Int(stockCount) else {
            errorMessage = "Please fill in all required fields with valid values."
            showError = true
            return
        }

        let product = Product(
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            description: description,
            price: priceVal,
            categoryName: selectedCategory,
            isLimitedEdition: isLimitedEdition,
            isFeatured: isFeatured,
            stockCount: stockVal
        )

        modelContext.insert(product)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ProductManagementView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
