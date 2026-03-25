
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
    
    
    // CSV Upload State
    @State private var showFileImporter = false
    @State private var showCSVPreview = false
    @State private var parsedCSVRows: [CSVProductRow] = []
    
    // CSV Template State
    @State private var showTemplateExporter = false
    @State private var templateDocument: CSVTemplateDocument?

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
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
            Button("Upload CSV") { showFileImporter = true }
            Button("Download CSV Template") {
                templateDocument = CSVTemplateDocument(initialText: CSVParserService.generateTemplate())
                showTemplateExporter = true
            }
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
        // CSV File Importer
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                do {
                    parsedCSVRows = try CSVParserService.parseCSV(url: url)
                    showCSVPreview = true
                } catch {
                    print("Failed to parse CSV: \(error)")
                }
            case .failure(let err):
                print("Failed to import file: \(err)")
            }
        }
        // CSV Preview Sheet
        .sheet(isPresented: $showCSVPreview) {
            if !parsedCSVRows.isEmpty {
                CSVPreviewView(rows: parsedCSVRows)
            }
        }
        // CSV Template Exporter
        .fileExporter(isPresented: $showTemplateExporter, document: templateDocument, contentType: .commaSeparatedText, defaultFilename: "Products_Template.csv") { _ in }
    }
}

// MARK: - CSV Template Document wrapper
import UniformTypeIdentifiers

