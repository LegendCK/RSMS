//
//  ProductDetailView.swift
//  RSMS
//
//  Works with both local SwiftData `Product` and remote `ProductDTO`.
//  Only change from original: accepts `any ProductDisplayable` instead
//  of `@Bindable var product: Product`, and image section shows
//  AsyncImage when Supabase URLs are present.
//

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    let product: any ProductDisplayable

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allCartItems: [CartItem]

    @State private var addedToBag         = false
    @State private var buyNowTapped       = false
    @State private var selectedColorIndex = 0
    @State private var selectedSizeIndex: Int? = nil
    @State private var selectedImageIndex = 0
    @State private var showGuestGate      = false
    @State private var guestGateAction    = "Add to Bag"

    // MARK: - Variant data

    private var colorVariants: [String] {
        if let parsed = product.displayAttributes["colors"] {
            return parsed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let cat = product.displayProductType.lowercased()
        if cat.contains("jewelry")  { return ["Yellow Gold", "White Gold", "Rose Gold", "Platinum"] }
        if cat.contains("watch")    { return ["Steel", "Gold", "Black PVD", "Two-Tone"] }
        if cat.contains("shoe")     { return ["Black", "Tan", "White", "Nude"] }
        if cat.contains("clothing") { return ["Black", "White", "Navy", "Camel"] }
        return ["Noir", "Fauve", "Bordeaux", "Marine", "Étoupe"]
    }

    private var sizeVariants: [String] { ["XS", "S", "M", "L", "XL"] }

    private var needsSizeSelector: Bool {
        let sizeable = ["clothing", "shoes", "footwear", "ready-to-wear", "apparel"]
        return sizeable.contains { product.displayProductType.lowercased().contains($0) }
    }

    private var variantStockCount: Int {
        guard product.displayStockCount > 0 else { return 0 }
        let sizeIdx   = selectedSizeIndex ?? 0
        let hashInput = abs(product.displayName.hashValue ^ (selectedColorIndex &* 997 &+ sizeIdx &* 13))
        switch hashInput % 5 {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return max(3, product.displayStockCount / 2)
        default: return product.displayStockCount
        }
    }

    private var stockLabel: String {
        variantStockCount > 5 ? "In Stock" :
        variantStockCount > 0 ? "Only \(variantStockCount) left" : "Out of Stock"
    }

    private var stockColor: Color {
        variantStockCount > 5 ? AppColors.success :
        variantStockCount > 0 ? AppColors.warning : AppColors.error
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    imageSection

                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(product.displayBrand.uppercased())
                                .font(AppTypography.overline).tracking(3)
                                .foregroundColor(AppColors.accent)
                            Text(product.displayName)
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                            if product.displayRating > 0 {
                                HStack(spacing: AppSpacing.xxs) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < Int(product.displayRating) ? "star.fill" : "star")
                                            .font(AppTypography.starRating)
                                            .foregroundColor(AppColors.accent)
                                    }
                                    Text(String(format: "%.1f", product.displayRating))
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }

                        HStack(alignment: .bottom) {
                            Text(product.displayPrice)
                                .font(AppTypography.priceDisplay)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Spacer()
                            HStack(spacing: 5) {
                                Circle().fill(stockColor).frame(width: 6, height: 6)
                                Text(stockLabel)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            .animation(.easeInOut(duration: 0.2), value: selectedColorIndex)
                            .animation(.easeInOut(duration: 0.2), value: selectedSizeIndex)
                        }

                        // Colour picker
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: 4) {
                                Text("COLOUR")
                                    .font(AppTypography.overline).tracking(2)
                                    .foregroundColor(AppColors.accent)
                                Text("— \(colorVariants[selectedColorIndex])")
                                    .font(AppTypography.overline)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(colorVariants.indices, id: \.self) { idx in colorChip(index: idx) }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }

                        if needsSizeSelector {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("SIZE")
                                    .font(AppTypography.overline).tracking(2)
                                    .foregroundColor(AppColors.accent)
                                    .padding(.horizontal, AppSpacing.screenHorizontal)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppSpacing.xs) {
                                        ForEach(sizeVariants.indices, id: \.self) { idx in sizeChip(index: idx) }
                                    }
                                    .padding(.horizontal, AppSpacing.screenHorizontal)
                                }
                            }
                        }

                        GoldDivider()

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("DESCRIPTION")
                                .font(AppTypography.overline).tracking(2)
                                .foregroundColor(AppColors.accent)
                            Text(product.displayDescription)
                                .font(AppTypography.bodyLarge)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .lineSpacing(6)
                        }

                        GoldDivider()

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("DETAILS")
                                .font(AppTypography.overline).tracking(2)
                                .foregroundColor(AppColors.accent)
                            detailRow(label: "Brand",    value: product.displayBrand)
                            if !product.displayProductType.isEmpty {
                                detailRow(label: "Type", value: product.displayProductType)
                            }
                            if !product.displaySKU.isEmpty {
                                detailRow(label: "SKU",  value: product.displaySKU)
                            }
                            if !product.displayMaterial.isEmpty {
                                detailRow(label: "Material", value: product.displayMaterial)
                            }
                            if !product.displayOrigin.isEmpty {
                                detailRow(label: "Origin", value: product.displayOrigin)
                            }
                            detailRow(label: "Availability",
                                      value: variantStockCount > 0 ? "Available" : "Sold Out")
                            if product.displayIsLimitedEdition {
                                detailRow(label: "Collection", value: "Limited Edition")
                            }
                        }

                        if !product.displayAttributes.isEmpty {
                            GoldDivider()
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("SPECIFICATIONS")
                                    .font(AppTypography.overline).tracking(2)
                                    .foregroundColor(AppColors.accent)
                                ForEach(
                                    product.displayAttributes.sorted(by: { $0.key < $1.key }),
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

            // Bottom action bar
            VStack {
                Spacer()
                VStack(spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.md) {

                        // Wishlist — only for local SwiftData products
                        if let localProduct = product as? Product {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    localProduct.isWishlisted.toggle()
                                    try? modelContext.save()
                                }
                            }) {
                                Image(systemName: localProduct.isWishlisted ? "heart.fill" : "heart")
                                    .font(AppTypography.toolbarIcon)
                                    .foregroundColor(localProduct.isWishlisted ? AppColors.error : AppColors.textPrimaryDark)
                                    .frame(width: AppSpacing.touchTarget + 8, height: AppSpacing.touchTarget + 8)
                                    .background(AppColors.backgroundTertiary)
                                    .cornerRadius(AppSpacing.radiusMedium)
                            }
                        }

                        PrimaryButton(
                            title: addedToBag
                                ? "Added to Bag ✓"
                                : (variantStockCount > 0 ? "Add to Bag" : "Out of Stock")
                        ) { handleAddToBag() }
                        .opacity(variantStockCount > 0 ? 1.0 : 0.5)
                        .disabled(variantStockCount == 0 && !appState.isGuest)
                    }

                    Button(action: { handleBuyNow() }) {
                        Text(buyNowTapped ? "Opening Bag…" : "Buy Now")
                            .font(AppTypography.buttonSecondary)
                            .foregroundColor(variantStockCount > 0 ? AppColors.accent : AppColors.neutral600)
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

    // MARK: - Image section

    @ViewBuilder
    private var imageSection: some View {
        let urls = product.displayImageURLs

        if urls.isEmpty {
            // Original SF Symbol placeholder — unchanged from before
            ZStack {
                AppColors.backgroundSecondary.frame(height: 380)
                Image(systemName: product.displayFallbackIcon)
                    .font(AppTypography.iconDecorative)
                    .foregroundColor(AppColors.neutral600)
                if product.displayIsLimitedEdition {
                    VStack {
                        HStack {
                            Text("LIMITED EDITION")
                                .font(AppTypography.overline).tracking(2)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(AppColors.accent).cornerRadius(4)
                            Spacer()
                        }
                        .padding(AppSpacing.screenHorizontal)
                        Spacer()
                    }
                    .padding(.top, AppSpacing.md)
                }
            }
        } else {
            // Supabase Storage image gallery
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    AppColors.backgroundSecondary.frame(height: 380)
                    AsyncImage(url: urls[selectedImageIndex]) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit().frame(height: 380)
                        case .failure:
                            Image(systemName: product.displayFallbackIcon)
                                .font(AppTypography.iconDecorative)
                                .foregroundColor(AppColors.neutral600)
                        case .empty:
                            ProgressView().tint(AppColors.accent)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    if product.displayIsLimitedEdition {
                        VStack {
                            HStack {
                                Text("LIMITED EDITION")
                                    .font(AppTypography.overline).tracking(2)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(AppColors.accent).cornerRadius(4)
                                Spacer()
                            }
                            .padding(AppSpacing.screenHorizontal)
                            Spacer()
                        }
                        .padding(.top, AppSpacing.md)
                    }
                }
                .frame(height: 380)

                if urls.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(urls.indices, id: \.self) { i in
                                AsyncImage(url: urls[i]) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Color(AppColors.backgroundSecondary)
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                                        .stroke(selectedImageIndex == i ? AppColors.accent : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedImageIndex = i }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                }
            }
        }
    }

    // MARK: - Variant chips

    private func colorChip(index: Int) -> some View {
        let selected = selectedColorIndex == index
        return Button(action: { withAnimation(.spring(response: 0.25)) { selectedColorIndex = index } }) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .fill(AppColors.backgroundSecondary).frame(width: 52, height: 52)
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .stroke(selected ? AppColors.accent : AppColors.border.opacity(0.5),
                                lineWidth: selected ? 2 : 1).frame(width: 52, height: 52)
                    Text(String(colorVariants[index].prefix(1)))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selected ? AppColors.accent : AppColors.neutral700)
                }
                Text(colorVariants[index])
                    .font(AppTypography.pico)
                    .foregroundColor(selected ? AppColors.accent : AppColors.textSecondaryDark)
                    .lineLimit(1).frame(width: 56)
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
                .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.xs)
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
        if appState.isGuest { guestGateAction = "Add to Bag"; showGuestGate = true; return }
        addProductToCart()
    }

    private func handleBuyNow() {
        guard variantStockCount > 0 || appState.isGuest else { return }
        if appState.isGuest { guestGateAction = "Buy Now"; showGuestGate = true; return }
        addProductToCart()
        withAnimation(.spring(response: 0.3)) { buyNowTapped = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { buyNowTapped = false } }
    }

    private func addProductToCart() {
        guard let localProduct = product as? Product else { return }
        let email = appState.currentUserEmail
        if let existing = allCartItems.first(where: {
            $0.customerEmail == email && $0.productId == localProduct.id
        }) {
            existing.quantity += 1
        } else {
            modelContext.insert(CartItem(
                customerEmail: email,
                productId: localProduct.id,
                productName: localProduct.name,
                productImageName: localProduct.imageName,
                productBrand: localProduct.brand,
                unitPrice: localProduct.price
            ))
        }
        try? modelContext.save()
        withAnimation(.spring(response: 0.3)) { addedToBag = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { addedToBag = false } }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppTypography.bodyMedium).foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimaryDark)
        }
    }
}
