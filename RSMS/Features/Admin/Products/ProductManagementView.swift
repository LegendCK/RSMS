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
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 50, height: 50)
                Image(systemName: product.imageName)
                    .font(AppTypography.catalogIcon)
                    .foregroundColor(AppColors.neutral600)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.xs) {
                    Text(product.categoryName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.purple)

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
                    modelContext.delete(product)
                    try? modelContext.save()
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
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        VStack(spacing: AppSpacing.xs) {
                            Text("Add Product")
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text("Create a new SKU in the catalog")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(.top, AppSpacing.xl)

                        // Category picker
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("CATEGORY")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, AppSpacing.screenHorizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.xs) {
                                    ForEach(categories) { cat in
                                        Button(action: { selectedCategory = cat.name }) {
                                            Text(cat.name)
                                                .font(AppTypography.caption)
                                                .foregroundColor(selectedCategory == cat.name ? AppColors.primary : AppColors.textSecondaryDark)
                                                .padding(.horizontal, AppSpacing.md)
                                                .padding(.vertical, AppSpacing.xs)
                                                .background(selectedCategory == cat.name ? AppColors.accent : AppColors.backgroundTertiary)
                                                .cornerRadius(AppSpacing.radiusSmall)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }

                        VStack(spacing: AppSpacing.lg) {
                            LuxuryTextField(placeholder: "Product Name", text: $name, icon: "tag")
                            LuxuryTextField(placeholder: "Brand", text: $brand, icon: "building")
                            LuxuryTextField(placeholder: "Description", text: $description, icon: "text.alignleft")
                            LuxuryTextField(placeholder: "Price (USD)", text: $price, icon: "dollarsign.circle")
                            LuxuryTextField(placeholder: "Stock Count", text: $stockCount, icon: "shippingbox")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Toggles
                        VStack(spacing: AppSpacing.sm) {
                            toggleRow(title: "Limited Edition", isOn: $isLimitedEdition)
                            toggleRow(title: "Featured Product", isOn: $isFeatured)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        PrimaryButton(title: "Create Product") {
                            createProduct()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(AppTypography.closeButton)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(AppColors.accent)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
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
