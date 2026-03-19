//
//  ProductDetailView.swift
//  RSMS
//
//  Luxe product detail: swipeable image carousel, fullscreen gallery, variant selectors,
//  Add to Bag with haptics, and Buy Now direct-purchase sheet.
//

import SwiftUI
import SwiftData
import Supabase

enum ProductDetailMode {
    case storefront
    case adminCatalog
}

struct ProductDetailView: View {
    @Bindable var product: Product
    let mode: ProductDetailMode
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allCartItems: [CartItem]
    @Query(sort: \Category.displayOrder) private var allCategories: [Category]

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

    // Inventory Items
    @State private var remoteItems: [ProductItemDTO] = []
    @State private var isFetchingItems = false
    @State private var showAdminManageSheet = false

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

    private var isAdminMode: Bool {
        mode == .adminCatalog
    }

    init(product: Product, mode: ProductDetailMode = .storefront) {
        self.product = product
        self.mode = mode
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Image Carousel ──────────────────────────────
                    imageCarouselSection

                    // ── Product Info ────────────────────────────────
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        headerSection
                        priceStockRow
                        if !isAdminMode {
                            colorPickerSection
                            if needsSizeSelector { sizePickerSection }
                        }

                        Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1)
                        descriptionSection
                        Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1)
                        detailsSection

                        if !product.parsedAttributes.isEmpty {
                            Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1)
                            specificationsSection
                        }

                        Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1)
                        inventorySection

                        Spacer().frame(height: 28)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xl)
                }
            }
        }
        .task {
            await fetchInventoryItems()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isAdminMode {
                    Button(action: { showAdminManageSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Manage")
                                .font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.accent)
                    }
                } else {
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                product.isWishlisted.toggle()
                                try? modelContext.save()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: product.isWishlisted ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(product.isWishlisted ? AppColors.accent : .black)
                        }
                        CartShortcutButton()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isAdminMode {
                adminManageBar
            } else {
                bottomActionBar
            }
        }
        .navigationDestination(isPresented: $navigateToCart) {
            if !isAdminMode {
                CartView()
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            ProductImageGalleryView(
                images: galleryImages,
                currentIndex: $currentImageIndex
            )
        }
        .sheet(isPresented: $showBuyNow) {
            if !isAdminMode {
                BuyNowSheetView(
                    product: product,
                    selectedColor: colorVariants[selectedColorIndex],
                    selectedSize: selectedSizeIndex.map { sizeVariants[$0] }
                )
            }
        }
        .sheet(isPresented: $showGuestGate) {
            if !isAdminMode {
                GuestAuthGateView(pendingAction: guestGateAction)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showAdminManageSheet) {
            if isAdminMode {
                AdminProductManageSheet(product: product, categories: allCategories)
            }
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
                                        cornerRadius: 0
                                    )
                                    .frame(width: 58, height: 76)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                idx == currentImageIndex ? AppColors.accent : Color.white.opacity(0.35),
                                                lineWidth: idx == currentImageIndex ? 2.5 : 1
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
        VStack(alignment: .leading, spacing: 6) {
            Text(product.brand.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(3)
                .foregroundColor(AppColors.accent)

            Text(product.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.black)

            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    Image(systemName: i < Int(product.rating) ? "star.fill" : (Double(i) < product.rating ? "star.leadinghalf.filled" : "star"))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.accent)
                }
                Text(String(format: "%.1f", product.rating))
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.black.opacity(0.5))
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

    // MARK: - Inventory Items

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("INVENTORY ITEMS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            if isFetchingItems {
                ProgressView().tint(AppColors.accent)
            } else if remoteItems.isEmpty {
                Text("No items in stock.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                ForEach(remoteItems) { item in
                    HStack {
                        Image(systemName: "barcode")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text(item.barcode)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(AppColors.textPrimaryDark)
                        Spacer()
                        Text(item.itemStatus.displayName)
                            .font(AppTypography.nano)
                            .foregroundColor(item.itemStatus == .inStock ? AppColors.success : AppColors.textSecondaryDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (item.itemStatus == .inStock ? AppColors.success : AppColors.textSecondaryDark).opacity(0.12)
                            )
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var adminManageBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: { showAdminManageSheet = true }) {
                    Label("Manage Product", systemImage: "slider.horizontal.3")
                        .font(AppTypography.buttonPrimary)
                        .foregroundColor(AppColors.textPrimaryLight)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(
            Color.white
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            // Stock + cart indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(stockColor)
                    .frame(width: 6, height: 6)
                Text(stockLabel)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.black.opacity(0.55))
                Spacer()
                if cartItemQuantity > 0 {
                    Button(action: { navigateToCart = true }) {
                        Text("\(cartItemQuantity) in bag — View")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)

            HStack(spacing: 10) {
                // Add to Bag — primary maroon
                Button(action: { handleAddToBag() }) {
                    Text(
                        variantStockCount > 0
                        ? (addedToBag ? "Added" : (cartItemQuantity > 0 ? "Add Another" : "Add to Bag"))
                        : "Out of Stock"
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(addedToBag ? AppColors.success : AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .animation(.spring(response: 0.3), value: addedToBag)
                    .scaleEffect(bagIconScale)
                }
                .opacity(variantStockCount > 0 ? 1.0 : 0.4)
                .disabled(variantStockCount == 0 && !appState.isGuest)

                // Buy Now — maroon outlined
                Button(action: { handleBuyNow() }) {
                    Text("Buy Now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(variantStockCount > 0 ? AppColors.accent : AppColors.accent.opacity(0.3))
                        .frame(width: 118)
                        .frame(height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(variantStockCount > 0 ? AppColors.accent : AppColors.accent.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .disabled(variantStockCount == 0 && !appState.isGuest)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(
            Color.white
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
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

    private func fetchInventoryItems() async {
        isFetchingItems = true
        defer { isFetchingItems = false }
        do {
            let items: [ProductItemDTO] = try await SupabaseManager.shared.client
                .from("product_items")
                .select("id, product_id, barcode, serial_number, status, store_id, created_at, products(*)")
                .eq("product_id", value: product.id.uuidString)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            remoteItems = items
        } catch {
            print("[ProductDetailView] Failed to fetch items:", error)
        }
    }
}

private struct AdminProductManageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let product: Product
    let categories: [Category]

    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var priceText: String = ""
    @State private var stockText: String = ""
    @State private var descriptionText: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedCollectionId: UUID?
    @State private var isLimitedEdition = false
    @State private var isFeatured = false
    @State private var remoteCategories: [CategoryDTO] = []
    @State private var remoteCollections: [BrandCollectionDTO] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    LuxuryTextField(placeholder: "Product Name", text: $name)
                    LuxuryTextField(placeholder: "Brand", text: $brand)
                    LuxuryTextField(placeholder: "Price (INR)", text: $priceText)
                        .keyboardType(.decimalPad)
                    LuxuryTextField(placeholder: "Stock Count", text: $stockText)
                        .keyboardType(.numberPad)

                    Menu {
                        ForEach(categories) { category in
                            Button(category.name) { selectedCategoryName = category.name }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategoryName.isEmpty ? "Select Category" : selectedCategoryName)
                                .foregroundColor(selectedCategoryName.isEmpty ? AppColors.neutral500 : AppColors.textPrimaryDark)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(AppColors.neutral500)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                    }

                    Menu {
                        Button("No Collection") { selectedCollectionId = nil }
                        Divider()
                        ForEach(remoteCollections.filter(\.isActive)) { collection in
                            Button(collection.name) { selectedCollectionId = collection.id }
                        }
                    } label: {
                        HStack {
                            Text(selectedCollectionName)
                                .foregroundColor(selectedCollectionId == nil ? AppColors.neutral500 : AppColors.textPrimaryDark)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(AppColors.neutral500)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                    }

                    TextField("Description", text: $descriptionText, axis: .vertical)
                        .lineLimit(4...8)
                        .padding(AppSpacing.sm)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)

                    Toggle("Limited Edition", isOn: $isLimitedEdition)
                        .tint(AppColors.accent)
                    Toggle("Featured", isOn: $isFeatured)
                        .tint(AppColors.accent)

                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .font(AppTypography.buttonPrimary)
                            .foregroundColor(AppColors.textPrimaryLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.accent)
                            .cornerRadius(AppSpacing.radiusMedium)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .background(AppColors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Manage Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .onAppear {
                name = product.name
                brand = product.brand
                priceText = String(format: "%.2f", product.price)
                stockText = "\(product.stockCount)"
                descriptionText = product.productDescription
                selectedCategoryName = product.categoryName
                isLimitedEdition = product.isLimitedEdition
                isFeatured = product.isFeatured
            }
            .task { await loadRemoteMetadata() }
        }
    }

    private func saveChanges() {
        let parsedPrice = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? product.price
        let parsedStock = Int(stockText) ?? product.stockCount
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                _ = try await CatalogService.shared.updateProduct(
                    id: product.id,
                    sku: product.sku,
                    name: trimmedName,
                    brand: trimmedBrand,
                    categoryId: mappedCategoryId,
                    collectionId: selectedCollectionId,
                    price: parsedPrice,
                    costPrice: nil,
                    description: trimmedDescription,
                    barcode: nil,
                    isActive: true
                )

                product.name = trimmedName
                product.brand = trimmedBrand
                product.price = parsedPrice
                product.stockCount = max(parsedStock, 0)
                product.productDescription = trimmedDescription
                if !selectedCategoryName.isEmpty {
                    product.categoryName = selectedCategoryName
                }
                product.productTypeName = selectedCollectionName == "No Collection" ? "" : selectedCollectionName
                product.isLimitedEdition = isLimitedEdition
                product.isFeatured = isFeatured

                try? modelContext.save()
                dismiss()
            } catch {
                await MainActor.run {
                    errorMessage = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private var mappedCategoryId: UUID? {
        remoteCategories.first(where: { $0.name == selectedCategoryName })?.id
    }

    private var selectedCollectionName: String {
        guard let selectedCollectionId else { return "No Collection" }
        return remoteCollections.first(where: { $0.id == selectedCollectionId })?.name ?? "No Collection"
    }

    private func loadRemoteMetadata() async {
        do {
            async let categories = CatalogService.shared.fetchCategories()
            async let collections = CatalogService.shared.fetchCollections()
            let (loadedCategories, loadedCollections) = try await (categories, collections)
            remoteCategories = loadedCategories
            remoteCollections = loadedCollections
            if let matchedCollection = loadedCollections.first(where: { $0.name == product.productTypeName }) {
                selectedCollectionId = matchedCollection.id
            }
        } catch {
            await MainActor.run {
                errorMessage = "Unable to load remote catalog metadata."
            }
        }
    }
}
