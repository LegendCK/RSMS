//
//  ManagerInventoryView.swift
//  infosys2
//
//  Boutique Manager inventory oversight — stock levels, low stock alerts, transfer requests, flagged items.
//  Store-scoped: only this boutique's inventory.
//

import SwiftUI
import SwiftData

struct ManagerInventoryView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Stock").tag(0)
                        Text("Alerts").tag(1)
                        Text("Transfers").tag(2)
                        Text("Flagged").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: InvStockSubview()
                    case 1: InvAlertsSubview()
                    case 2: InvTransfersSubview()
                    case 3: InvFlaggedSubview()
                    default: InvStockSubview()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Inventory").font(AppTypography.navTitle).foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {}) { Label("Request Transfer", systemImage: "arrow.left.arrow.right") }
                        Button(action: {}) { Label("Start Count", systemImage: "checklist") }
                        Button(action: {}) { Label("Flag Item", systemImage: "exclamationmark.bubble") }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(AppTypography.iconMedium).foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Stock Levels

struct InvStockSubview: View {
    @Query(sort: \Product.stockCount, order: .forward) private var allProducts: [Product]
    @State private var searchText = ""

    private var filtered: [Product] {
        searchText.isEmpty ? allProducts : allProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var totalUnits: Int { allProducts.reduce(0) { $0 + $1.stockCount } }
    private var lowCount: Int { allProducts.filter { $0.stockCount > 0 && $0.stockCount <= 3 }.count }
    private var outCount: Int { allProducts.filter { $0.stockCount == 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Stats
            HStack(spacing: AppSpacing.sm) {
                invStat(value: "\(totalUnits)", label: "Units", color: AppColors.accent)
                invStat(value: "\(allProducts.count)", label: "SKUs", color: AppColors.purple)
                invStat(value: "\(lowCount)", label: "Low", color: AppColors.warning)
                invStat(value: "\(outCount)", label: "Out", color: AppColors.error)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal).padding(.bottom, AppSpacing.sm)

            // Search
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.neutral500)
                TextField("Search inventory...", text: $searchText).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm).background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal).padding(.bottom, AppSpacing.xs)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(filtered) { product in
                        invRow(product)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func invRow(_ product: Product) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(AppColors.backgroundTertiary).frame(width: 40, height: 40)
                Image(systemName: product.imageName).font(AppTypography.inventoryIcon).foregroundColor(AppColors.neutral600)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(product.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
                Text(product.categoryName).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            stockBadge(product.stockCount)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func stockBadge(_ count: Int) -> some View {
        let color = count > 5 ? AppColors.success : count > 0 ? AppColors.warning : AppColors.error
        let label = count == 0 ? "OUT" : "\(count)"
        return Text(label).font(AppTypography.editLink).foregroundColor(color)
            .frame(width: 36).padding(.vertical, 3).background(color.opacity(0.12)).cornerRadius(4)
    }

    private func invStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(AppTypography.heading3).foregroundColor(color)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
    }
}

// MARK: - Alerts

struct InvAlertsSubview: View {
    @Query(sort: \Product.stockCount) private var allProducts: [Product]

    private var critical: [Product] { allProducts.filter { $0.stockCount <= 3 } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if critical.isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer().frame(height: 60)
                        Image(systemName: "checkmark.circle").font(AppTypography.emptyStateIcon).foregroundColor(AppColors.success)
                        Text("All stock levels healthy").font(AppTypography.heading3).foregroundColor(AppColors.textPrimaryDark)
                    }
                } else {
                    Text("ITEMS REQUIRING ACTION").font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, AppSpacing.screenHorizontal)

                    ForEach(critical) { product in
                        HStack(spacing: AppSpacing.sm) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                                .frame(width: 3, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                                Text(product.categoryName).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                            }
                            Spacer()
                            Text(product.stockCount == 0 ? "OUT" : "\(product.stockCount) left")
                                .font(AppTypography.statSmall)
                                .foregroundColor(product.stockCount == 0 ? AppColors.error : AppColors.warning)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background((product.stockCount == 0 ? AppColors.error : AppColors.warning).opacity(0.12)).cornerRadius(4)
                            Button(action: {}) {
                                Text("Request").font(AppTypography.actionLink).foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
                        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                }
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }
}

// MARK: - Transfers

struct InvTransfersSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                sLabel("OUTBOUND REQUESTS")
                transferCard(sku: "Heritage Bag", qty: 2, from: "Fifth Ave", to: "Newark DC", status: "Requested", color: AppColors.warning)

                sLabel("INBOUND")
                transferCard(sku: "Sport Diver", qty: 2, from: "Newark DC", to: "Fifth Ave", status: "In Transit", color: AppColors.info)
                transferCard(sku: "Silk Scarf", qty: 5, from: "Milan DC", to: "Fifth Ave", status: "Delivered", color: AppColors.success)
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func transferCard(sku: String, qty: Int, from: String, to: String, status: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sku).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                HStack(spacing: 4) {
                    Text(from).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                    Image(systemName: "arrow.right").font(AppTypography.arrowInline).foregroundColor(AppColors.neutral500)
                    Text(to).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
            }
            Spacer()
            Text("×\(qty)").font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
            Text(status.uppercased()).font(AppTypography.nano).foregroundColor(color)
                .padding(.horizontal, 8).padding(.vertical, 3).background(color.opacity(0.12)).cornerRadius(4)
        }
        .padding(AppSpacing.sm).background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Flagged Items

struct InvFlaggedSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                Text("FLAGGED FOR REVIEW").font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, AppSpacing.screenHorizontal)

                flagRow(item: "Classic Flap Bag #ML-0042", reason: "Minor scratch on hardware", flaggedBy: "Alexander Chase", time: "Today", severity: "Low")
                flagRow(item: "Diamond Bezel Watch #ML-0118", reason: "Display case damaged", flaggedBy: "Daniel Park", time: "Yesterday", severity: "Medium")
                flagRow(item: "Gold Bracelet #ML-0205", reason: "Clasp mechanism stiff", flaggedBy: "Marcus Webb", time: "2d ago", severity: "Low")
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func flagRow(item: String, reason: String, flaggedBy: String, time: String, severity: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(item).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark).lineLimit(1)
                Spacer()
                let sc = severity == "Low" ? AppColors.warning : AppColors.error
                Text(severity.uppercased()).font(AppTypography.nano).foregroundColor(sc)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(sc.opacity(0.12)).cornerRadius(4)
            }
            Text(reason).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
            HStack {
                Text(flaggedBy).font(AppTypography.micro).foregroundColor(AppColors.purple)
                Text("•").foregroundColor(AppColors.neutral600)
                Text(time).font(AppTypography.caption).foregroundColor(AppColors.neutral500)
                Spacer()
                Button(action: {}) {
                    Text("Review").font(AppTypography.reviewButton).foregroundColor(AppColors.accent)
                        .padding(.horizontal, 12).padding(.vertical, 5).background(AppColors.accent.opacity(0.12)).cornerRadius(6)
                }
            }
        }
        .padding(AppSpacing.cardPadding).background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    ManagerInventoryView()
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
