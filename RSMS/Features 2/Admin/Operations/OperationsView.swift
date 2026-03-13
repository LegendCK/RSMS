//
//  OperationsView.swift
//  infosys2
//
//  Enterprise operations hub — global inventory, distribution centers, stock transfers.
//

import SwiftUI
import SwiftData

struct OperationsView: View {
    @Query(sort: \Product.stockCount, order: .forward) private var allProducts: [Product]
    @State private var selectedSection = 0

    private var lowStockProducts: [Product] { allProducts.filter { $0.stockCount <= 3 && $0.stockCount > 0 } }
    private var outOfStockProducts: [Product] { allProducts.filter { $0.stockCount == 0 } }
    private var healthyProducts: [Product] { allProducts.filter { $0.stockCount > 3 } }
    private var totalUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segment
                    Picker("", selection: $selectedSection) {
                        Text("Inventory").tag(0)
                        Text("Distribution").tag(1)
                        Text("Transfers").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: inventorySection
                    case 1: distributionSection
                    case 2: transfersSection
                    default: inventorySection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Operations")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {}) { Label("New Transfer", systemImage: "arrow.left.arrow.right") }
                        Button(action: {}) { Label("Reorder Stock", systemImage: "cart.badge.plus") }
                        Button(action: {}) { Label("Export Inventory", systemImage: "square.and.arrow.up") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(AppTypography.iconMedium)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }

    // MARK: - Global Inventory

    private var inventorySection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                // Summary strip
                HStack(spacing: AppSpacing.sm) {
                    inventoryStat(value: "\(totalUnits)", label: "Total Units", color: AppColors.accent)
                    inventoryStat(value: "\(allProducts.count)", label: "SKUs", color: AppColors.purple)
                    inventoryStat(value: "\(lowStockProducts.count)", label: "Low", color: AppColors.warning)
                    inventoryStat(value: "\(outOfStockProducts.count)", label: "Out", color: AppColors.error)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                // Critical items
                if !outOfStockProducts.isEmpty || !lowStockProducts.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sectionLabel("REQUIRES ATTENTION")

                        ForEach(outOfStockProducts + lowStockProducts) { product in
                            stockAlertRow(product)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // All inventory
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionLabel("ALL INVENTORY")

                    ForEach(allProducts) { product in
                        inventoryRow(product)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func inventoryStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.heading2)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func stockAlertRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.categoryName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()

            Text(product.stockCount == 0 ? "OUT" : "\(product.stockCount) left")
                .font(AppTypography.statSmall)
                .foregroundColor(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((product.stockCount == 0 ? AppColors.error : AppColors.warning).opacity(0.12))
                .cornerRadius(4)

            Button(action: {}) {
                Text("Reorder")
                    .font(AppTypography.actionLink)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func inventoryRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 40, height: 40)
                Image(systemName: product.imageName)
                    .font(AppTypography.inventoryIcon)
                    .foregroundColor(AppColors.neutral600)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(product.name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.brand + " • " + product.categoryName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()

            stockBadge(product.stockCount)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func stockBadge(_ count: Int) -> some View {
        let color = count > 5 ? AppColors.success : count > 0 ? AppColors.warning : AppColors.error
        return Text("\(count)")
            .font(AppTypography.editLink)
            .foregroundColor(color)
            .frame(width: 32)
    }

    // MARK: - Distribution Centers

    private var distributionSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    inventoryStat(value: "2", label: "Centers", color: AppColors.info)
                    inventoryStat(value: "43K", label: "Capacity", color: AppColors.accent)
                    inventoryStat(value: "68%", label: "Utilized", color: AppColors.success)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                dcCard(name: "East Coast Hub", location: "Newark, NJ", capacity: "25,000", used: "18,200", percent: 0.73, status: "Operational")
                dcCard(name: "European Hub", location: "Milan, Italy", capacity: "18,000", used: "11,500", percent: 0.64, status: "Operational")
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func dcCard(name: String, location: String, capacity: String, used: String, percent: Double, status: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(location)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(status.uppercased())
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.success.opacity(0.12))
                    .cornerRadius(4)
            }

            // Utilization bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.backgroundTertiary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(percent > 0.8 ? AppColors.warning : AppColors.accent)
                            .frame(width: geo.size.width * percent)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(used) / \(capacity) units")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                    Text("\(Int(percent * 100))%")
                        .font(AppTypography.statSmall)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Transfers

    private var transfersSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                // Pending header
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionLabel("PENDING TRANSFERS")

                    transferRow(sku: "Classic Flap Bag", qty: 2, from: "NYC", to: "Paris", status: "In Transit", color: AppColors.info)
                    transferRow(sku: "Pearl Earrings", qty: 3, from: "Milan DC", to: "Tokyo", status: "Packing", color: AppColors.warning)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionLabel("COMPLETED")

                    transferRow(sku: "Diamond Pendant", qty: 1, from: "Newark DC", to: "Rodeo Dr.", status: "Delivered", color: AppColors.success)
                    transferRow(sku: "Silk Scarf", qty: 5, from: "Milan DC", to: "Fifth Ave", status: "Delivered", color: AppColors.success)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func transferRow(sku: String, qty: Int, from: String, to: String, status: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sku)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(from)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Image(systemName: "arrow.right")
                        .font(AppTypography.arrowInline)
                        .foregroundColor(AppColors.neutral500)
                    Text(to)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
            Spacer()

            Text("×\(qty)")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)

            Text(status.uppercased())
                .font(AppTypography.nano)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .cornerRadius(4)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
    }
}

#Preview {
    OperationsView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
