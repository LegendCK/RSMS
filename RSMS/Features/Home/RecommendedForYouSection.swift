//
//  RecommendedForYouSection.swift
//  RSMS
//
//  "Recommended for You" section on the customer HomeView.
//  Uses on-device RecommendationEngine (NaturalLanguage + content filtering).
//

import SwiftUI
import SwiftData
import Supabase

struct RecommendedForYouSection: View {
    @Environment(AppState.self) private var appState
    @Query private var allProducts: [Product]

    @State private var recommendations: [Product] = []
    @State private var isLoading = true

    var body: some View {
        if !recommendations.isEmpty || isLoading {
            VStack(alignment: .leading, spacing: 0) {
                // Section Header
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .accessibilityHidden(true)
                    Text("RECOMMENDED FOR YOU")
                        .font(.system(size: 13, weight: .black))
                        .tracking(2)
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 30)
                        Spacer()
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recommendations) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    recommendationCard(product)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
            }
            .padding(.bottom, 10)
            .task {
                await loadRecommendations()
            }
        }
    }

    // MARK: - Card

    private func recommendationCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack(alignment: .topLeading) {
                productImage(product)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.border.opacity(0.35), lineWidth: 0.8)
                    )

                // AI badge
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 7, weight: .bold))
                    Text("AI")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(AppColors.accent.opacity(0.85))
                .clipShape(Capsule())
                .padding(6)
            }

            // Details
            VStack(alignment: .leading, spacing: 5) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.8)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)

                Text(product.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)

                Text(product.formattedPrice)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.accent)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .frame(width: 150, alignment: .leading)
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recommended: \(product.brand) \(product.name), \(product.formattedPrice)")
        .accessibilityHint("Double tap to view product details")
    }

    @ViewBuilder
    private func productImage(_ product: Product) -> some View {
        if let firstImage = product.imageList.first,
           let url = URL(string: firstImage), firstImage.hasPrefix("http") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        Color(.systemGray6)
            .overlay(
                Image(systemName: "bag.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.3))
            )
    }

    // MARK: - Load

    private func loadRecommendations() async {
        guard let profile = appState.currentUserProfile else {
            // Still show popular recommendations for guests
            recommendations = RecommendationEngine.shared.recommendForCustomer(
                orders: [],
                orderItems: [],
                allProducts: allProducts,
                limit: 8
            )
            isLoading = false
            return
        }

        do {
            let client = SupabaseManager.shared.client
            let orders: [OrderDTO] = try await client
                .from("orders")
                .select()
                .eq("client_id", value: profile.id.uuidString.lowercased())
                .execute()
                .value

            let orderIds = orders.map(\.id)
            var allItems: [OrderItemDTO] = []
            for orderId in orderIds {
                let items: [OrderItemDTO] = try await client
                    .from("order_items")
                    .select()
                    .eq("order_id", value: orderId.uuidString.lowercased())
                    .execute()
                    .value
                allItems.append(contentsOf: items)
            }

            recommendations = RecommendationEngine.shared.recommendForCustomer(
                orders: orders,
                orderItems: allItems,
                allProducts: allProducts,
                limit: 8
            )
        } catch {
            print("[RecommendedForYou] Order fetch failed: \(error.localizedDescription)")
            recommendations = RecommendationEngine.shared.recommendForCustomer(
                orders: [],
                orderItems: [],
                allProducts: allProducts,
                limit: 8
            )
        }

        isLoading = false
    }
}
