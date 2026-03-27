//
//  CreateLookView.swift
//  RSMS
//

import SwiftUI
import SwiftData

struct CreateLookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let onSaved: (() -> Void)?

    @State private var lookName = ""
    @State private var isShared = true
    @State private var selectedProducts: [Product] = []
    @State private var selectedThumbnailProductId: UUID?
    @State private var showAddProducts = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    private var isValid: Bool {
        !lookName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedProducts.isEmpty
    }

    var body: some View {
        Form {
            Section("Look Details") {
                TextField("Name this look (e.g. Summer Gala)", text: $lookName)
                Toggle("Share with team", isOn: $isShared)
                    .tint(AppColors.accent)
            }

            if !selectedProducts.isEmpty {
                thumbnailSection
            }
            
            Section {
                Button {
                    showAddProducts = true
                } label: {
                    Label("Add Products", systemImage: "plus.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
                
                ForEach(selectedProducts) { product in
                    HStack(spacing: 12) {
                        ProductArtworkView(
                            imageSource: product.imageList.first ?? product.imageName,
                            fallbackSymbol: "bag.fill",
                            cornerRadius: 8
                        )
                        .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text(product.brand)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(product.formattedPrice)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .onDelete { indexSet in
                    selectedProducts.remove(atOffsets: indexSet)
                }
            } header: {
                Text("Selected Pieces (\(selectedProducts.count))")
            } footer: {
                if selectedProducts.isEmpty {
                    Text("Select at least one product to create a Look.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("New Look")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.secondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { Task { await saveLook() } }
                    .fontWeight(.bold)
                    .foregroundColor(isValid ? AppColors.accent : .gray)
                    .disabled(!isValid || isSaving)
            }
        }
        .sheet(isPresented: $showAddProducts) {
            NavigationStack {
                AddProductsView(selectedProducts: $selectedProducts)
            }
        }
        .onChange(of: selectedProducts.map(\.id)) { _, _ in
            if let selectedThumbnailProductId,
               selectedProducts.contains(where: { $0.id == selectedThumbnailProductId }) {
                return
            }
            selectedThumbnailProductId = selectedProducts.first?.id
        }
    }

    private var thumbnailSection: some View {
        Section(
            header: Text("Main Thumbnail"),
            footer: Text("Choose which image appears as the look cover.")
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(selectedProducts) { product in
                        thumbnailChip(product)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func thumbnailChip(_ product: Product) -> some View {
        let isSelected = selectedThumbnailProductId == product.id
        return Button {
            selectedThumbnailProductId = product.id
        } label: {
            VStack(spacing: 6) {
                ProductArtworkView(
                    imageSource: product.imageList.first ?? product.imageName,
                    fallbackSymbol: "bag.fill",
                    cornerRadius: 10
                )
                .frame(width: 72, height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
                )

                Text(product.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 90)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func saveLook() async {
        let trimmedName = lookName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedProducts.isEmpty else { return }

        guard let creatorId = appState.currentUserProfile?.id else {
            errorMessage = "Sign in again to create looks."
            return
        }
        guard let storeId = appState.currentStoreId else {
            errorMessage = "No store is linked to this profile."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let thumbnailProduct = selectedProducts.first(where: { $0.id == selectedThumbnailProductId }) ?? selectedProducts.first
            let thumbnailSource = thumbnailProduct.map { $0.imageList.first ?? $0.imageName }

            _ = try await SalesLooksService.shared.createLook(
                storeId: storeId,
                creatorId: creatorId,
                creatorName: appState.currentUserName,
                name: trimmedName,
                productIds: selectedProducts.map { $0.id },
                thumbnailSource: thumbnailSource,
                isShared: isShared
            )
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
