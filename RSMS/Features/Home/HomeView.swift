////  HomeView.swift
//  RSMS
//
//  Luxury home — maroon gradient header, carousel banner, category filter pills, featured + new arrivals.
//

import SwiftUI
import SwiftData

// MARK: - Gender / Lifestyle Filter

enum GenderFilter: String, CaseIterable {
    case all       = "All"
    case men       = "Men"
    case women     = "Women"
    case kids      = "Kids"
    case lifestyle = "Lifestyle"

    /// Keywords matched against product `categoryName` + `name` using word-boundary regex.
    var keywords: [String] {
        switch self {
        case .all:       return []
        case .men:       return ["men", "male", "gentleman", "groom", "suit", "aviator", "blazer", "cufflink"]
        case .women:     return ["women", "female", "lady", "ladies", "bridal", "gown", "dress", "necklace",
                                 "choker", "bracelet", "engagement", "handbag", "wedding"]
        case .kids:      return ["kid", "kids", "child", "children", "baby", "infant", "junior"]
        case .lifestyle: return ["lifestyle", "home", "decor", "fragrance", "candle", "wellness", "beauty", "gift"]
        }
    }

    /// Uses word-boundary matching so "men" does not match inside "women".
    func matches(_ product: Product) -> Bool {
        guard self != .all else { return true }
        let text = "\(product.categoryName) \(product.name)".lowercased()
        return keywords.contains { keyword in
            text.range(of: "\\b\(keyword)\\b", options: .regularExpression) != nil
        }
    }
}

