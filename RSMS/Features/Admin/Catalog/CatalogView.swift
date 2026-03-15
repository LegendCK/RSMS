//
//  CatalogView.swift
//  RSMS
//
//  Enterprise catalog management — SKU management, categories, pricing rules, promotions.
//

import SwiftUI
import SwiftData

struct CatalogView: View {
    @Query(sort: \Category.displayOrder) private var allCategories: [Category]

    @State private var selectedSection = 0
    @State private var showAddDialog   = false
    @State private var showAddCategory = false
    @State private var showAddProduct  = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Products").tag(0)
                        Text("Categories").tag(1)
                        Text("Pricing").tag(2)
                        Text("Promos").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: CatalogProductsSubview()
                    case 1: CatalogCategoriesSubview()
                    case 2: CatalogPricingSubview()
                    case 3: CatalogPromotionsSubview()
                    default: CatalogProductsSubview()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Catalog")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddDialog = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            // Context-sensitive action sheet
            .confirmationDialog("What would you like to add?", isPresented: $showAddDialog, titleVisibility: .visible) {
                Button("New Product") { showAddProduct = true }
                Button("New Category") { showAddCategory = true }
                Button("Cancel", role: .cancel) {}
            }
            // Add Category sheet
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView()
            }
            // Add Product sheet — passes current categories for the picker
            .sheet(isPresented: $showAddProduct) {
                AddProductView(availableCategories: allCategories)
            }
        }
    }
}

// MARK: - Products Sub-view (SKU Management)

struct CatalogProductsSubview: View {
    // Remote products from Supabase
    @State private var remoteProducts: [ProductDTO] = []
    @State private var remoteCategories: [CategoryDTO] = []
    @State private var isLoading = false
 
    // Keep local SwiftData categories for the chip filter labels
    @Query(sort: \Category.displayOrder) private var localCategories: [Category]
    @Environment(\.modelContext) private var modelContext
 
    @State private var searchText = ""
    @State private var selectedCategoryId: UUID? = nil   // filter by Supabase category UUID
 
