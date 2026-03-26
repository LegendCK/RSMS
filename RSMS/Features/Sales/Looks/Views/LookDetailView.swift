//
//  LookDetailView.swift
//  RSMS
//

import SwiftUI
import SwiftData

struct LookDetailView: View {
    let look: Look
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allProducts: [Product]
    
    private var lookProducts: [Product] {
        allProducts.filter { look.productIds.contains($0.id) }
    }
    
    private var totalPrice: Double {
        lookProducts.reduce(0) { $0 + $1.price }
    }
    
    private var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: totalPrice)) ?? "INR \(totalPrice)"
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image placeholder
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
                    
                    // Look Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(look.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Curated by \(look.creatorName)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    
                    // Products List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pieces in this Look (\(lookProducts.count))")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal)
                        
                        ForEach(lookProducts) { product in
                            HStack(spacing: 16) {
                                Image(systemName: product.imageName.isEmpty ? "bag.fill" : product.imageName)
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, height: 80)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.brand)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AppColors.textSecondaryDark)
                                        .textCase(.uppercase)
                                    
                                    Text(product.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    
                                    Spacer()
                                    
                                    Text(product.formattedPrice)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColors.accent)
                                }
                                .padding(.vertical, 4)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 100) // Space for bottom bar
                }
            }
            
            // Sticky Bottom Bar
            VStack(spacing: 0) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Value")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formattedTotal)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        // Action: Add all to cart
                    } label: {
                        Text("Add All to Cart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