struct CSVTemplateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    
    init(initialText: String) {
        text = initialText
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Products Sub-view (SKU Management)

struct CatalogProductsSubview: View {
    // Remote products from Supabase
    @State private var selectedProduct: Product?
    @State private var remoteProducts: [ProductDTO] = []
    @State private var remoteCategories: [CategoryDTO] = []
    @State private var isLoading = false
 
    // Keep local SwiftData categories for the chip filter labels
    @Query(sort: \Category.displayOrder) private var localCategories: [Category]
    @Query private var localProducts: [Product]
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
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .padding(.top, 2)
            .padding(.bottom, 6)
 
            // Loading / list
            if isLoading && remoteProducts.isEmpty {
                Spacer()
                ProgressView().progressViewStyle(.circular).tint(AppColors.accent)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(filtered, id: \.id) { dto in
                            Button {
                                let localProduct: Product
                                if let existing = localProducts.first(where: { $0.id == dto.id }) {
                                    localProduct = existing
                                } else {
                                    let newProduct = Product(
                                        id: dto.id,
                                        name: dto.name,
                                        brand: dto.brand ?? "Maison Luxe",
                                        description: dto.description ?? "",
                                        price: dto.price,
                                        categoryName: remoteCategories.first(where: { $0.id == dto.categoryId })?.name ?? "",
                                        imageName: dto.primaryImageUrl ?? ""
                                    )
                                    modelContext.insert(newProduct)
                                    try? modelContext.save()
                                    localProduct = newProduct
                                }
                                selectedProduct = localProduct
                            } label: {
                                productRow(dto)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .refreshable { await loadAll() }
                .navigationDestination(item: $selectedProduct) { product in
                    ProductDetailView(product: product, mode: .adminCatalog)
                }
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
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 44, height: 44)
 
                if let urlString = product.primaryImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                               .frame(width: 44, height: 44).clipped()
                               .cornerRadius(6)
                        default:
                            Image(systemName: "bag.fill")
                                .font(AppTypography.productRowIcon)
                                .foregroundColor(AppColors.neutral600)
                        }
                    }
                } else {
                    Image(systemName: "bag.fill")
                        .font(AppTypography.productRowIcon)
                        .foregroundColor(AppColors.neutral600)
                }
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
 
            Image(systemName: "ellipsis")
                .font(AppTypography.iconSmall)
                .foregroundColor(AppColors.neutral500)
                .frame(width: 28, height: AppSpacing.touchTarget)
                .allowsHitTesting(false)
        }
        .padding(AppSpacing.sm)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                .allowsHitTesting(false)
        )
    }
 
    // MARK: - Chip button
 
    private func chipButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .foregroundStyle(selected ? AppColors.accent : AppColors.textPrimaryDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minWidth: 66)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            selected
                            ? AppColors.accent.opacity(0.14)
                            : Color(uiColor: .secondarySystemGroupedBackground)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            selected
                            ? AppColors.accent.opacity(0.30)
                            : Color.black.opacity(0.05),
                            lineWidth: 0.6
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: selected)
    }
 
    // MARK: - Data loading
 
    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let cats  = CatalogService.shared.fetchCategories()
            async let prods = CatalogService.shared.fetchProducts()
            async let cols  = CatalogService.shared.fetchCollections()
            let (c, p, co) = try await (cats, prods, cols)
            remoteCategories = c
            remoteProducts   = p
            try syncLocalMirror(remoteProducts: p, remoteCategories: c, remoteCollections: co)
        } catch {
            print("[CatalogProductsSubview] Load failed: \(error)")
        }
    }

    private func syncLocalMirror(
        remoteProducts: [ProductDTO],
        remoteCategories: [CategoryDTO],
        remoteCollections: [BrandCollectionDTO]
    ) throws {
        let locals = try modelContext.fetch(FetchDescriptor<Product>())
        var localById = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })
        let categoryNamesById = Dictionary(uniqueKeysWithValues: remoteCategories.map { ($0.id, $0.name) })
        let collectionNamesById = Dictionary(uniqueKeysWithValues: remoteCollections.map { ($0.id, $0.name) })

        for dto in remoteProducts {
            let categoryName = dto.categoryId.flatMap { categoryNamesById[$0] } ?? "Uncategorized"
            let collectionName = dto.collectionId.flatMap { collectionNamesById[$0] } ?? ""
            let fallbackImage = fallbackIcon(forCategory: categoryName)
            let resolvedImages = {
                let urls = dto.resolvedImageURLs.map(\.absoluteString)
                if !urls.isEmpty { return urls }
                return (dto.imageUrls ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }()
            let primaryImage = resolvedImages.first ?? fallbackImage
            let imageNames = resolvedImages.joined(separator: ",")

            if let local = localById[dto.id] {
                local.name = dto.name
                local.brand = dto.brand ?? "Maison Luxe"
                local.productDescription = dto.description ?? "Details coming soon."
                local.price = dto.price
                local.categoryName = categoryName
                local.imageName = primaryImage
                local.imageNames = imageNames
                local.sku = dto.sku
                local.productTypeName = collectionName
                local.createdAt = dto.createdAt
            } else {
                let product = Product(
                    name: dto.name,
                    brand: dto.brand ?? "Maison Luxe",
                    description: dto.description ?? "Details coming soon.",
                    price: dto.price,
                    categoryName: categoryName,
                    imageName: primaryImage,
                    isLimitedEdition: false,
                    isFeatured: false,
                    rating: 4.8,
                    stockCount: 10,
                    sku: dto.sku,
                    serialNumber: "",
                    rfidTagID: "",
                    certificateRef: "",
                    productTypeName: collectionName,
                    attributes: "{}",
                    imageNames: imageNames,
                    material: "",
                    countryOfOrigin: "",
                    weight: 0,
                    dimensions: ""
                )
                product.id = dto.id
                product.createdAt = dto.createdAt
                modelContext.insert(product)
                localById[dto.id] = product
            }
        }

        try modelContext.save()
    }

    private func fallbackIcon(forCategory name: String) -> String {
        let value = name.lowercased()
        if value.contains("watch") { return "clock.fill" }
        if value.contains("jewel") { return "sparkles" }
        if value.contains("couture") || value.contains("apparel") || value.contains("wear") {
            return "tshirt.fill"
        }
        return "bag.fill"
    }
}
 
// MARK: - Categories Sub-view

