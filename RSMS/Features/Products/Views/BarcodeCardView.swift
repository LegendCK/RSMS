//
//  BarcodeCardView.swift
//  RSMS
//
//  Presents a premium modal displaying the generated barcode with export actions.
//

import SwiftUI

struct BarcodeCardView: View {
    let item: ProductItemDTO
    let productName: String
    let brand: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var barcodeImage: UIImage?
    @State private var isExporting = false
    @State private var generatedPDF: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()
                
                VStack(spacing: AppSpacing.xl) {
                    
                    // The Physical Sticker Card
                    VStack(spacing: 0) {
                        Text(brand.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .padding(.top, AppSpacing.lg)
                        
                        Text(productName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.textPrimaryDark)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, 4)
                        
                        if let image = barcodeImage {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none) // Prevent Apple from blurring our hard-math scales
                                .scaledToFit()
                                .frame(height: 80)
                                .padding(.horizontal, AppSpacing.xl)
                                .padding(.top, AppSpacing.lg)
                                .padding(.bottom, AppSpacing.sm)
                        } else {
                            Rectangle()
                                .fill(AppColors.neutral300)
                                .frame(height: 80)
                                .overlay(ProgressView())
                                .padding(.top, AppSpacing.lg)
                                .padding(.bottom, AppSpacing.sm)
                                .padding(.horizontal, AppSpacing.xl)
                        }
                        
                        Text(item.barcode)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.textPrimaryDark)
                            .padding(.bottom, AppSpacing.lg)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.06), radius: 24, y: 12)
                    )
                    .padding(.horizontal, AppSpacing.xl)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    }
                    
                    // Action Button
                    Button(action: exportSinglePDF) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Export PDF Label")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.md)
                }
            }
            .navigationTitle("Barcode Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(AppTypography.bodyMedium)
                }
            }
            .task {
                generateHighResBarcode()
            }
            .sheet(isPresented: $isExporting, onDismiss: { generatedPDF = nil }) {
                if let url = generatedPDF {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func generateHighResBarcode() {
        // Offload image render queue so UI remains hyper-smooth opening the modal
        Task.detached(priority: .userInitiated) {
            if let img = BarcodeGeneratorService.shared.generateBarcode(from: item.barcode, scale: 6) {
                await MainActor.run { barcodeImage = img }
            }
        }
    }
    
    private func exportSinglePDF() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let url = BarcodePDFService.shared.generatePDF(
            items: [item],
            productName: productName,
            brand: brand
        )
        
        if let output = url {
            self.generatedPDF = output
            self.isExporting = true
        }
    }
}