    private var filtered: [ProductDTO] {
        var list = remoteProducts
        if let catId = selectedCategoryId {
            list = list.filter { $0.categoryId == catId }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                $0.sku.lowercased().contains(q) ||
                ($0.brand?.lowercased().contains(q) == true)
            }
        }
        return list
    }
 
    var body: some View {
        VStack(spacing: 0) {
 
            // Search bar
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.neutral500)
                TextField("Search SKUs...", text: $searchText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)
 
            // Category chips — built from remote categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    chipButton(label: "All", selected: selectedCategoryId == nil) {
                        selectedCategoryId = nil
                    }
                    ForEach(remoteCategories) { cat in
                        chipButton(label: cat.name, selected: selectedCategoryId == cat.id) {
                            selectedCategoryId = cat.id
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.vertical, AppSpacing.xs)
 
            // Count
            HStack {
                Text("\(filtered.count) products")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xs)
 
            // Loading / list
            if isLoading && remoteProducts.isEmpty {
                Spacer()
                ProgressView().progressViewStyle(.circular).tint(AppColors.accent)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(filtered) { product in
                            NavigationLink {
                                CatalogProductDetailView(
                                    product: product,
                                    categoryName: categoryName(for: product),
                                    categories: remoteCategories
                                ) { updated in
                                    if let idx = remoteProducts.firstIndex(where: { $0.id == updated.id }) {
                                        remoteProducts[idx] = updated
                                    }
                                }
                            } label: {
                                productRow(product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .refreshable { await loadAll() }
            }
        }
        .task { await loadAll() }
    }
 
    // MARK: - Product row
 
    private func productRow(_ product: ProductDTO) -> some View {
        HStack(spacing: AppSpacing.sm) {
 
            // Thumbnail — AsyncImage from Supabase Storage
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 44, height: 44)
 
                ProductThumbnailImageView(urls: product.resolvedImageURLs)
            }
 
            // Name + brand
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.brand ?? "Maison Luxe")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
 
            Spacer()
 
            // Price + active dot
            VStack(alignment: .trailing, spacing: 2) {
                Text(product.formattedPrice)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                HStack(spacing: 3) {
                    Circle()
                        .fill(product.isActive ? AppColors.success : AppColors.error)
                        .frame(width: 5, height: 5)
                    Text(product.isActive ? "Active" : "Inactive")
                        .font(AppTypography.caption)
                        .foregroundColor(product.isActive ? AppColors.success : AppColors.error)
                }
            }
 
            Image(systemName: "chevron.right")
                .font(AppTypography.chevron)
                .foregroundColor(AppColors.neutral600)
                .frame(width: 28, height: AppSpacing.touchTarget)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
 
    // MARK: - Chip button
 
    private func chipButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(selected ? AppTypography.label : AppTypography.bodySmall)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(selected ? AppColors.textPrimaryLight : AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
                .frame(minWidth: 76)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(selected ? AppColors.accent : AppColors.backgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(
                            selected ? AppColors.accentDark.opacity(0.5) : AppColors.border.opacity(0.28),
                            lineWidth: selected ? 1 : 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
 
    // MARK: - Data loading
 
    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let cats  = CatalogService.shared.fetchCategories()
            async let prods = CatalogService.shared.fetchProducts()
            let (c, p) = try await (cats, prods)
            remoteCategories = c
            remoteProducts   = p
        } catch {
            print("[CatalogProductsSubview] Load failed: \(error)")
        }
    }

    private func categoryName(for product: ProductDTO) -> String {
        guard let categoryId = product.categoryId else { return "Uncategorized" }
        return remoteCategories.first(where: { $0.id == categoryId })?.name ?? "Uncategorized"
    }
}

// MARK: - Product Detail (Admin)

struct CatalogProductDetailView: View {
    let categories: [CategoryDTO]
    let onProductUpdated: (ProductDTO) -> Void
    let showsManageButton: Bool
    let fallbackImageSymbol: String
    @State private var selectedImageIndex = 0
    @State private var showImageViewer = false
    @State private var showManageSheet = false
    @State private var currentProduct: ProductDTO
    @State private var currentCategoryName: String

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(
        product: ProductDTO,
        categoryName: String,
        categories: [CategoryDTO],
        showsManageButton: Bool = true,
        fallbackImageSymbol: String = "bag.fill",
        onProductUpdated: @escaping (ProductDTO) -> Void = { _ in }
    ) {
        self.categories = categories
        self.showsManageButton = showsManageButton
        self.fallbackImageSymbol = fallbackImageSymbol
        self.onProductUpdated = onProductUpdated
        _currentProduct = State(initialValue: product)
        _currentCategoryName = State(initialValue: categoryName)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.backgroundPrimary,
                    AppColors.backgroundWarmWhite,
                    AppColors.backgroundSecondary.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    heroSection
                    highlightRow
                    availabilitySection
                    pricingSection
                    infoSection
                    timelineSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .navigationTitle(currentProduct.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsManageButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manage") {
                        showManageSheet = true
                    }
                    .font(AppTypography.buttonSecondary)
                    .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showManageSheet) {
            CatalogManageProductSheet(
                product: currentProduct,
                categories: categories
            ) { updated, updatedCategoryName in
                currentProduct = updated
                currentCategoryName = updatedCategoryName
                onProductUpdated(updated)
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            FullscreenProductGalleryView(
                imageURLs: imageURLs,
                selectedIndex: selectedImageIndex,
                productName: currentProduct.name
            )
        }
    }

    private var heroSection: some View {
        VStack(spacing: AppSpacing.md) {
            gallerySection

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text((currentProduct.brand ?? "Maison Luxe").uppercased())
                    .font(AppTypography.overline)
                    .foregroundColor(AppColors.accent)
                    .tracking(2)

                Text(currentProduct.name)
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)

                if let description = currentProduct.description, !description.isEmpty {
                    Text(description)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXL))
        .shadow(color: AppColors.neutral900.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private var gallerySection: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(AppColors.backgroundWhite.opacity(0.85))
                    .frame(height: 380)

                if imageURLs.isEmpty {
                    Image(systemName: fallbackImageSymbol)
                        .font(AppTypography.iconDecorative)
                        .foregroundColor(AppColors.neutral600)
                } else {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .padding(AppSpacing.md)
                                case .failure(_):
                                    Image(systemName: "photo")
                                        .font(AppTypography.iconProductLarge)
                                        .foregroundColor(AppColors.neutral500)
                                default:
                                    ProgressView()
                                        .tint(AppColors.accent)
                                }
                            }
                            .tag(index)
                            .onTapGesture {
                                selectedImageIndex = index
                                showImageViewer = true
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                    VStack {
                        HStack {
                            Spacer()
                            Text("Image \(selectedImageIndex + 1)/\(imageURLs.count)")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.sm)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )

            if !imageURLs.isEmpty {
                HStack {
                    Text("Gallery")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("\(selectedImageIndex + 1) of \(imageURLs.count)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                            Button {
                                selectedImageIndex = index
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.backgroundWhite)
                                        .frame(width: 74, height: 74)

                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 64, height: 64)
                                        default:
                                            Image(systemName: "photo")
                                                .font(AppTypography.iconSmall)
                                                .foregroundColor(AppColors.neutral500)
                                        }
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedImageIndex == index ? AppColors.accent : AppColors.border,
                                            lineWidth: selectedImageIndex == index ? 2 : 1
                                        )
                                )
                                .shadow(
                                    color: AppColors.neutral900.opacity(selectedImageIndex == index ? 0.12 : 0.04),
                                    radius: 6,
                                    x: 0,
                                    y: 2
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var availabilitySection: some View {
        detailCard(title: "Available Variants", icon: "square.grid.3x3.topleft.filled") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                variantGroup(title: "Colours", values: availableColours, emptyLabel: "Standard colourway")
                variantGroup(title: "Sizes", values: availableSizes, emptyLabel: "One Size")

                if !variantSummary.isEmpty {
                    Text(variantSummary)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var highlightRow: some View {
        HStack(spacing: AppSpacing.sm) {
            detailPill(title: "Status", icon: "checkmark.seal.fill") {
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(currentProduct.isActive ? AppColors.success : AppColors.error)
                        .frame(width: 8, height: 8)
                    Text(currentProduct.isActive ? "Active" : "Inactive")
                        .font(AppTypography.label)
                        .foregroundColor(currentProduct.isActive ? AppColors.success : AppColors.error)
                }
            }

            detailPill(title: "Price", icon: "dollarsign.circle.fill") {
                Text(currentProduct.formattedPrice)
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
        }
    }

    private var pricingSection: some View {
        detailCard(title: "Pricing", icon: "creditcard.fill") {
            detailRow(label: "Retail Price", value: currentProduct.formattedPrice)
            if let costPrice = currentProduct.costPrice {
                detailRow(label: "Cost Price", value: currency(costPrice))
            }
        }
    }

    private var infoSection: some View {
        detailCard(title: "Product Information", icon: "shippingbox.fill") {
            detailRow(label: "SKU", value: currentProduct.sku)
            if let barcode = currentProduct.barcode, !barcode.isEmpty {
                detailRow(label: "Barcode", value: barcode)
            }
            detailRow(label: "Category", value: currentCategoryName)
            detailRow(label: "Product ID", value: currentProduct.id.uuidString)
        }
    }

    private var timelineSection: some View {
        detailCard(title: "Timeline", icon: "clock.fill") {
            detailRow(label: "Created", value: Self.timestampFormatter.string(from: currentProduct.createdAt))
            detailRow(label: "Updated", value: Self.timestampFormatter.string(from: currentProduct.updatedAt))
        }
    }

    private func detailPill<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(title, systemImage: icon)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    private func detailCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
                .tracking(1.5)

            VStack(spacing: AppSpacing.sm) {
                content()
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: AppColors.neutral900.opacity(0.06), radius: 14, x: 0, y: 4)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: AppSpacing.xs) {
                Text(label.uppercased())
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text(value)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .multilineTextAlignment(.trailing)
            }

            Divider()
                .background(AppColors.dividerLight.opacity(0.8))
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private var imageURLs: [URL] {
        currentProduct.resolvedImageURLs
    }

    private var availableColours: [String] {
        if let parsed = parsedInlineList(prefixes: ["colors", "colours", "colour", "color"]) {
            return parsed
        }

        let category = currentCategoryName.lowercased()
        if category.contains("jewellery") || category.contains("jewelry") {
            return ["Yellow Gold", "White Gold", "Rose Gold", "Platinum"]
        }
        if category.contains("watch") {
            return ["Steel", "Black", "Gold", "Two-Tone"]
        }
        if category.contains("shoe") || category.contains("footwear") {
            return ["Black", "Brown", "Tan"]
        }
        if category.contains("clothing") || category.contains("couture") {
            return ["Black", "Ivory", "Navy", "Camel"]
        }
        return []
    }

    private var availableSizes: [String] {
        if let parsed = parsedInlineList(prefixes: ["sizes", "size"]) {
            return parsed
        }

        let category = currentCategoryName.lowercased()
        if category.contains("shoe") || category.contains("footwear") {
            return ["39", "40", "41", "42", "43"]
        }
        if category.contains("clothing") || category.contains("couture") {
            return ["XS", "S", "M", "L", "XL"]
        }
        if category.contains("ring") || category.contains("jewellery") || category.contains("jewelry") {
            return ["5", "6", "7", "8"]
        }
        return ["One Size"]
    }

    private var variantSummary: String {
        if let description = currentProduct.description, !description.isEmpty {
            return "Admin note: Variants inferred from product description and category rules."
        }
        return "Admin note: Add explicit colour/size details in product description for exact options."
    }

    private func variantGroup(title: String, values: [String], emptyLabel: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(values.isEmpty ? [emptyLabel] : values, id: \.self) { value in
                        Text(value)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 7)
                            .background(AppColors.backgroundWhite.opacity(0.9))
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.border.opacity(0.35), lineWidth: 0.6)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func parsedInlineList(prefixes: [String]) -> [String]? {
        guard let description = currentProduct.description?.lowercased() else { return nil }
        for prefix in prefixes {
            if let range = description.range(of: "\(prefix):") {
                let tail = description[range.upperBound...]
                let firstLine = tail.split(separator: "\n").first ?? Substring(tail)
                let parsed = firstLine
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
                    .filter { !$0.isEmpty }
                if !parsed.isEmpty {
                    return parsed
                }
            }
        }
        return nil
    }
}

private struct ProductThumbnailImageView: View {
    let urls: [URL]

    @State private var activeIndex = 0
    @State private var failedIndices: Set<Int> = []

    var body: some View {
        ZStack {
            if let url = activeURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    case .failure(_):
                        fallbackIcon
                            .onAppear { advanceIfNeeded() }
                    default:
                        ProgressView()
                            .scaleEffect(0.65)
                            .tint(AppColors.accent)
                    }
                }
            } else {
                fallbackIcon
            }
        }
    }

    private var activeURL: URL? {
        guard activeIndex >= 0, activeIndex < urls.count else { return nil }
        return urls[activeIndex]
    }

    private var fallbackIcon: some View {
        Image(systemName: "bag.fill")
            .font(AppTypography.productRowIcon)
            .foregroundColor(AppColors.neutral600)
    }

    private func advanceIfNeeded() {
        guard activeIndex < urls.count, !failedIndices.contains(activeIndex) else { return }
        failedIndices.insert(activeIndex)

        if let next = (activeIndex + 1..<urls.count).first(where: { !failedIndices.contains($0) }) {
            activeIndex = next
        } else {
            activeIndex = urls.count
        }
    }
}

