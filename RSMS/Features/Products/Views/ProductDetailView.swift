//
//  ProductDetailView.swift
//  infosys2
//
//  Full product detail with image, price, variant selectors, description, and wishlist toggle.
//  Guests can browse freely; Add to Bag / Buy Now triggers an auth gate.
//

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    @Bindable var product: Product
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allCartItems: [CartItem]

    // Bag state
    @State private var addedToBag     = false
    @State private var buyNowTapped   = false

    // Variant selection
    @State private var selectedColorIndex = 0
    @State private var selectedSizeIndex: Int? = nil

    // Guest auth gate
    @State private var showGuestGate       = false
    @State private var guestGateAction     = "Add to Bag"

    // MARK: - Variant data

    private var colorVariants: [String] {
        if let parsed = product.parsedAttributes["colors"] {
            return parsed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let cat = product.categoryName.lowercased()
        if cat.contains("jewelry")  { return ["Yellow Gold", "White Gold", "Rose Gold", "Platinum"] }
        if cat.contains("watch")    { return ["Steel", "Gold", "Black PVD", "Two-Tone"] }
        if cat.contains("shoe") || cat.contains("footwear") { return ["Black", "Tan", "White", "Nude"] }
        if cat.contains("clothing") || cat.contains("apparel") { return ["Black", "White", "Navy", "Camel"] }
        // Bags / leather goods / default
        return ["Noir", "Fauve", "Bordeaux", "Marine", "Étoupe"]
    }

    private var sizeVariants: [String] {
        let cat = product.categoryName.lowercased()
        if cat.contains("shoe") || cat.contains("footwear") { return ["36", "37", "38", "39", "40", "41"] }
        return ["XS", "S", "M", "L", "XL"]
    }

    private var needsSizeSelector: Bool {
        let sizeable = ["clothing", "shoes", "footwear", "ready-to-wear", "apparel"]
        return sizeable.contains { product.categoryName.lowercased().contains($0) }
    }

    /// Deterministic per-variant stock derived from the product's total stockCount.
    /// Ensures instant UI updates when the user changes a variant.
    private var variantStockCount: Int {
        guard product.stockCount > 0 else { return 0 }
        let sizeIdx   = selectedSizeIndex ?? 0
        let hashInput = abs(product.id.uuidString.hashValue ^ (selectedColorIndex &* 997 &+ sizeIdx &* 13))
        switch hashInput % 5 {
        case 0: return 0                              // out of stock for this combo
        case 1: return 1                              // only 1 left
        case 2: return 2                              // only 2 left
        case 3: return max(3, product.stockCount / 2) // limited
        default: return product.stockCount            // full stock
        }
    }

    private var stockLabel: String {
        variantStockCount > 5  ? "In Stock" :
        variantStockCount > 0  ? "Only \(variantStockCount) left" :
                                 "Out of Stock"
    }

    private var stockColor: Color {
        variantStockCount > 5  ? AppColors.success :
        variantStockCount > 0  ? AppColors.warning :
                                 AppColors.error
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Product image area
                    ZStack {
                        AppColors.backgroundSecondary.frame(height: 380)

                        Image(systemName: product.imageName)
                            .font(AppTypography.iconDecorative)
                            .foregroundColor(AppColors.neutral600)

                        if product.isLimitedEdition {
                            VStack {
                                HStack {
                                    Text("LIMITED EDITION")
                                        .font(AppTypography.overline)
                                        .tracking(2)
                                        .foregroundColor(AppColors.textPrimaryLight)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.accent)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                .padding(AppSpacing.screenHorizontal)
                                Spacer()
                            }
                            .padding(.top, AppSpacing.md)
                        }
                    }

                    // Product info
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        // Brand, name, rating
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(product.brand.uppercased())
                                .font(AppTypography.overline)
                                .tracking(3)
                                .foregroundColor(AppColors.accent)

                            Text(product.name)
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)

                            HStack(spacing: AppSpacing.xxs) {
                                ForEach(0..<5) { i in
                                    Image(systemName: i < Int(product.rating) ? "star.fill" : "star")
                                        .font(AppTypography.starRating)
                                        .foregroundColor(AppColors.accent)
                                }
                                Text(String(format: "%.1f", product.rating))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }

                        // Price + live stock status
                        HStack(alignment: .bottom) {
                            Text(product.formattedPrice)
                                .font(AppTypography.priceDisplay)
                                .foregroundColor(AppColors.textPrimaryDark)

                            Spacer()

                            HStack(spacing: 5) {
                                Circle()
                                    .fill(stockColor)
                                    .frame(width: 6, height: 6)
                                Text(stockLabel)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            .animation(.easeInOut(duration: 0.2), value: selectedColorIndex)
                            .animation(.easeInOut(duration: 0.2), value: selectedSizeIndex)
                        }

                        // MARK: Color picker
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: 4) {
                                Text("COLOUR")
                                    .font(AppTypography.overline)
                                    .tracking(2)
                                    .foregroundColor(AppColors.accent)
                                Text("— \(colorVariants[selectedColorIndex])")
                                    .font(AppTypography.overline)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(colorVariants.indices, id: \.self) { idx in
                                        colorChip(index: idx)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }

                        // MARK: Size picker (clothing & shoes only)
                        if needsSizeSelector {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("SIZE")
                                    .font(AppTypography.overline)
                                    .tracking(2)
                                    .foregroundColor(AppColors.accent)
                                    .padding(.horizontal, AppSpacing.screenHorizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppSpacing.xs) {
                                        ForEach(sizeVariants.indices, id: \.self) { idx in
                                            sizeChip(index: idx)
                                        }
                                    }
                                    .padding(.horizontal, AppSpacing.screenHorizontal)
                                }
                            }
                        }

                        GoldDivider()

                        // Description
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("DESCRIPTION")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            Text(product.productDescription)
                                .font(AppTypography.bodyLarge)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .lineSpacing(6)
                        }

                        GoldDivider()

                        // Details
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("DETAILS")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            detailRow(label: "Brand",    value: product.brand)
                            detailRow(label: "Category", value: product.categoryName)
                            if !product.productTypeName.isEmpty {
                                detailRow(label: "Type", value: product.productTypeName)
                            }
                            if !product.sku.isEmpty {
                                detailRow(label: "SKU", value: product.sku)
                            }
                            if !product.material.isEmpty {
                                detailRow(label: "Material", value: product.material)
                            }
                            if !product.countryOfOrigin.isEmpty {
                                detailRow(label: "Origin", value: product.countryOfOrigin)
                            }
                            detailRow(label: "Availability",
                                      value: variantStockCount > 0 ? "Available" : "Sold Out")
                            if product.isLimitedEdition {
                                detailRow(label: "Collection", value: "Limited Edition")
                            }
                        }

                        // Specifications
                        if !product.parsedAttributes.isEmpty {
                            GoldDivider()

                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("SPECIFICATIONS")
                                    .font(AppTypography.overline)
                                    .tracking(2)
                                    .foregroundColor(AppColors.accent)

                                ForEach(
                                    product.parsedAttributes.sorted(by: { $0.key < $1.key }),
                                    id: \.key
                                ) { key, value in
                                    detailRow(label: key.capitalized, value: value)
                                }
                            }
                        }

                        Spacer().frame(height: AppSpacing.xxl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xl)
                }
            }

            // MARK: Bottom action bar
            VStack {
                Spacer()

                VStack(spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.md) {
                        // Wishlist — always available
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                product.isWishlisted.toggle()
                                try? modelContext.save()
                            }
                        }) {
                            Image(systemName: product.isWishlisted ? "heart.fill" : "heart")
                                .font(AppTypography.toolbarIcon)
                                .foregroundColor(product.isWishlisted ? AppColors.error : AppColors.textPrimaryDark)
                                .frame(width: AppSpacing.touchTarget + 8, height: AppSpacing.touchTarget + 8)
                                .background(AppColors.backgroundTertiary)
                                .cornerRadius(AppSpacing.radiusMedium)
                        }

                        // Add to Bag — gated for guests
                        PrimaryButton(
                            title: addedToBag
                                ? "Added to Bag ✓"
                                : (variantStockCount > 0 ? "Add to Bag" : "Out of Stock")
                        ) {
                            handleAddToBag()
                        }
                        .opacity(variantStockCount > 0 ? 1.0 : 0.5)
                        .disabled(variantStockCount == 0 && !appState.isGuest)
                    }

                    // Buy Now — gated for guests; direct checkout for members
                    Button(action: { handleBuyNow() }) {
                        Text(buyNowTapped ? "Opening Bag…" : "Buy Now")
                            .font(AppTypography.buttonSecondary)
                            .foregroundColor(variantStockCount > 0
                                ? AppColors.accent
                                : AppColors.neutral600)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xs)
                    }
                    .disabled(variantStockCount == 0 && !appState.isGuest)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
                .background(
                    AppColors.backgroundPrimary
                        .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGuestGate) {
            GuestAuthGateView(pendingAction: guestGateAction)
                .presentationDetents([.large])
        }
    }

    // MARK: - Variant chips

    private func colorChip(index: Int) -> some View {
        let selected = selectedColorIndex == index
        return Button(action: { withAnimation(.spring(response: 0.25)) { selectedColorIndex = index } }) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .fill(AppColors.backgroundSecondary)
                        .frame(width: 52, height: 52)
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .stroke(selected ? AppColors.accent : AppColors.border.opacity(0.5),
                                lineWidth: selected ? 2 : 1)
                        .frame(width: 52, height: 52)
                    Text(String(colorVariants[index].prefix(1)))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selected ? AppColors.accent : AppColors.neutral700)
                }

                Text(colorVariants[index])
                    .font(AppTypography.pico)
                    .foregroundColor(selected ? AppColors.accent : AppColors.textSecondaryDark)
                    .lineLimit(1)
                    .frame(width: 56)
            }
        }
        .buttonStyle(.plain)
    }

    private func sizeChip(index: Int) -> some View {
        let selected = selectedSizeIndex == index
        return Button(action: { withAnimation(.spring(response: 0.25)) { selectedSizeIndex = index } }) {
            Text(sizeVariants[index])
                .font(AppTypography.label)
                .foregroundColor(selected ? AppColors.primary : AppColors.textPrimaryDark)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(selected ? AppColors.accent : AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .stroke(selected ? AppColors.accent : AppColors.border.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleAddToBag() {
        guard variantStockCount > 0 || appState.isGuest else { return }
        if appState.isGuest {
            guestGateAction = "Add to Bag"
            showGuestGate   = true
            return
        }
        addProductToCart()
    }

    private func handleBuyNow() {
        guard variantStockCount > 0 || appState.isGuest else { return }
        if appState.isGuest {
            guestGateAction = "Buy Now"
            showGuestGate   = true
            return
        }
        addProductToCart()
        withAnimation(.spring(response: 0.3)) { buyNowTapped = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { buyNowTapped = false }
        }
    }

    private func addProductToCart() {
        let email = appState.currentUserEmail
        if let existing = allCartItems.first(where: { $0.customerEmail == email && $0.productId == product.id }) {
            existing.quantity += 1
        } else {
            let item = CartItem(
                customerEmail: email,
                productId: product.id,
                productName: product.name,
                productImageName: product.imageName,
                productBrand: product.brand,
                unitPrice: product.price
            )
            modelContext.insert(item)
        }
        try? modelContext.save()

        withAnimation(.spring(response: 0.3)) { addedToBag = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { addedToBag = false }
        }
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(product: Product(
            name: "Classic Flap Bag",
            brand: "Maison Luxe",
            description: "Timeless quilted leather bag with signature gold chain strap.",
            price: 4850,
            categoryName: "Leather Goods",
            imageName: "bag.fill",
            isLimitedEdition: true,
            isFeatured: true,
            rating: 4.9,
            stockCount: 3,
            productTypeName: "Handbags",
            attributes: "{\"leather\":\"Lambskin\",\"hardware\":\"Gold-Tone\"}"
        ))
    }
    .modelContainer(for: Product.self, inMemory: true)
    .environment(AppState())
}
