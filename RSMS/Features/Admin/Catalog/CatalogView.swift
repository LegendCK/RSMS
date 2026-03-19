
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
                        print("Failed to parse CSV: \\(error)")
                    }
                case .failure(let err):
                    print("Failed to import file: \\(err)")
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
                        ForEach(filtered) { dto in
                            if let localProduct = localProducts.first(where: { $0.id == dto.id }) {
                                NavigationLink(destination: ProductDetailView(product: localProduct)) {
                                    productRow(dto)
                                }
                                .buttonStyle(.plain)
                            } else {
                                productRow(dto)
                                    .opacity(0.5)
                            }
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
        }
        .padding(AppSpacing.sm)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
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
            let (c, p) = try await (cats, prods)
            remoteCategories = c
            remoteProducts   = p
        } catch {
            print("[CatalogProductsSubview] Load failed: \(error)")
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
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
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