struct CatalogManageProductSheet: View {
    @Environment(\.dismiss) private var dismiss

    let product: ProductDTO
    let categories: [CategoryDTO]
    let onSaved: (ProductDTO, String) -> Void

    @State private var sku: String
    @State private var name: String
    @State private var brand: String
    @State private var selectedCategoryId: UUID?
    @State private var priceText: String
    @State private var costPriceText: String
    @State private var barcode: String
    @State private var descriptionText: String
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(product: ProductDTO, categories: [CategoryDTO], onSaved: @escaping (ProductDTO, String) -> Void) {
        self.product = product
        self.categories = categories
        self.onSaved = onSaved
        _sku = State(initialValue: product.sku)
        _name = State(initialValue: product.name)
        _brand = State(initialValue: product.brand ?? "")
        _selectedCategoryId = State(initialValue: product.categoryId)
        _priceText = State(initialValue: String(format: "%.2f", product.price))
        _costPriceText = State(initialValue: product.costPrice.map { String(format: "%.2f", $0) } ?? "")
        _barcode = State(initialValue: product.barcode ?? "")
        _descriptionText = State(initialValue: product.description ?? "")
        _isActive = State(initialValue: product.isActive)
    }

    private var priceValue: Double? {
        Double(priceText.replacingOccurrences(of: ",", with: "."))
    }

