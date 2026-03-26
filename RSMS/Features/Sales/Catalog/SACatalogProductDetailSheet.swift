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
    @State private var currentImageIndex = 0
    @State private var addedToCart = false
    @State private var showFullscreen = false
    @State private var selectedColorIndex = 0
    @State private var selectedSizeIndex: Int? = nil

    // Derived
    private var resolvedURLs: [URL] { product.resolvedImageURLs }
    private var stockQty: Int { vm.stockQty(for: product.id) }
    private var stockInfo: (label: String, color: Color) { vm.stockInfo(for: product.id) }
    private var categoryName: String? { vm.categoryName(for: product.categoryId) }

    // MARK: - Variant data (category-based defaults, matching customer-facing logic)

    private var colorVariants: [String] {
        let cat = (categoryName ?? "").lowercased()
        if cat.contains("jewel") || cat.contains("ring") || cat.contains("necklace") || cat.contains("bracelet") {
            return ["Yellow Gold", "White Gold", "Rose Gold", "Platinum"]
        }
        if cat.contains("watch") { return ["Steel", "Gold", "Black PVD", "Two-Tone"] }
        if cat.contains("shoe") || cat.contains("footwear") { return ["Black", "Tan", "White", "Nude"] }
        if cat.contains("cloth") || cat.contains("apparel") || cat.contains("wear") {
            return ["Black", "White", "Navy", "Camel"]
        }
        return ["Noir", "Fauve", "Bordeaux", "Marine", "Étoupe"]
    }

    private var sizeVariants: [String] {
        let cat = (categoryName ?? "").lowercased()
        if cat.contains("shoe") || cat.contains("footwear") { return ["36", "37", "38", "39", "40", "41"] }
        if cat.contains("ring") { return ["5", "6", "7", "8", "9", "10"] }
        if cat.contains("cloth") || cat.contains("apparel") || cat.contains("wear") {
            return ["XS", "S", "M", "L", "XL"]
        }
        return []
    }

    private var showSizes: Bool { !sizeVariants.isEmpty }

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
                .frame(height: 340)
            } else {
                TabView(selection: $currentImageIndex) {
                    ForEach(resolvedURLs.indices, id: \.self) { idx in
                        AsyncImage(url: resolvedURLs[idx]) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFit()
                            case .failure:
                                ZStack {
                                    AppColors.backgroundTertiary
                                    Image(systemName: "photo")
                                        .font(.system(size: 40, weight: .ultraLight))
                                        .foregroundColor(AppColors.neutral500)
                                }
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
                .frame(height: 340)
                .onTapGesture { showFullscreen = true }
                .overlay(alignment: .topTrailing) {
                    // Fullscreen expand hint
                    Button { showFullscreen = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(12)
                }

                // Page dots + image count
                VStack(spacing: 4) {
                    if resolvedURLs.count > 1 {
                        HStack(spacing: 5) {
                            ForEach(resolvedURLs.indices, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentImageIndex ? AppColors.accent : Color.white.opacity(0.7))
                                    .frame(width: idx == currentImageIndex ? 7 : 5,
                                           height: idx == currentImageIndex ? 7 : 5)
                                    .animation(.easeInOut(duration: 0.15), value: currentImageIndex)
                            }
                        }
                        Text("\(currentImageIndex + 1) / \(resolvedURLs.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showFullscreen) {
            FullscreenImageViewer(urls: resolvedURLs, startIndex: currentImageIndex)
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

            // Variant selector
            variantsSection
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

    // MARK: - Variants Section

    private var variantsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            // Color picker
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: 4) {
                    Text("COLOUR")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                    Text("— \(colorVariants[selectedColorIndex])")
                        .font(AppTypography.overline)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(colorVariants.indices, id: \.self) { idx in
                            colorChip(idx)
                        }
                    }
                }
            }

            // Size picker (only for relevant categories)
            if showSizes {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: 4) {
                        Text("SIZE")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                        if let s = selectedSizeIndex {
                            Text("— \(sizeVariants[s])")
                                .font(AppTypography.overline)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(sizeVariants.indices, id: \.self) { idx in
                                sizeChip(idx)
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedColorIndex)
        .animation(.easeInOut(duration: 0.15), value: selectedSizeIndex)
    }

    private func colorChip(_ idx: Int) -> some View {
        let selected = selectedColorIndex == idx
        return Button {
            withAnimation(.spring(response: 0.25)) { selectedColorIndex = idx }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(selected ? AppColors.accent.opacity(0.12) : AppColors.backgroundSecondary)
                        .overlay(
                            Circle()
                                .stroke(selected ? AppColors.accent : AppColors.border.opacity(0.5),
                                        lineWidth: selected ? 1.5 : 1)
                        )
                        .frame(width: 48, height: 48)
                    Text(String(colorVariants[idx].prefix(2)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selected ? AppColors.accent : AppColors.neutral700)
                }
                Text(colorVariants[idx])
                    .font(AppTypography.pico)
                    .foregroundColor(selected ? AppColors.accent : AppColors.textSecondaryDark)
                    .lineLimit(1)
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
    }

    private func sizeChip(_ idx: Int) -> some View {
        let selected = selectedSizeIndex == idx
        return Button {
            withAnimation(.spring(response: 0.25)) {
                selectedSizeIndex = selected ? nil : idx
            }
        } label: {
            Text(sizeVariants[idx])
                .font(AppTypography.label)
                .foregroundColor(selected ? AppColors.textPrimaryLight : AppColors.textPrimaryDark)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(selected ? AppColors.accent : AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? AppColors.accent : AppColors.border.opacity(0.5),
                                lineWidth: selected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add to Sale Button

    private var addToSaleButton: some View {
        Button {
            cart.addItem(product,
                         color: colorVariants[selectedColorIndex],
                         size: selectedSizeIndex.map { sizeVariants[$0] },
                         isInStock: stockQty > 0)
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
                Text(addedToCart ? "Added to Cart" : (stockQty == 0 ? "Add to Sale (Order)" : "Add to Sale"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                addedToCart ? AppColors.success :
                AppColors.accent
            )
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: addedToCart)
        }
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
        f.currencyCode = "INR"
        return f.string(from: NSNumber(value: value)) ?? "₹\(value)"
    }

    private func marginString(price: Double, cost: Double) -> String {
        guard cost > 0 else { return "N/A" }
        let pct = ((price - cost) / cost) * 100
        return String(format: "+%.1f%%", pct)
    }
}
