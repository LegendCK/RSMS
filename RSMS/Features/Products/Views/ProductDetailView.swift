//
//  ProductDetailView.swift
//  RSMS
//
//  Luxe product detail: swipeable image carousel, fullscreen gallery, variant selectors,
//  Add to Bag with haptics, and Buy Now direct-purchase sheet.
//

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    @Bindable var product: Product
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allCartItems: [CartItem]

    // Image gallery
    @State private var currentImageIndex = 0
    @State private var showGallery       = false

    // Bag/buy state
    @State private var addedToBag  = false
    @State private var showBuyNow  = false
    @State private var navigateToCart = false

    // Variant selection
    @State private var selectedColorIndex = 0
    @State private var selectedSizeIndex: Int? = nil

    // Guest auth gate
    @State private var showGuestGate   = false
    @State private var guestGateAction = "Add to Bag"

    // Add-to-bag animation
    @State private var bagIconScale: CGFloat = 1.0

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

    private var variantStockCount: Int {
        guard product.stockCount > 0 else { return 0 }
        let sizeIdx   = selectedSizeIndex ?? 0
        let hashInput = abs(product.id.uuidString.hashValue ^ (selectedColorIndex &* 997 &+ sizeIdx &* 13))
        switch hashInput % 5 {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return max(3, product.stockCount / 2)
        default: return product.stockCount
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

    private var cartItemQuantity: Int {
        allCartItems
            .first(where: { $0.customerEmail == appState.currentUserEmail && $0.productId == product.id })?
            .quantity ?? 0
    }

    // Product gallery images from synced catalog data.
    // Falls back to `imageName` when no multi-image payload exists.
    private var galleryImages: [String] {
        let list = product.imageList
        if !list.isEmpty { return list }
        return [product.imageName]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Image Carousel ──────────────────────────────
                    imageCarouselSection

                    // ── Product Info ────────────────────────────────
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        // Limited edition badge + brand + name + stars
                        headerSection

                        // Price + stock
                        priceStockRow

                        // Color picker
                        colorPickerSection

                        // Size picker
                        if needsSizeSelector { sizePickerSection }

                        GoldDivider()

                        // Description
                        descriptionSection

                        GoldDivider()

                        // Details
                        detailsSection

                        // Specifications
                        if !product.parsedAttributes.isEmpty {
                            GoldDivider()
                            specificationsSection
                        }

                        Spacer().frame(height: 28)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xl)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartShortcutButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .navigationDestination(isPresented: $navigateToCart) {
            CartView()
        }
        .fullScreenCover(isPresented: $showGallery) {
            ProductImageGalleryView(
                images: galleryImages,
                currentIndex: $currentImageIndex
            )
        }
        .sheet(isPresented: $showBuyNow) {
            BuyNowSheetView(
                product: product,
                selectedColor: colorVariants[selectedColorIndex],
                selectedSize: selectedSizeIndex.map { sizeVariants[$0] }
            )
        }
        .sheet(isPresented: $showGuestGate) {
            GuestAuthGateView(pendingAction: guestGateAction)
                .presentationDetents([.large])
        }
    }

    // MARK: - Image Carousel

    private var imageCarouselSection: some View {
        ZStack(alignment: .bottom) {
            // Swipeable image pager
            TabView(selection: $currentImageIndex) {
                ForEach(galleryImages.indices, id: \.self) { idx in
                    imageCell(source: galleryImages[idx])
                        .tag(idx)
                        .onTapGesture {
                            currentImageIndex = idx
                            showGallery = true
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 470)
            .background(AppColors.backgroundSecondary)

            // Limited edition badge
            if product.isLimitedEdition {
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
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, 44)
            }

            // Dot indicator + gallery hint
            VStack(spacing: 6) {
                if galleryImages.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(galleryImages.indices, id: \.self) { idx in
                            Capsule()
                                .fill(idx == currentImageIndex ? AppColors.accent : AppColors.neutral600.opacity(0.6))
                                .frame(
                                    width: idx == currentImageIndex ? 20 : 6,
                                    height: 6
                                )
                                .animation(.spring(response: 0.3), value: currentImageIndex)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.bottom, 14)

            // Thumbnail strip for quick angle selection
            if galleryImages.count > 1 {
                VStack {
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(galleryImages.indices, id: \.self) { idx in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentImageIndex = idx
                                    }
                                } label: {
                                    ProductArtworkView(
                                        imageSource: galleryImages[idx],
                                        fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock.fill" : "bag.fill",
                                        cornerRadius: 12
                                    )
                                    .frame(width: 58, height: 76)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                idx == currentImageIndex ? AppColors.accent : Color.white.opacity(0.3),
                                                lineWidth: idx == currentImageIndex ? 2 : 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                    .padding(.bottom, 44)
                }
            }

            // Rich overlay for legibility and premium contrast
            LinearGradient(
                colors: [Color.black.opacity(0.32), .clear, Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Page counter pill
            VStack {
                HStack {
                    Spacer()
                    Text("\(min(currentImageIndex + 1, galleryImages.count)) / \(galleryImages.count)")
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 14)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                Spacer()
            }

            // Expand icon (tap gesture area hint)
            HStack {
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
                    .onTapGesture { showGallery = true }
            }
        }
        .clipped()
        .onChange(of: galleryImages.count) { _, newCount in
            if newCount > 0 {
                currentImageIndex = min(currentImageIndex, newCount - 1)
            } else {
                currentImageIndex = 0
            }
        }
    }

    private func imageCell(source: String) -> some View {
        ProductArtworkView(
            imageSource: source,
            fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock.fill" : "bag.fill",
            cornerRadius: 0
        )
        .frame(maxWidth: .infinity)
        .frame(height: 470)
        .contentShape(Rectangle())
    }

    // MARK: - Header

    private var headerSection: some View {
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
                    Image(systemName: i < Int(product.rating) ? "star.fill" : (Double(i) < product.rating ? "star.leadinghalf.filled" : "star"))
                        .font(AppTypography.starRating)
                        .foregroundColor(AppColors.accent)
                }
                Text(String(format: "%.1f", product.rating))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Text("(\(Int.random(in: 28...312)) reviews)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.neutral600)
            }
        }
    }

    // MARK: - Price + Stock

    private var priceStockRow: some View {
        HStack(alignment: .bottom) {
            Text(product.formattedPrice)
                .font(AppTypography.priceDisplay)
                .foregroundColor(AppColors.textPrimaryDark)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(stockColor)
                    .frame(width: 7, height: 7)
                Text(stockLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedColorIndex)
            .animation(.easeInOut(duration: 0.2), value: selectedSizeIndex)
        }
    }

    // MARK: - Color Picker

    private var colorPickerSection: some View {
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
            .padding(.horizontal, -AppSpacing.screenHorizontal)
        }
    }

    // MARK: - Size Picker

    private var sizePickerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("SIZE")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Spacer()
                Button("Size Guide") {}
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(sizeVariants.indices, id: \.self) { idx in
                        sizeChip(index: idx)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.horizontal, -AppSpacing.screenHorizontal)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
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
    }

    // MARK: - Details

    private var detailsSection: some View {
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
    }

    // MARK: - Specifications

    private var specificationsSection: some View {
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

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                Circle()
                    .fill(stockColor)
                    .frame(width: 7, height: 7)
                Text(stockLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                if cartItemQuantity > 0 {
                    Text("\(cartItemQuantity) in bag")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.accent.opacity(0.08), in: Capsule())
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        product.isWishlisted.toggle()
                        try? modelContext.save()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: product.isWishlisted ? "heart.fill" : "heart")
                        .font(AppTypography.toolbarIcon)
                        .foregroundColor(product.isWishlisted ? AppColors.error : AppColors.textPrimaryDark)
                        .frame(width: AppSpacing.touchTarget, height: AppSpacing.touchTarget)
                        .background(AppColors.backgroundTertiary, in: RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                }
                .buttonStyle(.plain)

                Button(action: { handleAddToBag() }) {
                    HStack(spacing: 8) {
                        Image(systemName: cartItemQuantity > 0 ? "plus.circle.fill" : "bag.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .scaleEffect(bagIconScale)
                        Text(
                            variantStockCount > 0
                            ? (cartItemQuantity > 0 ? "Add Another" : "Add to Bag")
                            : "Out of Stock"
                        )
                        .font(AppTypography.buttonPrimary)
                    }
                    .foregroundColor(AppColors.textPrimaryLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.touchTarget)
                    .background(addedToBag ? AppColors.success : AppColors.accent)
                    .cornerRadius(AppSpacing.radiusMedium)
                    .animation(.spring(response: 0.3), value: addedToBag)
                }
                .opacity(variantStockCount > 0 ? 1.0 : 0.5)
                .disabled(variantStockCount == 0 && !appState.isGuest)
            }

            HStack(spacing: AppSpacing.sm) {
                Button(action: { handleBuyNow() }) {
                    Text("Buy Now")
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(variantStockCount > 0 ? AppColors.accent : AppColors.neutral600)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppColors.backgroundTertiary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(variantStockCount > 0 ? AppColors.accent : AppColors.neutral600.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(variantStockCount == 0 && !appState.isGuest)

                if cartItemQuantity > 0 {
                    Button(action: { navigateToCart = true }) {
                        Text("View Bag")
                            .font(AppTypography.buttonSecondary)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppColors.backgroundSecondary)
                            .cornerRadius(AppSpacing.radiusMedium)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.7)
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
        .background(
            AppColors.backgroundPrimary.opacity(0.9)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Variant Chips

    private func colorChip(index: Int) -> some View {
        let selected = selectedColorIndex == index
        return Button(action: {
            withAnimation(.spring(response: 0.25)) { selectedColorIndex = index }
        }) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .fill(selected ? AppColors.accent.opacity(0.08) : AppColors.backgroundSecondary)
                        .frame(width: 52, height: 52)
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .stroke(selected ? AppColors.accent : AppColors.border.opacity(0.5),
                                lineWidth: selected ? 1.5 : 1)
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
        return Button(action: {
            withAnimation(.spring(response: 0.25)) { selectedSizeIndex = index }
        }) {
            Text(sizeVariants[index])
                .font(AppTypography.label)
                .foregroundColor(selected ? AppColors.textPrimaryLight : AppColors.textPrimaryDark)
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        addProductToCart()
    }

    private func handleBuyNow() {
        if appState.isGuest {
            guestGateAction = "Buy Now"
            showGuestGate   = true
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showBuyNow = true
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

        withAnimation(.spring(response: 0.35)) { addedToBag = true }
        // Bounce the bag icon
        withAnimation(.spring(response: 0.2)) { bagIconScale = 1.3 }
        withAnimation(.spring(response: 0.2).delay(0.15)) { bagIconScale = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) { addedToBag = false }
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