private struct BannerData {
    let label: String
    let title: String
    let subtitle: String
    let buttonText: String
}

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Product> { $0.isFeatured == true })
    private var featuredProducts: [Product]
    @Query private var allProducts: [Product]

    @State private var selectedGender: GenderFilter = .all
    @State private var currentBanner = 0
    @State private var showAllFeatured = false
    @State private var showAllArrivals = false
    @State private var showNotifications = false
    @State private var unreadCount = 0
    @State private var selectedProduct: Product? = nil
    @State private var showVIPOnlyAlert = false
    @State private var resolvedClientSegment: String? = nil

    private let banners: [BannerData] = [
        BannerData(label: "NEW SEASON", title: "Spring\n2026", subtitle: "Curated luxury for the modern connoisseur.", buttonText: "Shop Now"),
        BannerData(label: "LIMITED EDITION", title: "Exclusive\nDrops", subtitle: "One-of-a-kind pieces from elite artisans.", buttonText: "Explore")
    ]

    private var filteredProducts: [Product] {
        var products = allProducts
        if selectedGender != .all {
            products = products.filter { selectedGender.matches($0) }
        }
        return products
    }

    private var genderFilteredFeatured: [Product] {
        if selectedGender == .all { return featuredProducts }
        return featuredProducts.filter { selectedGender.matches($0) }
    }

    private var isVIPMember: Bool {
        let segment = (
            appState.currentClientProfile?.segment ??
            resolvedClientSegment ??
            ""
        ).lowercased()
        return segment == "vip" || segment == "ultra_vip"
    }

    var body: some View {
        @Bindable var state = appState
        
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Maroon top glow
            LinearGradient(
                colors: [AppColors.accent.opacity(0.13), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.28)
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    bannerCarousel
                    genderFilterSection
                    featuredSection
                    RecommendedForYouSection()
                    newArrivalsSection
                    Spacer().frame(height: 48)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Centre brand wordmark — no leading item so it never truncates to "M …"
            ToolbarItem(placement: .principal) {
                Text("MAISON LUXE")
                    .font(.system(size: 13, weight: .black))
                    .tracking(5)
                    .foregroundColor(.primary)
            }
            // Trailing: bell and cart at identical visual height
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(alignment: .center, spacing: 20) {
                    Button { showNotifications = true } label: {
                        Image(systemName: unreadCount > 0 ? "bell.badge" : "bell")
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(unreadCount > 0 ? "Notifications, \(unreadCount) unread" : "Notifications")
                    .accessibilityHint("Double tap to view notifications")
                    CartShortcutButton()
                }
            }
        }
        .navigationDestination(isPresented: $showAllFeatured) { ProductListView(categoryFilter: nil, showsTabBar: false) }
        .navigationDestination(isPresented: $showAllArrivals) { ProductListView(categoryFilter: nil, showsTabBar: false) }
        .navigationDestination(isPresented: $state.showCart) {
            CartView()
        }
        .sheet(isPresented: $showNotifications, onDismiss: { Task { await refreshUnreadCount() } }) {
            NavigationStack {
                NotificationCenterView(showsCloseButton: true)
                    .environment(appState)
            }
        }
        .fullScreenCover(item: $selectedProduct) { product in
            ProductDetailView(product: product, isSheet: true)
                .environment(appState)
        }
        .alert("VIP Access Only", isPresented: $showVIPOnlyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This collection is available only for VIP members.")
        }
        .task {
            await resolveClientSegmentIfNeeded()
            await NotificationService.shared.requestPermission()
            await refreshUnreadCount()
            if let clientId = appState.currentUserProfile?.id {
                NotificationService.shared.subscribeToRealtime(clientId: clientId) { _ in
                    Task { await refreshUnreadCount() }
                }
            }
        }
    }

    private func refreshUnreadCount() async {
        guard let clientId = appState.currentUserProfile?.id else { return }
        let dtos = (try? await NotificationService.shared.fetchNotifications(clientId: clientId)) ?? []
        unreadCount = dtos.filter { !$0.isRead }.count
    }

    private func resolveClientSegmentIfNeeded() async {
        if let segment = appState.currentClientProfile?.segment, !segment.isEmpty {
            resolvedClientSegment = segment
            return
        }
        if appState.currentUserRole != .customer { return }
        if let profile = try? await ProfileService.shared.fetchMyClientProfile() {
            resolvedClientSegment = profile.segment
            appState.updateCurrentClientProfile(profile)
        }
    }

    // MARK: - Banner Carousel

    private var bannerCarousel: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentBanner) {
                ForEach(0..<banners.count, id: \.self) { index in
                    bannerCard(banners[index])
                        .tag(index)
                        .padding(.horizontal, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)

            // Dots
            HStack(spacing: 5) {
                ForEach(0..<banners.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentBanner ? AppColors.accent : Color(.systemGray4))
                        .frame(width: index == currentBanner ? 20 : 5, height: 5)
                        .animation(.easeInOut(duration: 0.25), value: currentBanner)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Promotional banners, \(banners.count) banners, showing banner \(currentBanner + 1)")
    }

    private func bannerCard(_ data: BannerData) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))

            // Accent bar
            HStack {
                Spacer()
                Rectangle()
                    .fill(AppColors.accent.opacity(0.7))
                    .frame(width: 3, height: 80)
                    .padding(.trailing, 28)
                    .padding(.bottom, 36)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(data.label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(4)
                    .foregroundColor(AppColors.accent)

                Text(data.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.primary)
                    .lineSpacing(2)

                Text(data.subtitle)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Button(action: { handleBannerTap(data) }) {
                    Text(data.buttonText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("\(data.buttonText) — \(data.title.replacingOccurrences(of: "\n", with: " "))")
                .accessibilityHint(data.subtitle)
                .padding(.top, 2)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func handleBannerTap(_ data: BannerData) {
        let isMembersOnlyBanner = data.label.uppercased() == "PRIVATE ACCESS"
        guard isMembersOnlyBanner else {
            showAllFeatured = true
            return
        }
        if isVIPMember {
            showAllFeatured = true
        } else {
            showVIPOnlyAlert = true
        }
    }

    // MARK: - Featured Section

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "FEATURED", action: { showAllFeatured = true })

            if genderFilteredFeatured.isEmpty {
                emptyBanner(icon: "star", message: "No featured products yet")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(genderFilteredFeatured) { product in
                            featuredCard(product)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedProduct = product
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }
        }
        .padding(.bottom, 28)
    }

    private func featuredCard(_ product: Product) -> some View {
        let isOutOfStock = product.stockCount == 0
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    ProductArtworkView(
                        imageSource: product.imageName,
                        fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock" : "bag",
                        cornerRadius: 0
                    )
                    .frame(width: 150, height: 200)
                    .clipped()
                    .background(Color(.systemGray6))
                    .overlay {
                        if isOutOfStock {
                            Color.white.opacity(0.55)
                        }
                    }

                    if product.isLimitedEdition {
                        Text("LIMITED")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppColors.accent)
                    }
                }
                .frame(width: 150, height: 200)
                .overlay(alignment: .topLeading) {
                    if isOutOfStock {
                        Text("OUT OF STOCK")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(3)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    wishlistButton(for: product)
                        .padding(8)
                }

            }

            VStack(alignment: .leading, spacing: 5) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(isOutOfStock ? .secondary : AppColors.accent)
                Text(product.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isOutOfStock ? .secondary : .primary)
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .topLeading)
                Text(product.formattedPrice)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(width: 150, alignment: .leading)
        }
        .frame(width: 150)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.brand) \(product.name), \(product.formattedPrice)\(isOutOfStock ? ", out of stock" : "")\(product.isLimitedEdition ? ", limited edition" : "")")
        .accessibilityHint("Double tap to view product details")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - New Arrivals

    private var newArrivalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "NEW ARRIVALS", action: { showAllArrivals = true })

            if filteredProducts.isEmpty {
                emptyBanner(icon: "shippingbox", message: "No products available")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 14
                ) {
                    ForEach(filteredProducts.prefix(6)) { product in
                        productCard(product)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProduct = product
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .padding(.bottom, 8)
    }

    private func productCard(_ product: Product) -> some View {
        let isOutOfStock = product.stockCount == 0
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        ProductArtworkView(
                            imageSource: product.imageName,
                            fallbackSymbol: product.categoryName.lowercased().contains("watch") ? "clock" : "bag",
                            cornerRadius: 0
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .background(Color(.systemGray6))
                        .overlay {
                            if isOutOfStock {
                                Color.white.opacity(0.55)
                            }
                        }

                        if product.isLimitedEdition {
                            Text("LIMITED")
                                .font(.system(size: 7, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AppColors.accent)
                        }
                    }
                }
                .aspectRatio(3/4, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    if isOutOfStock {
                        Text("OUT OF STOCK")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(3)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    wishlistButton(for: product)
                        .padding(8)
                }

            }

            VStack(alignment: .leading, spacing: 5) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(isOutOfStock ? .secondary : AppColors.accent)
                Text(product.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isOutOfStock ? .secondary : .primary)
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .topLeading)
                Text(product.formattedPrice)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.brand) \(product.name), \(product.formattedPrice)\(isOutOfStock ? ", out of stock" : "")\(product.isLimitedEdition ? ", limited edition" : "")")
        .accessibilityHint("Double tap to view product details")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Gender Filter Section

    private var genderFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(GenderFilter.allCases, id: \.self) { gender in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedGender = gender
                        }
                    } label: {
                        Text(gender.rawValue.uppercased())
                            .font(.system(size: 11, weight: selectedGender == gender ? .bold : .medium))
                            .tracking(1.5)
                            .foregroundColor(
                                selectedGender == gender
                                    ? AppColors.textPrimaryLight
                                    : AppColors.textPrimaryDark
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedGender == gender
                                    ? AppColors.accent
                                    : AppColors.backgroundSecondary
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    selectedGender == gender
                                        ? AppColors.accent
                                        : AppColors.border.opacity(0.6),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("\(gender.rawValue) filter\(selectedGender == gender ? ", selected" : "")")
                    .accessibilityAddTraits(selectedGender == gender ? [.isButton, .isSelected] : .isButton)
                    .accessibilityHint("Double tap to filter products by \(gender.rawValue)")
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Shared Helpers

    private func sectionHeader(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .black))
                .tracking(1.5)
                .foregroundColor(AppColors.textPrimaryDark)
                .shadow(color: AppColors.border.opacity(0.25), radius: 1, x: 0, y: 1)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: action) {
                HStack(spacing: 3) {
                    Text("View All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
            }
            .accessibilityLabel("View all \(title.lowercased()) products")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func emptyBanner(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent.opacity(0.5))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }

    private func wishlistButton(for product: Product) -> some View {
        Button {
            toggleWishlist(product)
        } label: {
            Image(systemName: product.isWishlisted ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(product.isWishlisted ? AppColors.accent : AppColors.textPrimaryLight)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(AppColors.border.opacity(0.35), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(product.isWishlisted ? "Remove \(product.name) from wishlist" : "Add \(product.name) to wishlist")
        .accessibilityHint("Double tap to \(product.isWishlisted ? "remove from" : "add to") your wishlist")
    }

    private func toggleWishlist(_ product: Product) {
        let targetState = !product.isWishlisted
        product.isWishlisted = targetState
        try? modelContext.save()

        guard appState.isAuthenticated, !appState.isGuest else { return }

        Task { @MainActor in
            do {
                try await WishlistService.shared.setWishlisted(productId: product.id, isWishlisted: targetState)
            } catch {
                if case WishlistService.SyncCapabilityError.missingWishlistTable = error {
                    print("[HomeView] Wishlist table not available yet; kept local wishlist state for \(product.id)")
                    return
                }
                if case WishlistService.SyncCapabilityError.wishlistForeignKeyMisconfigured = error {
                    print("[HomeView] Wishlist FK misconfigured; kept local wishlist state for \(product.id)")
                    return
                }
                product.isWishlisted = !targetState
                try? modelContext.save()
                print("[HomeView] Wishlist sync failed for \(product.id): \(error)")
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
