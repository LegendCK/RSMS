//
//  AddProductView.swift
//  RSMS
//
//  Sheet for creating a new product SKU.
//  Supports multi-photo upload, category linking, and full attribute entry.
//  Saves to Supabase `products` table + Storage, and SwiftData.
//
//  Acceptance criteria:
//  - Admin can create a new SKU with product details
//  - Admin can set price, description, category
//  - System validates mandatory fields (SKU, Name, Price, Category) before saving
//  - Changes reflect across all stores via Supabase
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - View

struct AddProductView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Passed-in categories so the picker is pre-populated
    let availableCategories: [Category]

    // Photo selection
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    // Core fields (mandatory)
    @State private var sku: String = ""
    @State private var productName: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var priceText: String = ""

    @State private var brand: String = ""
    @State private var costPriceText: String = ""
    @State private var descriptionText: String = ""

    // Toggles
    @State private var isActive: Bool = true
    @State private var isLimitedEdition: Bool = false

    // UI state
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showPhotosPicker: Bool = false

    private var isFormValid: Bool {
        !sku.trimmingCharacters(in: .whitespaces).isEmpty &&
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedCategory != nil &&
        priceDouble != nil
    }

    private var priceDouble: Double? {
        Double(priceText.replacingOccurrences(of: ",", with: "."))
    }

    private var costPriceDouble: Double? {
        let t = costPriceText.replacingOccurrences(of: ",", with: ".")
        return t.isEmpty ? nil : Double(t)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {

                        // MARK: Photo Section
                        photoSection

                        // MARK: Mandatory Fields Card
                        formCard("Product Details — Required") {
                            // SKU
                            fieldRow(label: "SKU *") {
                                HStack(spacing: AppSpacing.xs) {
                                    TextField("e.g. BAG-20260313-4821", text: $sku)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Button(action: generateSKU) {
                                        Text("Auto")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.accent.opacity(0.15))
                                            .cornerRadius(AppSpacing.radiusSmall)
                                    }
                                }
                            }

                            divider

                            // Product Name
                            fieldRow(label: "Name *") {
                                TextField("e.g. Classic Monogram Tote", text: $productName)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }

                            divider

                            // Category
                            fieldRow(label: "Category *") {
                                Menu {
                                    Button("No Category") { selectedCategory = nil }
                                    Divider()
                                    ForEach(availableCategories) { cat in
                                        Button(cat.name) { selectedCategory = cat }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedCategory?.name ?? "Select…")
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(
                                                selectedCategory == nil
                                                    ? AppColors.neutral500
                                                    : AppColors.textPrimaryDark
                                            )
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.neutral500)
                                    }
                                }
                            }

                            divider

                            // Price
                            fieldRow(label: "Price (USD) *") {
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.neutral500)
                                    TextField("0.00", text: $priceText)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                        .keyboardType(.decimalPad)
                                }
                            }
                        }

                        // MARK: Optional Fields Card
                        formCard("Additional Details") {
                            // Brand
                            fieldRow(label: "Brand") {
                                TextField("e.g. Louis Vuitton", text: $brand)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }

                            divider

                            // Cost Price
                            fieldRow(label: "Cost Price (USD)") {
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.neutral500)
                                    TextField("0.00", text: $costPriceText)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                        .keyboardType(.decimalPad)
                                }
                            }
                        }

                        // MARK: Description
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            sectionLabel("Description")
                            TextField(
                                "Product description visible to customers and staff…",
                                text: $descriptionText,
                                axis: .vertical
                            )
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .lineLimit(4...8)
                            .padding(AppSpacing.sm)
                            .background(AppColors.backgroundSecondary)
                            .cornerRadius(AppSpacing.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // MARK: Toggles Card
                        formCard("Visibility & Flags") {
                            toggleRow(
                                label: "Active",
                                subtitle: "Visible across all stores",
                                isOn: $isActive
                            )
                            divider
                            toggleRow(
                                label: "Limited Edition",
                                subtitle: "Marks product with LTD badge",
                                isOn: $isLimitedEdition
                            )
                        }

                        // Error banner
                        if let err = errorMessage {
                            HStack(alignment: .top, spacing: AppSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.error)
                                    .padding(.top, 1)
                                Text(err)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(AppSpacing.sm)
                            .background(AppColors.error.opacity(0.1))
                            .cornerRadius(AppSpacing.radiusMedium)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // Validation hints
                        if !isFormValid {
                            validationHints
                        }

                        // MARK: Save button
                        Button(action: save) {
                            HStack(spacing: AppSpacing.xs) {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(tint: AppColors.primary)
                                        )
                                        .scaleEffect(0.85)
                                    Text("Saving…")
                                } else {
                                    Image(systemName: "checkmark")
                                    Text("Create Product")
                                }
                            }
                            .font(AppTypography.buttonPrimary)
                            .foregroundColor(AppColors.textPrimaryLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                isFormValid && !isSaving
                                    ? AppColors.accent
                                    : AppColors.accent.opacity(0.4)
                            )
                            .cornerRadius(AppSpacing.radiusMedium)
                        }
                        .disabled(!isFormValid || isSaving)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                    .padding(.top, AppSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Product")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.accent)
                }
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: 8,
                matching: .images
            )
            // FIX: Use the no-argument closure form — safest across iOS 17+ and Xcode 26
            .onChange(of: selectedPhotoItems) {
                loadImages(from: selectedPhotoItems)
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionLabel("Product Photos")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // Add photo button
                    Button(action: { showPhotosPicker = true }) {
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: "plus")
                                .font(AppTypography.iconMedium)
                                .foregroundColor(AppColors.accent)
                            Text("Add Photos")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .frame(width: 90, height: 90)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        // FIX: single .stroke() call with StrokeStyle for dashed border
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(
                                    AppColors.accent.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                        )
                    }

                    // Thumbnails
                    ForEach(selectedImages.indices, id: \.self) { idx in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: selectedImages[idx])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipped()
                                .cornerRadius(AppSpacing.radiusMedium)

                            // Remove button
                            Button(action: { removeImage(at: idx) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.error)
                                    .background(
                                        Circle()
                                            .fill(AppColors.backgroundPrimary)
                                            .frame(width: 14, height: 14)
                                    )
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }

            if !selectedImages.isEmpty {
                Text(
                    "\(selectedImages.count) photo\(selectedImages.count == 1 ? "" : "s") selected"
                )
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }

    // MARK: - Validation Hints

    private var validationHints: some View {
        VStack(alignment: .leading, spacing: 4) {
            if sku.trimmingCharacters(in: .whitespaces).isEmpty {
                hintRow("SKU is required")
            }
            if productName.trimmingCharacters(in: .whitespaces).isEmpty {
                hintRow("Product name is required")
            }
            if selectedCategory == nil {
                hintRow("Please select a category")
            }
            if priceDouble == nil && !priceText.isEmpty {
                hintRow("Enter a valid price (e.g. 1299.99)")
            } else if priceText.isEmpty {
                hintRow("Price is required")
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func hintRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundColor(AppColors.warning)
            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.warning)
        }
    }

    // MARK: - Reusable Sub-views

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .foregroundColor(AppColors.textSecondaryDark)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func formCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xs)

            VStack(spacing: 0) { content() }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusMedium)
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private func fieldRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 120, alignment: .leading)
            content()
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func toggleRow(label: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(AppColors.accent)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var divider: some View {
        Divider()
            .background(AppColors.border)
            .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func generateSKU() {
        let prefix = selectedCategory.map {
            String($0.name.prefix(3)).uppercased()
        } ?? "SKU"
        sku = CatalogService.generateSKU(prefix: prefix)
    }

    private func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        if index < selectedPhotoItems.count {
            selectedPhotoItems.remove(at: index)
        }
    }

    // FIX: Use async/await loadTransferable — eliminates Swift 6 Sendable concurrency error
    // that occurred with the old callback-based loadTransferable + DispatchQueue.main.async pattern.
    private func loadImages(from items: [PhotosPickerItem]) {
        Task { @MainActor in
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image)
                }
            }
            selectedImages = loaded
        }
    }

    // MARK: - Save Logic

    private func save() {
        guard isFormValid, let price = priceDouble else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Compress picked images to JPEG for upload
                let imageDataList: [Data] = selectedImages.compactMap {
                    $0.jpegData(compressionQuality: 0.8)
                }

                let dto = try await CatalogService.shared.createProduct(
                    sku: sku.trimmingCharacters(in: .whitespaces),
                    name: productName.trimmingCharacters(in: .whitespaces),
                    brand: brand.trimmingCharacters(in: .whitespaces),
                    categoryId: nil, // local SwiftData Category has no Supabase UUID mapping
                    price: price,
                    costPrice: costPriceDouble,
                    description: descriptionText.trimmingCharacters(in: .whitespaces),
                    isActive: isActive,
                    imageDataList: imageDataList,
                    createdBy: nil
                )
                print("[AddProductView] Created product in Supabase: \(dto.id)")

                persistToSwiftData()
                dismiss()

            } catch {
                print("[AddProductView] Supabase error: \(error)")
                // Fallback: save locally and show brief error
                persistToSwiftData()
                errorMessage = "Saved locally. Supabase sync failed: \(error.localizedDescription)"
                isSaving = false
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            }
        }
    }

    private func persistToSwiftData() {
        let product = Product(
            name: productName.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            description: descriptionText.trimmingCharacters(in: .whitespaces),
            price: priceDouble ?? 0,
            categoryName: selectedCategory?.name ?? "Uncategorized",
            imageName: selectedCategory?.icon ?? "bag.fill",
            isLimitedEdition: isLimitedEdition,
            isFeatured: false,
            rating: 0,
            stockCount: 0,
            sku: sku.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(product)
        try? modelContext.save()
    }
}

#Preview {
    AddProductView(availableCategories: [])
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
