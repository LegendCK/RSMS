//
//  CSVPreviewView.swift
//  RSMS
//

import SwiftUI

struct CSVPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let rows: [CSVProductRow]
    
    @State private var isUploading = false
    @State private var uploadFailedError: String?
    @State private var showSuccessSummary = false
    
    var validRows: [CSVProductRow] {
        rows.filter { $0.isValid }
    }
    
    var invalidRows: [CSVProductRow] {
        rows.filter { !$0.isValid }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if showSuccessSummary {
                    successSummaryView
                } else {
                    previewContent
                }
            }
            .navigationTitle(showSuccessSummary ? "Upload Summary" : "CSV Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isUploading && !showSuccessSummary {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isUploading && !showSuccessSummary {
                        Button("Upload \(validRows.count) Valid") {
                            Task {
                                await uploadValidRows()
                            }
                        }
                        .fontWeight(.bold)
                        .disabled(validRows.isEmpty)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isUploading || showSuccessSummary)
    }
    
    private var previewContent: some View {
        VStack(spacing: 0) {
            // Metrics Header
            HStack(spacing: 16) {
                metricBox(title: "TOTAL", count: rows.count, color: .primary)
                metricBox(title: "VALID", count: validRows.count, color: .green)
                metricBox(title: "INVALID", count: invalidRows.count, color: .red)

            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 5)
            .zIndex(1)
            
            if let error = uploadFailedError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
            }
            
            List {
                ForEach(rows) { row in
                    CSVRowCell(row: row)
                }
            }
            .listStyle(.plain)
            .overlay {
                if isUploading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Uploading...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var successSummaryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
            
            Text("\(validRows.count) Products Uploaded Successfully")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("The catalog definitions have been created. \\n**Add stock** to generate their unique barcodes.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
    }
    
    private func metricBox(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func uploadValidRows() async {
        isUploading = true
        uploadFailedError = nil
        
        // Map to strict DTO
        let dtos = validRows.map { row in
            ProductInsertDTO(
                sku: row.sku,
                name: row.name,
                brand: row.brand.isEmpty ? nil : row.brand,
                categoryId: nil, // Default uncategorized for CSV initially
                collectionId: nil,
                taxCategoryId: nil,
                description: row.description.isEmpty ? nil : row.description,
                price: row.parsedPrice,
                costPrice: nil,
                imageUrls: nil,
                isActive: true,
                createdBy: nil
            )
        }
        
        do {
            try await CatalogService.shared.createProductsBulk(products: dtos)
            isUploading = false
            withAnimation {
                showSuccessSummary = true
            }
        } catch {
            isUploading = false
            uploadFailedError = "Database rejected batch: \(error.localizedDescription). Check for SKU collisions."
        }
    }
}

fileprivate struct CSVRowCell: View {
    let row: CSVProductRow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.name.isEmpty ? "Unnamed Product" : row.name)
                    .font(.headline)
                    .foregroundColor(row.isValid ? .primary : .red)
                
                Spacer()
                if row.isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Text("SKU: \(row.sku)")
                Spacer()
                Text(row.priceStr)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if !row.isValid {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(row.validationErrors, id: \.self) { err in
                        Text("• " + err)
                            .font(.caption2)
                    }
                }
                .foregroundColor(.red)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