    private var costPriceValue: Double? {
        let value = costPriceText.replacingOccurrences(of: ",", with: ".")
        return value.isEmpty ? nil : Double(value)
    }

    private var isFormValid: Bool {
        !sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        priceValue != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        manageCard(title: "Core Details", icon: "shippingbox.fill") {
                            textInputRow("SKU", text: $sku)
                            textInputRow("Product Name", text: $name)
                            textInputRow("Brand", text: $brand)
                            categoryRow
                            toggleRow
                        }

                        manageCard(title: "Pricing", icon: "creditcard.fill") {
                            priceRow("Retail Price", text: $priceText)
                            priceRow("Cost Price", text: $costPriceText, optional: true)
                        }

                        manageCard(title: "Extended Details", icon: "doc.text.fill") {
                            textInputRow("Barcode", text: $barcode, placeholder: "UPC / EAN")
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Description")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                TextField("Write product details...", text: $descriptionText, axis: .vertical)
                                    .lineLimit(3...7)
                                    .font(AppTypography.bodyMedium)
                                    .padding(AppSpacing.sm)
                                    .background(AppColors.backgroundWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.sm)
                                .background(AppColors.error.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .navigationTitle("Manage Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(AppColors.accent)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                    .foregroundColor((isFormValid && !isSaving) ? AppColors.accent : AppColors.neutral400)
                }
            }
        }
    }

