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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                            Text("AI PICKS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                        }
                        Text("RECOMMENDED FOR YOU")
                            .font(.system(size: 13, weight: .black))
                            .tracking(2)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 14)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 40)
                        Spacer()
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(recommendations) { product in
                                NavigationLink(value: product) {
                                    recommendationCard(product)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .task {
                await loadRecommendations()
            }
        }
    }

    // MARK: - Card

    private func recommendationCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            ZStack(alignment: .topTrailing) {
                productImage(product)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // AI sparkle badge
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(AppColors.accent)
                    .clipShape(Circle())
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(product.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 34, alignment: .top)

                Text(product.formattedPrice)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.accent)
            }
            .frame(width: 160, alignment: .leading)
        }
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
                    Color(.systemGray5)
                        .overlay(
                            Image(systemName: "bag.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.4))
                        )
                }
            }
        } else {
            Color(.systemGray5)
                .overlay(
                    Image(systemName: "bag.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray.opacity(0.4))
                )
        }
    }

    // MARK: - Load

    private func loadRecommendations() async {
        guard let profile = appState.currentUserProfile else {
            isLoading = false
            return
        }

        // Fetch customer's order history
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
                limit: 10
            )
        } catch {
            // Fallback to popular items if fetch fails
            print("[RecommendedForYou] Order fetch failed: \(error.localizedDescription)")
            recommendations = RecommendationEngine.shared.recommendForCustomer(
                orders: [],
                orderItems: [],
                allProducts: allProducts,
                limit: 10
            )
        }

        isLoading = false
    }
}
