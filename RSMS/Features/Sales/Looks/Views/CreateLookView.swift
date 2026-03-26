//
//  CreateLookView.swift
//  RSMS
//

import SwiftUI
import SwiftData

struct CreateLookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var lookName = ""
    @State private var isShared = true
    @State private var selectedProducts: [Product] = []
    @State private var showAddProducts = false
    
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
            
            Section {
                Button {
                    showAddProducts = true
                } label: {
                    Label("Add Products", systemImage: "plus.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
                
                ForEach(selectedProducts) { product in
                    HStack(spacing: 12) {
                        Image(systemName: product.imageName.isEmpty ? "bag.fill" : product.imageName)
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
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
        }
        .navigationTitle("New Look")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.secondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveLook() }
                    .fontWeight(.bold)
                    .foregroundColor(isValid ? AppColors.accent : .gray)
                    .disabled(!isValid)
            }
        }
        .sheet(isPresented: $showAddProducts) {
            NavigationStack {
                AddProductsView(selectedProducts: $selectedProducts)
            }
        }
    }
    
    private func saveLook() {
        let newLook = Look(
            name: lookName.trimmingCharacters(in: .whitespaces),
            creatorId: appState.currentUserProfile?.id ?? UUID(),
            creatorName: appState.currentUserName,
            productIds: selectedProducts.map { $0.id },
            isShared: isShared
        )
        modelContext.insert(newLook)
        try? modelContext.save()
        
        dismiss()
    }
}