    private var categoryRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Category")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            Menu {
                Button("Uncategorized") { selectedCategoryId = nil }
                Divider()
                ForEach(categories) { category in
                    Button(category.name) {
                        selectedCategoryId = category.id
                    }
                }
            } label: {
                HStack {
                    Text(selectedCategoryName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral500)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            }
        }
    }

    private var toggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active")
                    .font(AppTypography.label)
                Text("Visible in catalog")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            Toggle("", isOn: $isActive)
                .tint(AppColors.accent)
        }
        .padding(.top, AppSpacing.xs)
    }

    private func manageCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXL))
    }

    private func textInputRow(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            TextField(placeholder, text: text)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private func priceRow(_ label: String, text: Binding<String>, optional: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(optional ? "\(label) (Optional)" : label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            HStack(spacing: 6) {
                Text("$")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.neutral500)
                TextField("0.00", text: text)
                    .keyboardType(.decimalPad)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId else { return "Uncategorized" }
        return categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Uncategorized"
    }

    private func saveChanges() async {
        guard isFormValid, let priceValue else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await CatalogService.shared.updateProduct(
                id: product.id,
                sku: sku.trimmingCharacters(in: .whitespacesAndNewlines),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: selectedCategoryId,
                price: priceValue,
                costPrice: costPriceValue,
                description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                barcode: barcode.trimmingCharacters(in: .whitespacesAndNewlines),
                isActive: isActive
            )
            onSaved(updated, selectedCategoryName)
            dismiss()
        } catch {
            errorMessage = "Could not save changes: \(error.localizedDescription)"
        }
    }
}

struct FullscreenProductGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    let imageURLs: [URL]
    let selectedIndex: Int
    let productName: String

    @State private var activeIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if imageURLs.isEmpty {
                    Image(systemName: "photo")
                        .font(AppTypography.iconHero)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    TabView(selection: $activeIndex) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                            ZoomableRemoteImage(url: url)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text("\(productName)  \(activeIndex + 1)/\(max(1, imageURLs.count))")
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                activeIndex = selectedIndex
            }
        }
    }
}

struct ZoomableRemoteImage: View {
    let url: URL

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(1, lastScale * value), 4)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale <= 1 {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    guard scale > 1 else { return }
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2
                                    lastScale = 2
                                }
                            }
                        }
                case .failure(_):
                    Image(systemName: "photo")
                        .font(AppTypography.iconHero)
                        .foregroundColor(.white.opacity(0.65))
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
}
 
