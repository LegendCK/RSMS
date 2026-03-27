//
//  AddProductsView.swift
//  RSMS
//

import SwiftUI
import SwiftData

struct AddProductsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allProducts: [Product]
    
    @Binding var selectedProducts: [Product]
    @State private var searchText = ""
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return allProducts
        } else {
            return allProducts.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredProducts) { product in
                Button {
                    toggleSelection(of: product)
                } label: {
                    HStack(spacing: 12) {
                        ProductArtworkView(
                            imageSource: product.imageList.first ?? product.imageName,
                            fallbackSymbol: "bag.fill",
                            cornerRadius: 10
                        )
                        .frame(width: 50, height: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text(product.brand)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(product.formattedPrice)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                        
                        Spacer()
                        
                        let isSelected = selectedProducts.contains(where: { $0.id == product.id })
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? AppColors.accent : Color(.tertiaryLabel))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search products by name or brand")
        .navigationTitle("Select Products")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accent)
            }
        }
    }
    
    private func toggleSelection(of product: Product) {
        if let index = selectedProducts.firstIndex(where: { $0.id == product.id }) {
            selectedProducts.remove(at: index)
        } else {
            selectedProducts.append(product)
        }
    }
}
