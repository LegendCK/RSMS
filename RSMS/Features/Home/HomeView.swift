////  HomeView.swift
//  RSMS
//
//  Luxury home — maroon gradient header, carousel banner, category filter pills, featured + new arrivals.
//

import SwiftUI
import SwiftData

private struct BannerData {
    let label: String
    let title: String
    let subtitle: String
    let buttonText: String
}

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Query(filter: #Predicate<Product> { $0.isFeatured == true })
    private var featuredProducts: [Product]
    @Query(sort: \Category.displayOrder)
    private var categories: [Category]
    @Query private var allProducts: [Product]

    @State private var selectedCategoryName: String? = nil
    @State private var currentBanner = 0
    @State private var showAllCategories = false
    @State private var showAllFeatured = false
    @State private var showAllArrivals = false
    @State private var showNotifications = false
    @State private var unreadCount = 0

    private let banners: [BannerData] = [
        BannerData(label: "NEW SEASON", title: "Spring\n2026", subtitle: "Curated luxury for the modern connoisseur.", buttonText: "Shop Now"),
        BannerData(label: "LIMITED EDITION", title: "Exclusive\nDrops", subtitle: "One-of-a-kind pieces from elite artisans.", buttonText: "Explore"),
        BannerData(label: "PRIVATE ACCESS", title: "Members\nOnly", subtitle: "Unlock bespoke collections reserved for you.", buttonText: "Discover")
    ]

    private var filteredProducts: [Product] {
        guard let name = selectedCategoryName else { return allProducts }
        return allProducts.filter { $0.categoryName == name }
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
                VStack(spacing: 0) {
                    bannerCarousel
                    categorySection
                    featuredSection
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
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: unreadCount > 0 ? "bell.badge" : "bell")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(.primary)
                            if unreadCount > 0 {
                                Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(AppColors.accent)
                                    .clipShape(Capsule())
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                    CartShortcutButton()
                }
            }
        }
        .navigationDestination(isPresented: $showAllCategories) { CategoriesView(showsTabBar: false) }
        .navigationDestination(isPresented: $showAllFeatured) { ProductListView(categoryFilter: nil, showsTabBar: false) }
        .navigationDestination(isPresented: $showAllArrivals) { ProductListView(categoryFilter: nil, showsTabBar: false) }
        .navigationDestination(isPresented: $state.showCart) {
            CartView()
        }
        .sheet(isPresented: $showNotifications, onDismiss: { Task { await refreshUnreadCount() } }) {
            NotificationCenterView()
                .environment(appState)
        }
        .task {
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
        .padding(.bottom, 4)
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

                Button(action: { showAllFeatured = true }) {
                    Text(data.buttonText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Category Filter Pills

    private var categorySection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Categories")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { showAllCategories = true }) {
                    Text("View All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryPill(name: "All", isSelected: selectedCategoryName == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedCategoryName = nil }
                    }
                    ForEach(categories) { category in
                        categoryPill(name: category.name, isSelected: selectedCategoryName == category.name) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategoryName = selectedCategoryName == category.name ? nil : category.name
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
    }

    private func categoryPill(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(isSelected ? Color.primary : Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Featured Section

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "FEATURED", action: { showAllFeatured = true })

            if featuredProducts.isEmpty {
                emptyBanner(icon: "star", message: "No featured products yet")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(featuredProducts) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                featuredCard(product)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func featuredCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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

                Image(systemName: "bookmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Circle())
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Text(product.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(product.formattedPrice)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: 150, alignment: .leading)
        }
        .frame(width: 150)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
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
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(filteredProducts.prefix(6)) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            productCard(product)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func productCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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

                Image(systemName: "bookmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Circle())
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
                Text(product.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(product.formattedPrice)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    // MARK: - Shared Helpers

    private func sectionHeader(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(3)
                .foregroundColor(.primary.opacity(0.5))
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
        }
        .padding(.horizontal, 20)
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
}

#Preview {
    HomeView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self], inMemory: true)
}
