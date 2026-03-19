
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
        .modelContainer(
            for: [
                Product.self,
                Category.self,
                PricingPolicySettings.self,
                IndianTaxRule.self,
                RegionalPriceRule.self
            ],
            inMemory: true
        )
}