struct CatalogCategoriesSubview: View {
    @Environment(\.modelContext) private var modelContext
    @State private var remoteCategories: [CategoryDTO] = []
    @State private var remoteCollections: [BrandCollectionDTO] = []
    @State private var remoteProducts: [ProductDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingCategory: CategoryDTO?
    @State private var editingCollection: BrandCollectionDTO?
    @State private var showCreateCategory = false
    @State private var showCreateCollection = false

    private var activeCategories: [CategoryDTO] {
        remoteCategories.filter(\.isActive)
    }

    private var activeCollections: [BrandCollectionDTO] {
        remoteCollections.filter(\.isActive)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                headerCard

                if let errorMessage {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.error)
                        Text(errorMessage)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.error)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)
                    .background(AppColors.error.opacity(0.08))
                    .cornerRadius(AppSpacing.radiusMedium)
                }

                if isLoading && remoteCategories.isEmpty && remoteCollections.isEmpty {
                    ProgressView().tint(AppColors.accent)
                        .padding(.top, AppSpacing.xl)
                } else {
                    sectionHeader("Categories")
                    ForEach(activeCategories) { category in
                        categoryRow(category)
                    }

                    sectionHeader("Brand Collections")
                    ForEach(activeCollections) { collection in
                        collectionRow(collection)
                    }

                    if activeCollections.isEmpty {
                        Text("No active collections yet.")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.xs)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(
                mode: .edit(category),
                onSaved: {
                    Task { await loadAll() }
                }
            )
        }
        .sheet(item: $editingCollection) { collection in
            CollectionEditorSheet(
                mode: .edit(collection),
                onSaved: {
                    Task { await loadAll() }
                }
            )
        }
        .sheet(isPresented: $showCreateCategory) {
            CategoryEditorSheet(
                mode: .create,
                onSaved: {
                    Task { await loadAll() }
                }
            )
        }
        .sheet(isPresented: $showCreateCollection) {
            CollectionEditorSheet(
                mode: .create,
                onSaved: {
                    Task { await loadAll() }
                }
            )
        }
    }

    private var headerCard: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ORGANIZATION STUDIO")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Text("Control categories and brand collections used across catalog, product forms, and listings.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            VStack(spacing: AppSpacing.xs) {
                Button("New Category") { showCreateCategory = true }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textPrimaryLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.radiusSmall)
                Button("New Collection") { showCreateCollection = true }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppColors.accent.opacity(0.12))
                    .cornerRadius(AppSpacing.radiusSmall)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.textSecondaryDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.sm)
    }

    private func categoryRow(_ category: CategoryDTO) -> some View {
        let count = remoteProducts.filter { product in
            product.categoryId == category.id && product.isActive
        }.count

        return HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(AppColors.accent.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: fallbackIcon(forCategory: category.name))
                    .font(AppTypography.catalogIcon)
                    .foregroundColor(AppColors.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(category.description ?? "No description")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(count) SKUs")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.accent)

            Menu {
                Button("Edit") { editingCategory = category }
                Button(role: .destructive) {
                    Task { await deactivateCategory(category) }
                } label: {
                    Text("Delete")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppTypography.iconSmall)
                    .foregroundColor(AppColors.neutral500)
                    .frame(width: 28, height: AppSpacing.touchTarget)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func collectionRow(_ collection: BrandCollectionDTO) -> some View {
        let count = remoteProducts.filter { product in
            product.collectionId == collection.id && product.isActive
        }.count

        return HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(AppColors.accent.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(AppTypography.catalogIcon)
                    .foregroundColor(AppColors.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(collection.brand ?? "Maison Luxe")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(count) SKUs")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.accent)

            Menu {
                Button("Edit") { editingCollection = collection }
                Button(role: .destructive) {
                    Task { await deactivateCollection(collection) }
                } label: {
                    Text("Delete")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppTypography.iconSmall)
                    .foregroundColor(AppColors.neutral500)
                    .frame(width: 28, height: AppSpacing.touchTarget)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func fallbackIcon(forCategory name: String) -> String {
        let value = name.lowercased()
        if value.contains("watch") { return "clock.fill" }
        if value.contains("jewel") { return "sparkles" }
        if value.contains("shoe") { return "shoe.fill" }
        if value.contains("cloth") || value.contains("couture") { return "tshirt.fill" }
        return "bag.fill"
    }

    @MainActor
    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let categories = CatalogService.shared.fetchCategories()
            async let collections = CatalogService.shared.fetchCollections()
            async let products = CatalogService.shared.fetchProducts()
            let (loadedCategories, loadedCollections, loadedProducts) = try await (categories, collections, products)
            remoteCategories = loadedCategories
            remoteCollections = loadedCollections
            remoteProducts = loadedProducts
            errorMessage = nil
            try? await CustomerCatalogSyncService.shared.refreshLocalCatalog(modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deactivateCategory(_ category: CategoryDTO) async {
        do {
            _ = try await CatalogService.shared.deleteCategory(id: category.id)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deactivateCollection(_ collection: BrandCollectionDTO) async {
        do {
            _ = try await CatalogService.shared.deleteCollection(id: collection.id)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum CategoryEditorMode {
    case create
    case edit(CategoryDTO)

    var initialName: String {
        switch self {
        case .create: return ""
        case .edit(let category): return category.name
        }
    }

    var initialDescription: String {
        switch self {
        case .create: return ""
        case .edit(let category): return category.description ?? ""
        }
    }

    var initialIsActive: Bool {
        switch self {
        case .create: return true
        case .edit(let category): return category.isActive
        }
    }

    var title: String {
        switch self {
        case .create: return "New Category"
        case .edit: return "Edit Category"
        }
    }
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: CategoryEditorMode
    let onSaved: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                LuxuryTextField(placeholder: "Category Name", text: $name)
                LuxuryTextField(placeholder: "Description", text: $description)
                Toggle("Active", isOn: $isActive)
                    .tint(AppColors.accent)

                Button(action: save) {
                    Text(isSaving ? "Saving..." : "Save")
                        .font(AppTypography.buttonPrimary)
                        .foregroundColor(AppColors.textPrimaryLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.accent)
                        .cornerRadius(AppSpacing.radiusMedium)
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
            .background(AppColors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .onAppear {
                name = mode.initialName
                description = mode.initialDescription
                isActive = mode.initialIsActive
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                switch mode {
                case .create:
                    _ = try await CatalogService.shared.createCategory(
                        name: trimmedName,
                        description: description,
                        isActive: isActive
                    )
                case .edit(let category):
                    _ = try await CatalogService.shared.updateCategory(
                        id: category.id,
                        name: trimmedName,
                        description: description,
                        isActive: isActive
                    )
                }
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

private enum CollectionEditorMode {
    case create
    case edit(BrandCollectionDTO)

    var initialName: String {
        switch self {
        case .create: return ""
        case .edit(let collection): return collection.name
        }
    }

    var initialDescription: String {
        switch self {
        case .create: return ""
        case .edit(let collection): return collection.description ?? ""
        }
    }

    var initialBrand: String {
        switch self {
        case .create: return "Maison Luxe"
        case .edit(let collection): return collection.brand ?? "Maison Luxe"
        }
    }

    var initialIsActive: Bool {
        switch self {
        case .create: return true
        case .edit(let collection): return collection.isActive
        }
    }

    var title: String {
        switch self {
        case .create: return "New Collection"
        case .edit: return "Edit Collection"
        }
    }
}

private struct CollectionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: CollectionEditorMode
    let onSaved: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var brand = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                LuxuryTextField(placeholder: "Collection Name", text: $name)
                LuxuryTextField(placeholder: "Brand", text: $brand)
                LuxuryTextField(placeholder: "Description", text: $description)
                Toggle("Active", isOn: $isActive)
                    .tint(AppColors.accent)

                Button(action: save) {
                    Text(isSaving ? "Saving..." : "Save")
                        .font(AppTypography.buttonPrimary)
                        .foregroundColor(AppColors.textPrimaryLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.accent)
                        .cornerRadius(AppSpacing.radiusMedium)
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
            .background(AppColors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .onAppear {
                name = mode.initialName
                description = mode.initialDescription
                brand = mode.initialBrand
                isActive = mode.initialIsActive
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                switch mode {
                case .create:
                    _ = try await CatalogService.shared.createCollection(
                        name: trimmedName,
                        description: description,
                        brand: brand,
                        isActive: isActive
                    )
                case .edit(let collection):
                    _ = try await CatalogService.shared.updateCollection(
                        id: collection.id,
                        name: trimmedName,
                        description: description,
                        brand: brand,
                        isActive: isActive
                    )
                }
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
// MARK: - Pricing Sub-view

struct CatalogPricingSubview: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var policies: [PricingPolicySettings]
    @Query(sort: \IndianTaxRule.goodsCategory) private var taxRules: [IndianTaxRule]
    @Query private var regionalPriceRules: [RegionalPriceRule]
    @Query(sort: \Product.name) private var products: [Product]

    @State private var businessState: String = ""
    @State private var freeShippingThreshold: String = ""
    @State private var standardShippingFee: String = ""

    @State private var taxCategory: String = ""
    @State private var gstPercent: String = ""
    @State private var cessPercent: String = ""
    @State private var additionalTaxPercent: String = ""

    @State private var selectedProductId: UUID?
    @State private var regionalState: String = ""
    @State private var regionalPriceText: String = ""

    @State private var infoMessage: String = ""
    @State private var showInfoMessage = false

    private var policy: PricingPolicySettings {
        policies.first ?? PricingPolicySettings()
    }

    private var categoryOptions: [String] {
        let fromProducts = Set(products.map { $0.categoryName })
        let fromRules = Set(taxRules.map { $0.goodsCategory })
        return Array(fromProducts.union(fromRules)).sorted()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                policyCard
                taxConfigCard
                regionalPricingCard
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .onAppear {
            businessState = policy.businessState
            freeShippingThreshold = String(format: "%.0f", policy.freeShippingThreshold)
            standardShippingFee = String(format: "%.0f", policy.standardShippingFee)
        }
        .alert("Saved", isPresented: $showInfoMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage)
        }
    }

    private var policyCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header(title: "India Commerce Policy", subtitle: "Business state, shipping, and billing currency", icon: "building.columns")
            Divider().background(AppColors.border)

            LuxuryTextField(placeholder: "Business Registration State", text: $businessState)
            LuxuryTextField(placeholder: "Free Shipping Threshold", text: $freeShippingThreshold)
                .keyboardType(.decimalPad)
            LuxuryTextField(placeholder: "Standard Shipping Fee", text: $standardShippingFee)
                .keyboardType(.decimalPad)

            HStack {
                Text("Currency")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text("INR")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.accent)
            }

            Button(action: savePolicy) {
                Text("Save Policy")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.radiusMedium)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }

    private var taxConfigCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header(title: "GST Rules by Goods", subtitle: "CGST/SGST or IGST will be auto-applied at checkout", icon: "percent")
            Divider().background(AppColors.border)

            ForEach(taxRules) { rule in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.goodsCategory)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("GST \(rule.gstPercent.formatted(.number.precision(.fractionLength(0...2))))% · Cess \(rule.cessPercent.formatted(.number.precision(.fractionLength(0...2))))%")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Button(rule.isActive ? "Disable" : "Enable") {
                        rule.isActive.toggle()
                        rule.updatedAt = Date()
                        try? modelContext.save()
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
                }
            }

            Divider().background(AppColors.border)

            Menu {
                ForEach(categoryOptions, id: \.self) { category in
                    Button(category) { taxCategory = category }
                }
            } label: {
                HStack {
                    Text(taxCategory.isEmpty ? "Select Goods Category" : taxCategory)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(taxCategory.isEmpty ? AppColors.neutral500 : AppColors.textPrimaryDark)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(AppColors.neutral500)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppColors.backgroundPrimary)
                .cornerRadius(AppSpacing.radiusMedium)
            }

            LuxuryTextField(placeholder: "GST % (e.g. 18)", text: $gstPercent).keyboardType(.decimalPad)
            LuxuryTextField(placeholder: "Compensation Cess % (optional)", text: $cessPercent).keyboardType(.decimalPad)
            LuxuryTextField(placeholder: "Other Tax % (optional)", text: $additionalTaxPercent).keyboardType(.decimalPad)

            Button(action: saveTaxRule) {
                Text("Save GST Rule")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.radiusMedium)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }

    private var regionalPricingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header(title: "Regional Product Pricing", subtitle: "Override SKU prices by buyer state", icon: "map")
            Divider().background(AppColors.border)

            Menu {
                ForEach(products) { product in
                    Button(product.name) { selectedProductId = product.id }
                }
            } label: {
                HStack {
                    Text(selectedProductName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(selectedProductId == nil ? AppColors.neutral500 : AppColors.textPrimaryDark)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(AppColors.neutral500)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppColors.backgroundPrimary)
                .cornerRadius(AppSpacing.radiusMedium)
            }

            LuxuryTextField(placeholder: "Region State (e.g. Karnataka)", text: $regionalState)
            LuxuryTextField(placeholder: "Override Price (INR)", text: $regionalPriceText).keyboardType(.decimalPad)

            Button(action: saveRegionalPriceRule) {
                Text("Save Regional Price")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.radiusMedium)
            }

            Divider().background(AppColors.border)
            ForEach(regionalPriceRules) { rule in
                HStack {
                    Text("\(productName(for: rule.productId)) · \(rule.regionState)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                    Text(formatCurrency(rule.overridePrice))
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }

    private var selectedProductName: String {
        guard let selectedProductId else { return "Select Product" }
        return products.first(where: { $0.id == selectedProductId })?.name ?? "Select Product"
    }

    private func header(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon).font(AppTypography.iconMedium).foregroundColor(AppColors.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Text(subtitle).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
        }
    }

    private func savePolicy() {
        guard let threshold = Double(freeShippingThreshold),
              let shippingFee = Double(standardShippingFee),
              !businessState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            infoMessage = "Enter valid state and shipping values."
            showInfoMessage = true
            return
        }

        let target = policies.first ?? PricingPolicySettings()
        if policies.isEmpty { modelContext.insert(target) }

        target.businessState = businessState.trimmingCharacters(in: .whitespacesAndNewlines)
        target.currencyCode = "INR"
        target.freeShippingThreshold = threshold
        target.standardShippingFee = shippingFee
        target.updatedAt = Date()
        try? modelContext.save()

        infoMessage = "India commerce policy saved."
        showInfoMessage = true
    }

    private func saveTaxRule() {
        guard !taxCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let gst = Double(gstPercent) else {
            infoMessage = "Select a goods category and GST percentage."
            showInfoMessage = true
            return
        }

        let cess = Double(cessPercent) ?? 0
        let additional = Double(additionalTaxPercent) ?? 0
        let normalizedCategory = taxCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = taxRules.first {
            $0.goodsCategory.caseInsensitiveCompare(normalizedCategory) == .orderedSame
        }

        if let existing {
            existing.gstPercent = gst
            existing.cessPercent = cess
            existing.additionalLevyPercent = additional
            existing.isActive = true
            existing.updatedAt = Date()
        } else {
            modelContext.insert(
                IndianTaxRule(
                    goodsCategory: normalizedCategory,
                    gstPercent: gst,
                    cessPercent: cess,
                    additionalLevyPercent: additional
                )
            )
        }
        try? modelContext.save()

        infoMessage = "GST rule saved."
        showInfoMessage = true
    }

    private func saveRegionalPriceRule() {
        guard let selectedProductId,
              !regionalState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let overridePrice = Double(regionalPriceText),
              overridePrice > 0 else {
            infoMessage = "Select a product and enter valid state and price."
            showInfoMessage = true
            return
        }

        let normalizedState = regionalState.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = regionalPriceRules.first(where: {
            $0.productId == selectedProductId &&
            IndianPricingEngine.normalizeState($0.regionState) == IndianPricingEngine.normalizeState(normalizedState)
        }) {
            existing.overridePrice = overridePrice
            existing.isActive = true
            existing.updatedAt = Date()
        } else {
            modelContext.insert(
                RegionalPriceRule(
                    productId: selectedProductId,
                    regionState: normalizedState,
                    overridePrice: overridePrice
                )
            )
        }
        try? modelContext.save()

        infoMessage = "Regional pricing rule saved."
        showInfoMessage = true
    }

    private func productName(for id: UUID) -> String {
        products.first(where: { $0.id == id })?.name ?? "Unknown Product"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }
}

// MARK: - Promotions Sub-view

struct CatalogPromotionsSubview: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var promotions: [PromotionDTO] = []
    @State private var remoteProducts: [ProductDTO] = []
    @State private var remoteCategories: [CategoryDTO] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                promotionsHeroCard

                if let errorMessage {
                    errorBanner(message: errorMessage)
                }

                if isLoading && promotions.isEmpty {
                    ProgressView()
                        .tint(AppColors.accent)
                        .padding(.top, AppSpacing.xl)
                } else if promotions.isEmpty {
                    emptyState
                } else {
                    ForEach(promotions) { promotion in
                        promotionCard(promotion)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .sheet(isPresented: $showCreateSheet) {
            PromotionComposerSheet(
                products: remoteProducts,
                categories: remoteCategories,
                createdBy: appState.currentUserProfile?.id,
                onSaved: {
                    Task {
                        await loadAll()
                        try? await PromotionSyncService.shared.refreshLocalPromotions(modelContext: modelContext)
                    }
                }
            )
        }
    }

    private var promotionsHeroCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Top row: overline label + New Offer button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OFFERS STUDIO")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.5)
                        .foregroundColor(AppColors.accent)
                    Text("Luxury promotions,\nlive at every checkout.")
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineSpacing(2)
                }
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New Offer")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                }
                .padding(.top, 2)
            }

            // Thin accent rule
            Rectangle()
                .fill(AppColors.accent.opacity(0.20))
                .frame(height: 0.5)

            // Metrics row
            HStack(spacing: 0) {
                heroMetric(value: activeCount,    label: "LIVE",      valueColor: AppColors.success)
                heroMetricDivider()
                heroMetric(value: scheduledCount, label: "SCHEDULED", valueColor: AppColors.textSecondaryDark)
                heroMetricDivider()
                heroMetric(value: expiredCount,   label: "ARCHIVE",   valueColor: AppColors.textSecondaryDark)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func heroMetric(value: Int, label: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(value > 0 ? valueColor : AppColors.neutral500)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroMetricDivider() -> some View {
        Rectangle()
            .fill(AppColors.border)
            .frame(width: 0.5, height: 32)
            .padding(.horizontal, AppSpacing.sm)
    }

    private var activeCount: Int {
        promotions.filter { displayStatus(for: $0) == .active }.count
    }

    private var scheduledCount: Int {
        promotions.filter { displayStatus(for: $0) == .scheduled }.count
    }

    private var expiredCount: Int {
        promotions.filter { displayStatus(for: $0) == .expired || displayStatus(for: $0) == .inactive }.count
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.07))
                    .frame(width: 72, height: 72)
                Image(systemName: "tag.slash")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(AppColors.accent.opacity(0.6))
            }
            VStack(spacing: 6) {
                Text("No active offers")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Create a promotion for a product or category\nand it flows into every checkout automatically.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
        .padding(.horizontal, AppSpacing.xl)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
    }

    private func promotionCard(_ promotion: PromotionDTO) -> some View {
        let status = displayStatus(for: promotion)
        return HStack(spacing: 0) {
            // Left status stripe
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(status.color)
                .frame(width: 3)
                .padding(.vertical, AppSpacing.sm)
                .padding(.leading, AppSpacing.sm)

            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(promotion.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimaryDark)
                        // Scope chip
                        Text(targetDescription(for: promotion).uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.2)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    // Status pill
                    HStack(spacing: 4) {
                        Circle()
                            .fill(status.color)
                            .frame(width: 6, height: 6)
                        Text(status.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(status.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.10))
                    .clipShape(Capsule())
                }

                // Discount hero number
                Text(discountDescription(for: promotion))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accent)

                // Note (if any)
                if let details = promotion.details, !details.isEmpty {
                    Text(details)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(2)
                }

                // Date range
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.neutral500)
                    Text("\(shortDate(promotion.startsAt)) – \(shortDate(promotion.endsAt))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppColors.neutral500)
                }

                // Divider + action
                Divider()
                Button(action: { togglePromotionState(promotion) }) {
                    HStack(spacing: 5) {
                        Image(systemName: promotion.isActive ? "pause.circle" : "play.circle")
                            .font(.system(size: 13))
                        Text(promotion.isActive ? "Pause Offer" : "Resume Offer")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(promotion.isActive ? AppColors.neutral500 : AppColors.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.md)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.error)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }

    private func discountDescription(for promotion: PromotionDTO) -> String {
        switch PromotionDiscountType(rawValue: promotion.promotionDiscountType) {
        case .percentage:
            return "\(promotion.discountValue.formatted(.number.precision(.fractionLength(0...1))))% off"
        case .fixedAmount:
            return formatCurrency(promotion.discountValue) + " off"
        case .bogo, .none:
            return "Special Offer"
        }
    }

    private func targetDescription(for promotion: PromotionDTO) -> String {
        switch PromotionScope(rawValue: promotion.promotionScope) {
        case .product:
            let productName = remoteProducts.first(where: { $0.id == promotion.targetProductId })?.name ?? "Selected Product"
            return "Product · \(productName)"
        case .category:
            let categoryName = remoteCategories.first(where: { $0.id == promotion.targetCategoryId })?.name ?? "Selected Category"
            return "Category · \(categoryName)"
        case .storeWide, .none:
            return "Store-wide Promotion"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: value)) ?? "INR \(value)"
    }

    private func statusPill(_ status: PromotionCardStatus) -> some View {
        Text(status.label)
            .font(AppTypography.nano)
            .foregroundColor(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.12))
            .cornerRadius(6)
    }

    private func displayStatus(for promotion: PromotionDTO) -> PromotionCardStatus {
        guard promotion.isActive else { return .inactive }
        let now = Date()
        if now < promotion.startsAt { return .scheduled }
        if now > promotion.endsAt { return .expired }
        return .active
    }

    private func togglePromotionState(_ promotion: PromotionDTO) {
        Task {
            do {
                _ = try await PromotionService.shared.setPromotionActiveState(
                    id: promotion.id,
                    isActive: !promotion.isActive
                )
                try? await PromotionSyncService.shared.refreshLocalPromotions(modelContext: modelContext)
                await loadAll()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let promos = PromotionService.shared.fetchPromotions()
            async let products = CatalogService.shared.fetchProducts()
            async let categories = CatalogService.shared.fetchCategories()
            let (loadedPromotions, loadedProducts, loadedCategories) = try await (promos, products, categories)
            promotions = loadedPromotions
            remoteProducts = loadedProducts
            remoteCategories = loadedCategories
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum PromotionCardStatus {
    case active
    case scheduled
    case expired
    case inactive

    var label: String {
        switch self {
        case .active: return "ACTIVE"
        case .scheduled: return "SCHEDULED"
        case .expired: return "ENDED"
        case .inactive: return "PAUSED"
        }
    }

    var color: Color {
        switch self {
        case .active: return AppColors.success
        case .scheduled: return AppColors.info
        case .expired: return AppColors.neutral500
        case .inactive: return AppColors.warning
        }
    }
}

private struct PromotionComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let products: [ProductDTO]
    let categories: [CategoryDTO]
    let createdBy: UUID?
    let onSaved: () -> Void

    @State private var name = ""
    @State private var details = ""
    @State private var scope: PromotionScope = .product
    @State private var discountType: PromotionDiscountType = .percentage
    @State private var selectedProductId: UUID?
    @State private var selectedCategoryId: UUID?
    @State private var discountValue = ""
    @State private var startsAt = Date()
    @State private var endsAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isActive = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var saveDisabled: Bool {
        isSaving ||
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        Double(discountValue) == nil ||
        startsAt > endsAt ||
        (scope == .product && selectedProductId == nil) ||
        (scope == .category && selectedCategoryId == nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    introCard

                    formCard(title: "Offer Identity") {
                        LuxuryTextField(placeholder: "Offer name", text: $name)
                        LuxuryTextField(placeholder: "Private note or campaign message", text: $details)
                    }

                    formCard(title: "Target") {
                        Picker("Scope", selection: $scope) {
                            ForEach(PromotionScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)

                        if scope == .product {
                            targetMenu(
                                title: selectedProductName,
                                options: products.map { ($0.id, $0.name) },
                                selection: $selectedProductId
                            )
                        } else {
                            targetMenu(
                                title: selectedCategoryName,
                                options: categories.map { ($0.id, $0.name) },
                                selection: $selectedCategoryId
                            )
                        }
                    }

                    formCard(title: "Discount") {
                        Picker("Discount Type", selection: $discountType) {
                            ForEach(PromotionDiscountType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        LuxuryTextField(
                            placeholder: discountType == .percentage ? "Discount % (e.g. 12)" : "Discount amount (INR)",
                            text: $discountValue
                        )
                        .keyboardType(.decimalPad)
                    }

                    formCard(title: "Schedule") {
                        DatePicker("Starts", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                            .tint(AppColors.accent)
                        DatePicker("Ends", selection: $endsAt, displayedComponents: [.date, .hourAndMinute])
                            .tint(AppColors.accent)
                        Toggle("Offer is active", isOn: $isActive)
                            .tint(AppColors.accent)
                    }

                    if let errorMessage {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.error)
                            Text(errorMessage)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.error)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.sm)
                        .background(AppColors.error.opacity(0.08))
                        .cornerRadius(AppSpacing.radiusMedium)
                    }

                    Button(action: savePromotion) {
                        HStack(spacing: AppSpacing.xs) {
                            if isSaving {
                                ProgressView()
                                    .tint(AppColors.textPrimaryLight)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Create Offer")
                            }
                        }
                        .font(AppTypography.buttonPrimary)
                        .foregroundColor(AppColors.textPrimaryLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(saveDisabled ? AppColors.accent.opacity(0.4) : AppColors.accent)
                        .cornerRadius(AppSpacing.radiusMedium)
                    }
                    .disabled(saveDisabled)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .background(AppColors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("New Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .onChange(of: scope) { _, newValue in
                if newValue == .product {
                    selectedCategoryId = nil
                } else {
                    selectedProductId = nil
                }
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("CLIENTELING READY")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
            Text("Every eligible checkout picks up the rule automatically.")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
    }

    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.textSecondaryDark)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func targetMenu(
        title: String,
        options: [(UUID, String)],
        selection: Binding<UUID?>
    ) -> some View {
        Menu {
            ForEach(options, id: \.0) { option in
                Button(option.1) { selection.wrappedValue = option.0 }
            }
        } label: {
            HStack {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(selection.wrappedValue == nil ? AppColors.neutral500 : AppColors.textPrimaryDark)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(AppColors.neutral500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.backgroundPrimary)
            .cornerRadius(AppSpacing.radiusMedium)
        }
    }

    private var selectedProductName: String {
        products.first(where: { $0.id == selectedProductId })?.name ?? "Select Product"
    }

    private var selectedCategoryName: String {
        categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Select Category"
    }

    private func savePromotion() {
        guard let discountValue = Double(discountValue) else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                _ = try await PromotionService.shared.createPromotion(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                    scope: scope,
                    targetProductId: scope == .product ? selectedProductId : nil,
                    targetCategoryId: scope == .category ? selectedCategoryId : nil,
                    discountType: discountType,
                    discountValue: discountValue,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    isActive: isActive,
                    createdBy: createdBy
                )
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    CatalogView()
        .modelContainer(
            for: [
                Product.self,
                Category.self,
                PricingPolicySettings.self,
                IndianTaxRule.self,
                RegionalPriceRule.self,
                PromotionRule.self
            ],
            inMemory: true
        )
}