// MARK: - Categories Sub-view

struct CatalogCategoriesSubview: View {
    @Query(sort: \Category.displayOrder) private var categories: [Category]
    @Query private var allProducts: [Product]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(categories) { cat in
                    let count = allProducts.filter { $0.categoryName == cat.name }.count
                    NavigationLink {
                        AdminCatalogCategoryDetailView(category: cat)
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle().fill(AppColors.accent.opacity(0.12)).frame(width: 44, height: 44)
                                Image(systemName: cat.icon).font(AppTypography.catalogIcon).foregroundColor(AppColors.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                                Text(cat.categoryDescription).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark).lineLimit(1)
                            }
                            Spacer()
                            Text("\(count) SKUs").font(AppTypography.caption).foregroundColor(AppColors.accent)
                            Image(systemName: "chevron.right").font(AppTypography.chevron).foregroundColor(AppColors.neutral600)
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }
}

struct AdminCatalogCategoryDetailView: View {
    @Bindable var category: Category
    @Query private var allProducts: [Product]
    @State private var showManageSheet = false

    private var categoryProducts: [Product] {
        allProducts.filter { $0.categoryName == category.name }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.backgroundPrimary,
                    AppColors.backgroundWarmWhite,
                    AppColors.backgroundSecondary.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    categoryHeader
                    productTypesCard
                    productsCard
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Manage") { showManageSheet = true }
                    .font(AppTypography.buttonSecondary)
                    .foregroundColor(AppColors.accent)
            }
        }
        .sheet(isPresented: $showManageSheet) {
            AdminManageCategorySheet(category: category)
        }
    }

    private var categoryHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: category.icon)
                        .font(AppTypography.iconAction)
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(AppTypography.heading2)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("\(categoryProducts.count) active SKUs")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
            }

            Text(category.categoryDescription)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXL))
    }

    private var productTypesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Product Types", systemImage: "square.grid.2x2.fill")
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
                .tracking(1.5)

            if category.parsedProductTypes.isEmpty {
                Text("No product types configured.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(category.parsedProductTypes, id: \.self) { type in
                            Text(type)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 6)
                                .background(AppColors.backgroundWhite.opacity(0.9))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXL))
    }

    private var productsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Products", systemImage: "shippingbox.fill")
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
                .tracking(1.5)

            if categoryProducts.isEmpty {
                Text("No products in this category yet.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.xs)
            } else {
                ForEach(categoryProducts) { product in
                    NavigationLink {
                        CatalogProductDetailView(
                            product: product.asCatalogProductDTO,
                            categoryName: product.categoryName,
                            categories: [],
                            showsManageButton: false,
                            fallbackImageSymbol: product.imageName
                        )
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            ProductArtworkView(
                                imageSource: product.imageName,
                                fallbackSymbol: "bag.fill",
                                cornerRadius: 6
                            )
                            .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text(product.sku)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            Spacer()
                            Text(product.formattedPrice)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.plain)

                    if product.id != categoryProducts.last?.id {
                        Divider().background(AppColors.dividerLight)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXL))
    }
}

