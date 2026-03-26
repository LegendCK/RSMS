//
//  RecommendationEngine.swift
//  RSMS
//
//  On-device product recommendation engine using NaturalLanguage embeddings
//  and content-based filtering. No API keys needed — runs entirely on-device.
//

import Foundation
import NaturalLanguage
import SwiftData

@MainActor
final class RecommendationEngine {

    static let shared = RecommendationEngine()
    private init() {}

    // MARK: - "For You" Recommendations

    /// Returns personalized product recommendations for a customer based on their
    /// order history and preferences. Uses NL embeddings for semantic similarity.
    func recommendForCustomer(
        orders: [OrderDTO],
        orderItems: [OrderItemDTO],
        allProducts: [Product],
        limit: Int = 10
    ) -> [Product] {
        guard !allProducts.isEmpty else { return [] }

        // 1. Build customer preference profile from purchase history
        let purchasedProductIds = Set(orderItems.map(\.productId))
        let purchasedProducts = allProducts.filter { purchasedProductIds.contains($0.id) }

        // If no purchase history, return popular + featured items
        guard !purchasedProducts.isEmpty else {
            return popularRecommendations(from: allProducts, limit: limit)
        }

        // 2. Extract preference signals
        let preferredCategories = frequencyMap(purchasedProducts.map(\.categoryName))
        let preferredBrands = frequencyMap(purchasedProducts.map(\.brand))
        let preferredMaterials = frequencyMap(purchasedProducts.map(\.material).filter { !$0.isEmpty })
        let avgPrice = purchasedProducts.map(\.price).reduce(0, +) / Double(purchasedProducts.count)

        // 3. Score each unseen product
        let unseenProducts = allProducts.filter { !purchasedProductIds.contains($0.id) && $0.stockCount > 0 }

        let scored = unseenProducts.map { product -> (Product, Double) in
            var score: Double = 0

            // Category affinity (strongest signal)
            if let categoryScore = preferredCategories[product.categoryName] {
                score += Double(categoryScore) * 30
            }

            // Brand affinity
            if let brandScore = preferredBrands[product.brand] {
                score += Double(brandScore) * 20
            }

            // Material affinity
            if !product.material.isEmpty, let matScore = preferredMaterials[product.material] {
                score += Double(matScore) * 10
            }

            // Price proximity (prefer products in similar price range)
            let priceDiff = abs(product.price - avgPrice) / max(avgPrice, 1)
            score += max(0, 15 - priceDiff * 10)

            // Boost featured & limited edition
            if product.isFeatured { score += 8 }
            if product.isLimitedEdition { score += 5 }

            // Rating boost
            score += product.rating * 2

            // Semantic similarity boost using NL embeddings
            score += semanticSimilarityBoost(product: product, purchasedProducts: purchasedProducts)

            return (product, score)
        }

        // 4. Return top scored products
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: - Cross-sell / Upsell (Assisted Selling)

    /// Given a product being viewed, suggests complementary products for cross-selling.
    func crossSellSuggestions(
        for currentProduct: Product,
        customerOrders: [OrderItemDTO],
        allProducts: [Product],
        limit: Int = 6
    ) -> [Product] {
        let candidates = allProducts.filter { $0.id != currentProduct.id && $0.stockCount > 0 }
        guard !candidates.isEmpty else { return [] }

        let scored = candidates.map { product -> (Product, Double) in
            var score: Double = 0

            // Complementary categories (cross-sell)
            let affinity = categoryAffinity(currentProduct.categoryName, product.categoryName)
            score += affinity * 25

            // Same brand (upsell)
            if product.brand == currentProduct.brand {
                score += 15
            }

            // Similar price range (within 50% band)
            let priceRatio = product.price / max(currentProduct.price, 1)
            if priceRatio > 0.5 && priceRatio < 2.0 {
                score += 10
            }

            // Different category preferred for cross-sell
            if product.categoryName != currentProduct.categoryName {
                score += 5
            }

            // Popularity signals
            if product.isFeatured { score += 5 }
            score += product.rating

            // NL similarity
            score += semanticSimilarityBoost(product: product, purchasedProducts: [currentProduct]) * 0.5

            return (product, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: - Popular Fallback

    private func popularRecommendations(from products: [Product], limit: Int) -> [Product] {
        products
            .filter { $0.stockCount > 0 }
            .sorted { lhs, rhs in
                let lScore = (lhs.isFeatured ? 10.0 : 0) + lhs.rating + (lhs.isLimitedEdition ? 3.0 : 0)
                let rScore = (rhs.isFeatured ? 10.0 : 0) + rhs.rating + (rhs.isLimitedEdition ? 3.0 : 0)
                return lScore > rScore
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - NL Embeddings

    private func semanticSimilarityBoost(product: Product, purchasedProducts: [Product]) -> Double {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return 0 }

        let productTerms = tokenize("\(product.name) \(product.categoryName) \(product.brand) \(product.material)")
        let purchasedTerms = purchasedProducts.flatMap {
            tokenize("\($0.name) \($0.categoryName) \($0.brand) \($0.material)")
        }

        guard !productTerms.isEmpty, !purchasedTerms.isEmpty else { return 0 }

        var totalSimilarity: Double = 0
        var count = 0

        for pTerm in productTerms {
            for hTerm in purchasedTerms {
                let distance = embedding.distance(between: pTerm.lowercased(), and: hTerm.lowercased())
                if distance < 2.0 { // Valid distance (not max/unknown)
                    // NLEmbedding distance is 0-2, where 0 = identical. Convert to similarity 0-1.
                    let similarity = max(0, 1.0 - distance / 2.0)
                    totalSimilarity += similarity
                    count += 1
                }
            }
        }

        guard count > 0 else { return 0 }
        return (totalSimilarity / Double(count)) * 10 // Scale to scoring range
    }

    // MARK: - Helpers

    private func frequencyMap(_ items: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for item in items where !item.isEmpty {
            map[item, default: 0] += 1
        }
        return map
    }

    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    /// Category affinity scores for cross-selling.
    /// E.g., Watches + Straps = high, Jewelry + Watches = medium
    private func categoryAffinity(_ cat1: String, _ cat2: String) -> Double {
        let c1 = cat1.lowercased()
        let c2 = cat2.lowercased()

        // High affinity pairs
        let highAffinityPairs: [(String, String)] = [
            ("watch", "strap"), ("watch", "accessori"),
            ("jewel", "watch"), ("ring", "necklace"),
            ("bag", "wallet"), ("shoe", "belt"),
            ("fragrance", "candle"), ("men", "accessori"),
            ("women", "jewel"), ("suit", "shirt"),
        ]

        for (a, b) in highAffinityPairs {
            if (c1.contains(a) && c2.contains(b)) || (c1.contains(b) && c2.contains(a)) {
                return 1.0
            }
        }

        // Medium affinity — same broad category
        if c1.contains("men") && c2.contains("men") { return 0.5 }
        if c1.contains("women") && c2.contains("women") { return 0.5 }

        return 0.2
    }
}
