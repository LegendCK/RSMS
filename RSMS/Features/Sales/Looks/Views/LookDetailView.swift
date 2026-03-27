//
//  LookDetailView.swift
//  RSMS
//

import SwiftUI
import SwiftData

struct LookDetailView: View {
    @Environment(SACartViewModel.self) private var cart
    let look: SalesLookDTO
    @Query private var allProducts: [Product]
    @State private var flowMessage: String?
    
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

    private var heroImageSource: String {
        if let thumb = look.thumbnailSource, !thumb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return thumb
        }
        return lookProducts.first?.imageList.first ?? lookProducts.first?.imageName ?? ""
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ProductArtworkView(
                        imageSource: heroImageSource,
                        fallbackSymbol: "photo.on.rectangle.angled",
                        cornerRadius: 18
                    )
                    .frame(height: 340)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(look.name)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Curated by \(look.creatorName)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pieces in this Look (\(lookProducts.count))")
                            .font(.system(size: 24, weight: .bold))
                            .padding(.horizontal, 20)

                        LazyVStack(spacing: 12) {
                            ForEach(lookProducts) { product in
                                NavigationLink {
                                    ProductDetailView(product: product)
                                } label: {
                                    HStack(spacing: 14) {
                                        ProductArtworkView(
                                            imageSource: product.imageList.first ?? product.imageName,
                                            fallbackSymbol: "bag.fill",
                                            cornerRadius: 12
                                        )
                                        .frame(width: 74, height: 74)

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(product.brand)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(AppColors.textSecondaryDark)
                                                .textCase(.uppercase)

                                            Text(product.name)
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(2)

                                            Text(product.formattedPrice)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppColors.accent)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppColors.neutral500)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 86)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppColors.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Value")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formattedTotal)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    Button {
                        addLookToCart(startCheckout: false)
                    } label: {
                        Text("Add All")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppColors.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Button {
                        addLookToCart(startCheckout: true)
                    } label: {
                        Text("Checkout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: Binding(
            get: { cart.showCart },
            set: { cart.showCart = $0 }
        )) {
            SASaleCartView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Curated Look", isPresented: Binding(
            get: { flowMessage != nil },
            set: { if !$0 { flowMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(flowMessage ?? "")
        }
    }

    private func addLookToCart(startCheckout: Bool) {
        guard !lookProducts.isEmpty else {
            flowMessage = "This look has no available products to add."
            return
        }

        for product in lookProducts {
            cart.addItem(
                productDTO(from: product),
                isInStock: product.stockCount > 0
            )
        }

        cart.showCart = true
        if startCheckout {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                cart.showCheckout = true
            }
        }
    }

    private func productDTO(from product: Product) -> ProductDTO {
        ProductDTO(
            id: product.id,
            sku: product.sku,
            name: product.name,
            brand: product.brand,
            categoryId: nil,
            collectionId: nil,
            taxCategoryId: nil,
            description: product.productDescription.isEmpty ? nil : product.productDescription,
            price: product.price,
            costPrice: nil,
            imageUrls: product.imageList.isEmpty ? nil : product.imageList,
            isActive: true,
            createdBy: nil,
            createdAt: product.createdAt,
            updatedAt: product.createdAt
        )
    }
}
