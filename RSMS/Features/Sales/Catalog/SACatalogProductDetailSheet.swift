//
//  SACatalogProductDetailSheet.swift
//  RSMS
//
//  Sales Associate product detail — image carousel, full specs,
//  inventory level, and description for client guidance.
//

import SwiftUI

struct SACatalogProductDetailSheet: View {

    let product: ProductDTO
    let vm: SACatalogViewModel

    @Environment(SACartViewModel.self) private var cart
    @Environment(\.dismiss) private var dismiss
    @State private var currentImageIndex = 0
    @State private var addedToCart = false

    // Derived
    private var resolvedURLs: [URL] { product.resolvedImageURLs }
    private var stockQty: Int { vm.stockQty(for: product.id) }
    private var stockInfo: (label: String, color: Color) { vm.stockInfo(for: product.id) }
    private var categoryName: String? { vm.categoryName(for: product.categoryId) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        imageCarousel
                        infoSection
                    }
                    .padding(.bottom, AppSpacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(product.sku)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Image Carousel

    private var imageCarousel: some View {
        ZStack(alignment: .bottom) {
            if resolvedURLs.isEmpty {
                ZStack {
                    AppColors.backgroundTertiary
                    Image(systemName: "bag.fill")
                        .font(.system(size: 60, weight: .ultraLight))
                        .foregroundColor(AppColors.neutral600)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            } else {
                TabView(selection: $currentImageIndex) {
                    ForEach(resolvedURLs.indices, id: \.self) { idx in
                        AsyncImage(url: resolvedURLs[idx]) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFill()
                                    .clipped()
                            default:
                                ZStack {
                                    AppColors.backgroundTertiary
                                    ProgressView().tint(AppColors.accent)
                                }
                            }
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 300)

                // Page dots
                if resolvedURLs.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(resolvedURLs.indices, id: \.self) { idx in
                            Circle()
                                .fill(idx == currentImageIndex ? AppColors.accent : Color.white.opacity(0.6))
                                .frame(width: idx == currentImageIndex ? 6 : 4,
                                       height: idx == currentImageIndex ? 6 : 4)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {

            // Name, brand, category
            VStack(alignment: .leading, spacing: 4) {
                if let cat = categoryName {
                    Text(cat.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(AppColors.accent)
                }
                Text(product.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimaryDark)
                if let brand = product.brand {
                    Text(brand)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.lg)

            // Price + Stock badge side by side
            HStack(alignment: .center) {
                Text(product.formattedPrice)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(stockInfo.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(stockInfo.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(stockInfo.color.opacity(0.12))
                        .clipShape(Capsule())
                    if stockQty > 0 {
                        Text("\(stockQty) unit\(stockQty == 1 ? "" : "s") available")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            GoldDivider(opacity: 0.2)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            // Specs grid
            specsGrid
                .padding(.horizontal, AppSpacing.screenHorizontal)

            // Description
            if let desc = product.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("DESCRIPTION")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                    Text(desc)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }

            // Inventory detail card
            stockCard
                .padding(.horizontal, AppSpacing.screenHorizontal)

            // Add to Sale button
            addToSaleButton
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxxl)
        }
    }

    // MARK: - Add to Sale Button

    private var addToSaleButton: some View {
        Button {
            guard stockQty > 0 else { return }
            cart.addItem(product)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                addedToCart = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { addedToCart = false }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: addedToCart ? "checkmark" : "cart.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                Text(addedToCart ? "Added to Cart" : (stockQty == 0 ? "Out of Stock" : "Add to Sale"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                addedToCart ? AppColors.success :
                (stockQty == 0 ? AppColors.neutral500 : AppColors.accent)
            )
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: addedToCart)
        }
        .disabled(stockQty == 0)
    }

    // MARK: - Specs Grid

    private var specsGrid: some View {
        VStack(spacing: 0) {
            specRow("SKU", value: product.sku)
            Divider().padding(.leading, 120)
            specRow("Status", value: product.isActive ? "Active" : "Inactive",
                    valueColor: product.isActive ? AppColors.success : AppColors.error)
            if let cost = product.costPrice {
                Divider().padding(.leading, 120)
                specRow("Cost Price", value: formattedCurrency(cost))
                specRow("Margin", value: marginString(price: product.price, cost: cost),
                        valueColor: AppColors.success)
            }
        }
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }

    private func specRow(_ label: String, value: String, valueColor: Color = AppColors.textPrimaryDark) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(AppTypography.label)
                .foregroundColor(valueColor)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 11)
    }

    // MARK: - Stock Card

    private var stockCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("INVENTORY STATUS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)

            HStack(spacing: AppSpacing.lg) {
                stockStat(value: "\(stockQty)", label: "Total Units", color: stockInfo.color)

                Divider().frame(height: 40)

                stockStat(
                    value: stockQty > 5 ? "Healthy" : stockQty > 0 ? "Low" : "None",
                    label: "Stock Level",
                    color: stockInfo.color
                )

                Divider().frame(height: 40)

                stockStat(
                    value: product.isActive ? "Live" : "Off",
                    label: "Listing",
                    color: product.isActive ? AppColors.success : AppColors.error
                )
            }
            .padding(AppSpacing.md)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        }
    }

    private func stockStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func formattedCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func marginString(price: Double, cost: Double) -> String {
        guard cost > 0 else { return "N/A" }
        let pct = ((price - cost) / cost) * 100
        return String(format: "+%.1f%%", pct)
    }
}