private extension Product {
    var asCatalogProductDTO: ProductDTO {
        ProductDTO(
            id: id,
            sku: sku,
            barcode: barcode.isEmpty ? nil : barcode,
            name: name,
            brand: brand.isEmpty ? nil : brand,
            categoryId: nil,
            taxCategoryId: nil,
            description: productDescription.isEmpty ? nil : productDescription,
            price: price,
            costPrice: nil,
            imageUrls: nil,
            isActive: true,
            createdBy: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

struct AdminManageCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: Category

    @State private var name: String
    @State private var icon: String
    @State private var descriptionText: String
    @State private var displayOrderText: String
    @State private var productTypesText: String
    @State private var errorMessage: String?

    init(category: Category) {
        self.category = category
        _name = State(initialValue: category.name)
        _icon = State(initialValue: category.icon)
        _descriptionText = State(initialValue: category.categoryDescription)
        _displayOrderText = State(initialValue: "\(category.displayOrder)")
        _productTypesText = State(initialValue: category.parsedProductTypes.joined(separator: ", "))
    }

    private var displayOrderValue: Int? { Int(displayOrderText) }
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        displayOrderValue != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        manageCard(title: "Category Details", icon: "square.grid.2x2.fill") {
                            textInputRow("Name", text: $name)
                            textInputRow("SF Symbol Icon", text: $icon, placeholder: "e.g. bag.fill")
                            textInputRow("Display Order", text: $displayOrderText, placeholder: "0")
                        }

                        manageCard(title: "Description", icon: "text.alignleft") {
                            TextField("Category description", text: $descriptionText, axis: .vertical)
                                .lineLimit(3...7)
                                .font(AppTypography.bodyMedium)
                                .padding(AppSpacing.sm)
                                .background(AppColors.backgroundWhite)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                        }

                        manageCard(title: "Product Types", icon: "tag.fill") {
                            Text("Comma separated values")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                            TextField("e.g. Engagement Rings, Wedding Bands", text: $productTypesText, axis: .vertical)
                                .lineLimit(2...6)
                                .font(AppTypography.bodyMedium)
                                .padding(AppSpacing.sm)
                                .background(AppColors.backgroundWhite)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.sm)
                                .background(AppColors.error.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .navigationTitle("Manage Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(!isFormValid)
                        .foregroundColor(isFormValid ? AppColors.accent : AppColors.neutral400)
                }
            }
        }
    }

    private func manageCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXL))
    }

    private func textInputRow(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            TextField(placeholder, text: text)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private func saveChanges() {
        guard isFormValid, let displayOrderValue else {
            errorMessage = "Please enter valid values before saving."
            return
        }

        category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        category.icon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        category.categoryDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        category.displayOrder = displayOrderValue
        category.productTypes = jsonArrayString(from: productTypesText)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Could not save category: \(error.localizedDescription)"
        }
    }

    private func jsonArrayString(from raw: String) -> String {
        let values = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Pricing Sub-view

struct CatalogPricingSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                pricingCard(title: "Tax Configuration", subtitle: "Regional tax rates and exemptions",
                            icon: "percent", items: ["US Federal — 0%", "New York — 8.875%", "California — 7.25%", "EU VAT — 20%", "Japan — 10%"])

                pricingCard(title: "Currency Settings", subtitle: "Multi-currency pricing",
                            icon: "dollarsign.circle", items: ["USD — Primary", "EUR — Auto-convert", "GBP — Auto-convert", "JPY — Auto-convert"])

                pricingCard(title: "Discount Rules", subtitle: "Automated discount tiers",
                            icon: "tag", items: ["VIP Gold — 5% off", "VIP Platinum — 10% off", "Employee — 15% off", "Loyalty 1000+ pts — $50 credit"])
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func pricingCard(title: String, subtitle: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon).font(AppTypography.iconMedium).foregroundColor(AppColors.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text(subtitle).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Button(action: {}) {
                    Text("Edit").font(AppTypography.editLink).foregroundColor(AppColors.accent)
                }
            }
            Divider().background(AppColors.border)
            ForEach(items, id: \.self) { item in
                Text(item).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
                    .padding(.leading, AppSpacing.xl)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }
}

// MARK: - Promotions Sub-view

struct CatalogPromotionsSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                promoCard(name: "Spring 2026 Collection", status: "Active", discount: "10% off select handbags",
                          start: "Mar 1", end: "Apr 15", color: AppColors.success)
                promoCard(name: "VIP Private Sale", status: "Scheduled", discount: "15% off all categories",
                          start: "Apr 1", end: "Apr 7", color: AppColors.info)
                promoCard(name: "Holiday 2025 Clearance", status: "Ended", discount: "20% off accessories",
                          start: "Dec 26", end: "Jan 15", color: AppColors.neutral500)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func promoCard(name: String, status: String, discount: String, start: String, end: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Text(status.uppercased()).font(AppTypography.nano).foregroundColor(color)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(color.opacity(0.12)).cornerRadius(4)
            }
            Text(discount).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
            HStack(spacing: AppSpacing.md) {
                Label(start, systemImage: "calendar").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                Image(systemName: "arrow.right").font(AppTypography.arrowInline).foregroundColor(AppColors.neutral600)
                Label(end, systemImage: "calendar").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }
}

#Preview {
    CatalogView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
