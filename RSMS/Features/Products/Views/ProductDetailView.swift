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
    let isSheet: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allCartItems: [CartItem]
    @Query(sort: \Category.displayOrder) private var allCategories: [Category]
    @Query private var allReservations: [ReservationItem]
    @Query private var allStores: [StoreLocation]
    
    private var hasActiveReservation: Bool {
        allReservations.contains {
            $0.customerEmail == appState.currentUserEmail &&
            $0.productId == product.id &&
            !$0.isExpired
        }
    }

    // Image gallery
    @State private var currentImageIndex = 0
    @State private var showGallery       = false

    // Bag/buy state
    @State private var addedToBag  = false
    @State private var showBuyNow  = false
    @State private var showReserveSheet = false
    @State private var navigateToCart = false

    // Variant selection
    @State private var selectedColorIndex = 0
    @State private var selectedSizeIndex: Int? = nil

    // Guest auth gate
    @State private var showGuestGate   = false
    @State private var guestGateAction = "Add to Bag"
    @State private var showSizeRequiredAlert = false

    // Add-to-bag animation
    @State private var bagIconScale: CGFloat = 1.0

    // Inventory Items
    @State private var remoteItems: [ProductItemDTO] = []
    @State private var isFetchingItems = false
    @State private var selectedBarcodeItem: ProductItemDTO?
    @State private var isExportingAll = false
    @State private var exportAllPDFURL: URL?
    @State private var showAdminManageSheet = false
    @State private var isCheckingWarranty = false
    @State private var warrantyResult: WarrantyLookupResult?
    @State private var warrantyError: String?
    @State private var productFeedback: [ProductFeedbackDTO] = []
    @State private var myFeedback: ProductFeedbackDTO?
    @State private var isLoadingFeedback = false
    @State private var feedbackError: String?
    @State private var showFeedbackComposer = false

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

    private var canViewInventory: Bool {
        let role = appState.currentUserRole
        return role == .inventoryController || role == .boutiqueManager || role == .corporateAdmin
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
        if hasActiveReservation { return "Reserved" }
        return variantStockCount > 5  ? "In Stock" :
        variantStockCount > 0  ? "Only \(variantStockCount) left" :
                                 "Out of Stock"
    }

    private var stockColor: Color {
        if hasActiveReservation { return AppColors.accent }
        return variantStockCount > 5  ? AppColors.success :
        variantStockCount > 0  ? AppColors.warning :
                                 AppColors.error
    }

    private func toggleWishlist() {
        let targetState = !product.isWishlisted
        product.isWishlisted = targetState
        try? modelContext.save()

        guard appState.isAuthenticated, !appState.isGuest else { return }

        Task { @MainActor in
            do {
                try await WishlistService.shared.setWishlisted(productId: product.id, isWishlisted: targetState)
            } catch {
                if case WishlistService.SyncCapabilityError.missingWishlistTable = error {
                    print("[ProductDetailView] Wishlist table not available yet; kept local wishlist state for \(product.id)")
                    return
                }
                product.isWishlisted = !targetState
                try? modelContext.save()
                print("[ProductDetailView] Wishlist sync failed for \(product.id): \(error)")
            }
        }
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
        mode == .adminCatalog || appState.currentUserRole == .corporateAdmin
    }

    init(product: Product, mode: ProductDetailMode = .storefront, isSheet: Bool = false) {
        self.product = product
        self.mode = mode
        self.isSheet = isSheet
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [AppColors.backgroundWarmWhite, AppColors.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Image Carousel ──────────────────────────────
                    imageCarouselSection

                    // ── Product Info ────────────────────────────────
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        headerSection
                        priceStockRow
                        if !isAdminMode {
                            inlineActionSection
                        }

                        sectionDivider
                        descriptionSection
                        sectionDivider
                        detailsSection

                        if !isAdminMode {
                            sectionDivider
                            feedbackSection
                        }

                        if !isAdminMode && appState.isAuthenticated && !appState.isGuest {
                            sectionDivider
                            warrantySection
                        }

                        if !product.parsedAttributes.isEmpty {
                            sectionDivider
                            specificationsSection
                        }

                        if canViewInventory {
                            sectionDivider
                            inventorySection
                        }

                        Spacer().frame(height: 28)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(AppColors.backgroundPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                    )
                    .padding(.horizontal, 12)
                }
            }

            // Floating close button — only when presented as a sheet
            if isSheet {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.black.opacity(0.40), in: Circle())
                }
                .accessibilityLabel("Close")
                .accessibilityHint("Double tap to close product details")
                .padding(.top, 16)
                .padding(.leading, 16)
            }
        }
        .task {
            await loadProductFeedback()
            guard canViewInventory else { return }
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
                    CartShortcutButton()
                }
            }
        }
        .if(!isAdminMode) { view in
            view.toolbar(.hidden, for: .tabBar)
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
        .sheet(isPresented: $showReserveSheet) {
            ReserveSheetView(
                product: product,
                selectedColor: colorVariants[selectedColorIndex],
                selectedSize: selectedSizeIndex.map { sizeVariants[$0] }
            )
            .presentationDetents([.fraction(0.85), .large])
        }
        .sheet(isPresented: $showFeedbackComposer) {
            ProductFeedbackComposerSheet(
                productName: product.name,
                initialRating: myFeedback?.rating ?? 5,
                initialTitle: myFeedback?.title ?? "",
                initialComment: myFeedback?.comment ?? "",
                onSubmit: { rating, title, comment in
                    Task { await submitFeedback(rating: rating, title: title, comment: comment) }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showGuestGate) {
            if !isAdminMode {
                GuestAuthGateView(pendingAction: guestGateAction)
            }
        }
        .sheet(isPresented: $showAdminManageSheet) {
            if isAdminMode {
                AdminProductManageSheet(product: product, categories: allCategories)
            }
        }
        .sheet(item: $selectedBarcodeItem) { item in
            BarcodeCardView(item: item, productName: product.name, brand: product.brand)
        }
        .sheet(isPresented: $isExportingAll, onDismiss: { exportAllPDFURL = nil }) {
            if let url = exportAllPDFURL {
                ShareSheet(activityItems: [url])
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
                                                idx == currentImageIndex ? AppColors.accent : AppColors.border.opacity(0.7),
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
                        .accessibilityLabel("Image \(min(currentImageIndex + 1, galleryImages.count)) of \(galleryImages.count)")
                }
                .padding(.top, 14)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                Spacer()
            }

            // Wishlist action inside product view so it remains visible in sheet/fullscreen presentation.
            if !isAdminMode {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                toggleWishlist()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: product.isWishlisted ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(product.isWishlisted ? AppColors.accent : .white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel(product.isWishlisted ? "Remove from wishlist" : "Add to wishlist")
                        .accessibilityHint("Double tap to \(product.isWishlisted ? "remove from" : "add to") your wishlist")
                    }
                    .padding(.top, 56)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    Spacer()
                }
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
                    .accessibilityLabel("View full screen gallery")
                    .accessibilityHint("Double tap to open image gallery")
                    .accessibilityAddTraits(.isButton)
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
                .foregroundColor(AppColors.textPrimaryDark)

            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    Image(systemName: i < Int(product.rating) ? "star.fill" : (Double(i) < product.rating ? "star.leadinghalf.filled" : "star"))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.accent)
                }
                Text(String(format: "%.1f", product.rating))
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rating: \(String(format: "%.1f", product.rating)) out of 5 stars")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Price + Stock

    private var priceStockRow: some View {
        HStack(alignment: .bottom) {
            Text(product.formattedPrice)
                .font(AppTypography.priceDisplay)
                .foregroundColor(AppColors.textPrimaryDark)
                .accessibilityLabel("Price: \(product.formattedPrice)")

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(stockColor)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(stockLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Stock status: \(stockLabel)")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Colour: \(colorVariants[selectedColorIndex])")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(colorVariants.indices, id: \.self) { idx in
                        colorChip(index: idx)
                            .accessibilityLabel("\(colorVariants[idx])\(selectedColorIndex == idx ? ", selected" : "")")
                            .accessibilityAddTraits(selectedColorIndex == idx ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint("Double tap to select \(colorVariants[idx])")
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
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Size Guide") {}
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
                    .accessibilityLabel("View size guide")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(sizeVariants.indices, id: \.self) { idx in
                        sizeChip(index: idx)
                            .accessibilityLabel("Size \(sizeVariants[idx])\(selectedSizeIndex == idx ? ", selected" : "")")
                            .accessibilityAddTraits(selectedSizeIndex == idx ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint("Double tap to select size \(sizeVariants[idx])")
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
                .accessibilityAddTraits(.isHeader)
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
                .accessibilityAddTraits(.isHeader)

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

    // MARK: - Warranty

    private var warrantySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("WARRANTY")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            Text("Check coverage for this product based on purchase history.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            Button {
                Task { await checkWarrantyFromProductDetail() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if isCheckingWarranty {
                        ProgressView().tint(.white)
                        Text("Checking...")
                    } else {
                        Image(systemName: "checkmark.shield")
                        Text("Check Warranty")
                    }
                }
                .font(AppTypography.buttonSecondary)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.touchTarget)
                .background(AppColors.accent)
                .cornerRadius(AppSpacing.radiusMedium)
            }
            .disabled(isCheckingWarranty)
            .opacity(isCheckingWarranty ? 0.75 : 1)

            if let result = warrantyResult {
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(warrantyStatusColor(result.status))
                        .frame(width: 8, height: 8)
                    Text("Status: \(result.status.rawValue)")
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                }

                detailRow(label: "Coverage", value: result.coveragePeriodText)
                detailRow(
                    label: "Eligible Services",
                    value: result.eligibleServices.isEmpty ? "None" : result.eligibleServices.joined(separator: ", ")
                )
            }

            if let warrantyError, !warrantyError.isEmpty {
                Text(warrantyError)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
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

    // MARK: - Reviews

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center) {
                Text("REVIEWS")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Spacer()
                if canWriteFeedback {
                    Button(myFeedback == nil ? "Write Review" : "Edit Review") {
                        showFeedbackComposer = true
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
                }
            }

            if isLoadingFeedback {
                ProgressView().tint(AppColors.accent)
            } else {
                ratingSummaryRow

                if let feedbackError, !feedbackError.isEmpty {
                    Text(feedbackError)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.error)
                }

                if productFeedback.isEmpty {
                    Text("No reviews yet. Be the first to share feedback.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                } else {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(productFeedback.prefix(5)) { feedback in
                            feedbackCard(feedback)
                        }
                    }
                }
            }
        }
    }

    private var canWriteFeedback: Bool {
        !isAdminMode && appState.isAuthenticated && !appState.isGuest && appState.currentClientProfile != nil
    }

    private var averageFeedbackRating: Double {
        guard !productFeedback.isEmpty else { return 0 }
        let total = productFeedback.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(productFeedback.count)
    }

    private var ratingSummaryRow: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { idx in
                    Image(systemName: idx < Int(round(averageFeedbackRating)) ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                }
            }

            Text(String(format: "%.1f", averageFeedbackRating))
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)

            Text("(\(productFeedback.count) reviews)")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            Spacer()
        }
    }

    private func feedbackCard(_ feedback: ProductFeedbackDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(feedback.customerName.isEmpty ? "Customer" : feedback.customerName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text(feedback.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { idx in
                    Image(systemName: idx < feedback.rating ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                }
            }

            if !feedback.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(feedback.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            Text(feedback.comment)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .lineLimit(4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                )
        )
    }

    // MARK: - Inventory Items

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("INVENTORY ITEMS")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Spacer()
                if !remoteItems.isEmpty {
                    Button("Export All Barcodes") {
                        handleExportAll()
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
                }
            }

            if isFetchingItems {
                ProgressView().tint(AppColors.accent)
            } else if remoteItems.isEmpty {
                Text("No inventory yet. Add stock.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .padding(.top, 4)
            } else {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(remoteItems) { item in
                        Button(action: {
                            selectedBarcodeItem = item
                        }) {
                            inventoryRow(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func inventoryRow(for item: ProductItemDTO) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "barcode")
                .font(.system(size: 14))
                .foregroundColor(AppColors.accent.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.barcode)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.textPrimaryDark)
                
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            
            Spacer()
            
            Text(item.itemStatus.displayName.uppercased())
                .font(AppTypography.nano)
                .tracking(1)
                .foregroundColor(statusColor(for: item.itemStatus))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(for: item.itemStatus).opacity(0.12))
                .cornerRadius(4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.border.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func statusColor(for status: ProductItemStatus) -> Color {
        switch status {
        case .inStock: return AppColors.success
        case .sold: return AppColors.error
        case .reserved: return AppColors.warning
        case .damaged: return AppColors.error
        case .returned: return Color.purple
        }
    }

    private func warrantyStatusColor(_ status: WarrantyCoverageStatus) -> Color {
        switch status {
        case .valid: return AppColors.success
        case .expired: return AppColors.warning
        case .notFound: return AppColors.error
        }
    }

    @MainActor
    private func checkWarrantyFromProductDetail() async {
        guard !isCheckingWarranty else { return }
        isCheckingWarranty = true
        warrantyError = nil

        do {
            warrantyResult = try await WarrantyService.shared.lookupWarranty(
                mode: .productId,
                query: product.id.uuidString
            )
        } catch {
            warrantyResult = nil
            warrantyError = error.localizedDescription
        }

        isCheckingWarranty = false
    }

    private var bottomActionBar: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 8) {
                Circle()
                    .fill(stockColor)
                    .frame(width: 7, height: 7)
                Text(stockLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                if cartItemQuantity > 0 {
                    Button(action: { navigateToCart = true }) {
                        Text("Bag (\(cartItemQuantity))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            Button(action: { handleAddToBag() }) {
                Text(
                    (variantStockCount > 0 || hasActiveReservation)
                    ? (addedToBag ? "Added To Bag" : (cartItemQuantity > 0 ? "Add Another To Bag" : "Add To Bag"))
                    : "Out of Stock"
                )
                .font(AppTypography.buttonPrimary)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(addedToBag ? AppColors.success : AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .animation(.spring(response: 0.3), value: addedToBag)
                .scaleEffect(bagIconScale)
            }
            .opacity((variantStockCount > 0 || hasActiveReservation) ? 1 : 0.45)
            .disabled((variantStockCount == 0 && !hasActiveReservation) && !appState.isGuest)

            HStack(spacing: 10) {
                Button(action: { handleBuyNow() }) {
                    Text(hasActiveReservation ? "Buy Reserved" : "Buy Now")
                        .font(AppTypography.buttonPrimary)
                        .foregroundColor((variantStockCount > 0 || hasActiveReservation) ? AppColors.accent : AppColors.accent.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(AppColors.backgroundPrimary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke((variantStockCount > 0 || hasActiveReservation) ? AppColors.accent : AppColors.accent.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .disabled((variantStockCount == 0 && !hasActiveReservation) && !appState.isGuest)

                Button(action: { handleReserve() }) {
                    HStack(spacing: 6) {
                        Image(systemName: hasActiveReservation ? "checkmark.seal.fill" : "building.2")
                            .font(.system(size: 13, weight: .medium))
                        Text(hasActiveReservation ? "Already Reserved" : "Reserve")
                            .font(AppTypography.buttonSecondary)
                    }
                    .foregroundColor(AppColors.textSecondaryDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .disabled((variantStockCount == 0 || hasActiveReservation) && !appState.isGuest)
                .opacity((variantStockCount > 0 && !hasActiveReservation) ? 1 : 0.45)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppColors.border.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 14, y: 6)
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var inlineActionSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 8) {
                Circle()
                    .fill(stockColor)
                    .frame(width: 7, height: 7)
                Text(stockLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                if cartItemQuantity > 0 {
                    Button(action: { navigateToCart = true }) {
                        Text("Bag (\(cartItemQuantity))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            // Primary: Add to Bag (full width)
            Button(action: { handleAddToBag() }) {
                Text(
                    (variantStockCount > 0 || hasActiveReservation)
                    ? (addedToBag ? "Added To Bag" : (cartItemQuantity > 0 ? "Add Another To Bag" : "Add To Bag"))
                    : "Out of Stock"
                )
                .font(AppTypography.buttonPrimary)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(addedToBag ? AppColors.success : AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .animation(.spring(response: 0.3), value: addedToBag)
                .scaleEffect(bagIconScale)
            }
            .opacity((variantStockCount > 0 || hasActiveReservation) ? 1 : 0.45)
            .disabled((variantStockCount == 0 && !hasActiveReservation) && !appState.isGuest)
            .accessibilityLabel(
                (variantStockCount > 0 || hasActiveReservation)
                ? (addedToBag ? "Added to bag" : (cartItemQuantity > 0 ? "Add another to bag" : "Add to bag"))
                : "Out of stock"
            )
            .accessibilityHint((variantStockCount > 0 || hasActiveReservation) ? "Double tap to add this item to your shopping bag" : "This item is currently unavailable")

            // Secondary row: Buy Now + Reserve
            HStack(spacing: 10) {
                Button(action: { handleBuyNow() }) {
                    Text(hasActiveReservation ? "Buy Reserved" : "Buy Now")
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor((variantStockCount > 0 || hasActiveReservation) ? AppColors.accent : AppColors.accent.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppColors.backgroundPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke((variantStockCount > 0 || hasActiveReservation) ? AppColors.accent : AppColors.accent.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .disabled((variantStockCount == 0 && !hasActiveReservation) && !appState.isGuest)
                .accessibilityLabel(hasActiveReservation ? "Buy reserved item" : "Buy now")
                .accessibilityHint("Double tap to purchase this item directly")

                Button(action: { handleReserve() }) {
                    Text(hasActiveReservation ? "Reserved" : "Reserve")
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled((variantStockCount == 0 || hasActiveReservation) && !appState.isGuest)
                .opacity((variantStockCount > 0 && !hasActiveReservation) ? 1 : 0.45)
                .accessibilityLabel(hasActiveReservation ? "Already reserved" : "Reserve in boutique")
                .accessibilityHint(hasActiveReservation ? "This item is already reserved for you" : "Double tap to reserve this item at a boutique")
            }

            // Store availability hint
            if let store = allStores.first(where: { $0.isOperational }) {
                HStack(spacing: 6) {
                    Image(systemName: "building.2")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("Available at \(store.name)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.border.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.clear, AppColors.accent.opacity(0.32), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
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

    private func handleReserve() {
        guard !hasActiveReservation else { return }
        
        if appState.isGuest {
            guestGateAction = "Reserve"
            showGuestGate   = true
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showReserveSheet = true
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

    @MainActor
    private func loadProductFeedback() async {
        isLoadingFeedback = true
        feedbackError = nil
        defer { isLoadingFeedback = false }

        do {
            productFeedback = try await ProductFeedbackService.shared.fetchProductFeedback(productId: product.id)
            if let customerId = appState.currentClientProfile?.id {
                myFeedback = try await ProductFeedbackService.shared.fetchMyFeedback(
                    productId: product.id,
                    customerId: customerId
                )
            } else {
                myFeedback = nil
            }
        } catch {
            feedbackError = error.localizedDescription
        }
    }

    @MainActor
    private func submitFeedback(rating: Int, title: String, comment: String) async {
        guard let client = appState.currentClientProfile else {
            feedbackError = "Sign in as a customer to submit feedback."
            return
        }

        do {
            _ = try await ProductFeedbackService.shared.upsertFeedback(
                productId: product.id,
                storeId: appState.currentStoreId,
                customerId: client.id,
                customerName: client.fullName,
                rating: rating,
                title: title,
                comment: comment
            )
            showFeedbackComposer = false
            await loadProductFeedback()
        } catch {
            feedbackError = error.localizedDescription
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
                .limit(50)
                .execute()
                .value
            remoteItems = items
        } catch {
            print("[ProductDetailView] Failed to fetch items:", error)
        }
    }
    
    private func handleExportAll() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let url = BarcodePDFService.shared.generatePDF(
            items: remoteItems,
            productName: product.name,
            brand: product.brand
        )
        if let output = url {
            exportAllPDFURL = output
            isExportingAll = true
        }
    }
}

private struct ProductFeedbackComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let productName: String
    let initialRating: Int
    let initialTitle: String
    let initialComment: String
    let onSubmit: (Int, String, String) -> Void

    @State private var rating: Int = 5
    @State private var title: String = ""
    @State private var comment: String = ""

    private var canSubmit: Bool {
        !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { index in
                            Button {
                                rating = index
                            } label: {
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Headline (Optional)") {
                    TextField("Summarize your experience", text: $title)
                }

                Section("Review") {
                    TextField("Share details about \(productName)", text: $comment, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("Product Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit(rating, title, comment)
                    }
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                rating = max(1, min(5, initialRating))
                title = initialTitle
                comment = initialComment
            }
        }
    }
}

private struct AdminProductManageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

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
    @State private var warrantyCoverageMonthsText: String = "24"
    @State private var warrantyEligibleServicesText: String = ""
    @State private var remoteCategories: [CategoryDTO] = []
    @State private var remoteCollections: [BrandCollectionDTO] = []
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {

                        // ── Basic Info ───────────────────────────────────────
                        formSection(title: "PRODUCT INFO") {
                            formRow(label: "Name") {
                                TextField("Product name", text: $name)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, AppSpacing.md)
                            formRow(label: "Brand") {
                                TextField("Brand", text: $brand)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, AppSpacing.md)
                            formRow(label: "Price (INR)") {
                                TextField("0.00", text: $priceText)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, AppSpacing.md)
                            formRow(label: "Stock") {
                                TextField("0", text: $stockText)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        // ── Classification ───────────────────────────────────
                        formSection(title: "CLASSIFICATION") {
                            formRow(label: "Category") {
                                Menu {
                                    ForEach(categories) { cat in
                                        Button(cat.name) { selectedCategoryName = cat.name }
                                    }
                                } label: {
                                    Text(selectedCategoryName.isEmpty ? "Select…" : selectedCategoryName)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(selectedCategoryName.isEmpty ? AppColors.neutral500 : AppColors.textPrimaryDark)
                                }
                            }
                            Divider().padding(.leading, AppSpacing.md)
                            formRow(label: "Collection") {
                                Menu {
                                    Button("No Collection") { selectedCollectionId = nil }
                                    Divider()
                                    ForEach(remoteCollections.filter(\.isActive)) { col in
                                        Button(col.name) { selectedCollectionId = col.id }
                                    }
                                } label: {
                                    Text(selectedCollectionName)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(selectedCollectionId == nil ? AppColors.neutral500 : AppColors.textPrimaryDark)
                                }
                            }
                        }

                        // ── Description ──────────────────────────────────────
                        formSection(title: "DESCRIPTION") {
                            TextField("Product description…", text: $descriptionText, axis: .vertical)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .lineLimit(3...8)
                                .padding(AppSpacing.md)
                        }

                        // ── Flags ────────────────────────────────────────────
                        formSection(title: "LABELS") {
                            HStack {
                                Label("Limited Edition", systemImage: "sparkles")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Spacer()
                                Toggle("", isOn: $isLimitedEdition).tint(AppColors.accent).labelsHidden()
                            }
                            .padding(AppSpacing.md)
                            Divider().padding(.leading, AppSpacing.md)
                            HStack {
                                Label("Featured", systemImage: "star")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Spacer()
                                Toggle("", isOn: $isFeatured).tint(AppColors.accent).labelsHidden()
                            }
                            .padding(AppSpacing.md)
                        }

                        // ── Warranty ─────────────────────────────────────────
                        formSection(title: "WARRANTY") {
                            formRow(label: "Coverage (months)") {
                                TextField("0", text: $warrantyCoverageMonthsText)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider().padding(.leading, AppSpacing.md)
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("ELIGIBLE SERVICES")
                                    .font(AppTypography.overline)
                                    .tracking(1.5)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                TextField("Servicing, Polishing, Strap replacement…", text: $warrantyEligibleServicesText, axis: .vertical)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .lineLimit(2...4)
                                Text("Comma-separated list of covered services.")
                                    .font(AppTypography.micro)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            .padding(AppSpacing.md)
                        }

                        // ── Error ────────────────────────────────────────────
                        if let errorMessage {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                Text(errorMessage)
                                    .font(AppTypography.caption)
                            }
                            .foregroundColor(AppColors.error)
                            .padding(AppSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.error.opacity(0.08))
                            .cornerRadius(AppSpacing.radiusMedium)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // ── Actions ──────────────────────────────────────────
                        VStack(spacing: AppSpacing.sm) {
                            Button(action: saveChanges) {
                                Group {
                                    if isSaving {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Save Changes")
                                            .font(AppTypography.buttonPrimary)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .background(AppColors.accent)
                            .cornerRadius(AppSpacing.radiusMedium)
                            .disabled(isSaving || isDeleting)

                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Group {
                                    if isDeleting {
                                        ProgressView().tint(AppColors.error)
                                    } else {
                                        Label("Delete Product", systemImage: "trash")
                                            .font(AppTypography.buttonPrimary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppColors.error)
                            .disabled(isSaving || isDeleting)
                            .confirmationDialog(
                                "Delete \"\(product.name)\"?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Delete Product", role: .destructive) { deleteProduct() }
                                Button("Keep Product", role: .cancel) {}
                            } message: {
                                Text("This removes the product from the catalog. Existing orders are not affected.")
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        Spacer().frame(height: AppSpacing.xxxl)
                    }
                    .padding(.top, AppSpacing.md)
                }
            }
            .navigationTitle("Manage Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textPrimaryDark)
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
                hydrateWarrantyFromLocalAttributes()
            }
            .task { await loadRemoteMetadata() }
        }
    }

    // MARK: - Form helpers

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(1.5)
                .foregroundColor(AppColors.textSecondaryDark)
                .padding(.leading, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xs)
            VStack(spacing: 0) {
                content()
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
            Spacer()
            trailing()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 13)
    }

    private func saveChanges() {
        let parsedPrice = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? product.price
        let parsedStock = Int(stockText) ?? product.stockCount
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        Task {
            defer { isSaving = false }
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

                let coverageMonths = max(0, Int(warrantyCoverageMonthsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
                let services = parsedWarrantyServices
                try await ProductWarrantyPolicyService.shared.upsertPolicy(
                    productId: product.id,
                    coverageMonths: coverageMonths,
                    eligibleServices: services,
                    updatedBy: appState.currentUserProfile?.id
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
                product.attributes = updatedWarrantyAttributesJSON

                try? modelContext.save()
                dismiss()
            } catch {
                await MainActor.run {
                    errorMessage = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteProduct() {
        isDeleting = true
        Task {
            do {
                try await CatalogService.shared.deleteProduct(id: product.id)
                modelContext.delete(product)
                try? modelContext.save()
                dismiss()
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = "Delete failed: \(error.localizedDescription)"
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
            let productId = product.id
            async let categories = CatalogService.shared.fetchCategories()
            async let collections = CatalogService.shared.fetchCollections()
            async let remotePolicy = ProductWarrantyPolicyService.shared.fetchPolicy(productId: productId)
            let (loadedCategories, loadedCollections, warrantyPolicy) = try await (categories, collections, remotePolicy)
            remoteCategories = loadedCategories
            remoteCollections = loadedCollections
            if let matchedCollection = loadedCollections.first(where: { $0.name == product.productTypeName }) {
                selectedCollectionId = matchedCollection.id
            }
            if let warrantyPolicy {
                warrantyCoverageMonthsText = "\(warrantyPolicy.coverageMonths)"
                warrantyEligibleServicesText = warrantyPolicy.eligibleServices.joined(separator: ", ")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Unable to load remote catalog metadata."
            }
        }
    }

    private func hydrateWarrantyFromLocalAttributes() {
        let attributes = product.parsedAttributes
        if let months = attributes["warranty_coverage_months"], !months.isEmpty {
            warrantyCoverageMonthsText = months
        }
        if let services = attributes["warranty_eligible_services"], !services.isEmpty {
            warrantyEligibleServicesText = services
        }
    }

    private var parsedWarrantyServices: [String] {
        warrantyEligibleServicesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var updatedWarrantyAttributesJSON: String {
        var dict = product.parsedAttributes
        let months = max(0, Int(warrantyCoverageMonthsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        dict["warranty_coverage_months"] = "\(months)"
        dict["warranty_eligible_services"] = parsedWarrantyServices.joined(separator: ", ")

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return product.attributes
        }
        return json
    }
}
