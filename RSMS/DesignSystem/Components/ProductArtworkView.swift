//
//  ProductArtworkView.swift
//  RSMS
//
//  Shared product image renderer for customer flows.
//  Supports Supabase image URLs with SF Symbol fallback.
//

import SwiftUI

struct ProductArtworkView: View {
    let imageSource: String
    let fallbackSymbol: String
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppColors.backgroundSecondary)

            if let url = ProductImageResolver.url(from: imageSource) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        ProgressView()
                            .tint(AppColors.accent)
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var fallback: some View {
        Image(systemName: fallbackSymbol)
            .font(AppTypography.iconProductMedium)
            .foregroundColor(AppColors.neutral600)
    }
}

enum ProductImageResolver {
    static func url(from raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }

        let base = SupabaseConfig.projectURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if value.hasPrefix("/storage/v1/object/public/") {
            return URL(string: "\(base)\(value)")
        }
        if value.hasPrefix("storage/v1/object/public/") {
            return URL(string: "\(base)/\(value)")
        }
        if value.hasPrefix("/object/public/") {
            return URL(string: "\(base)/storage/v1\(value)")
        }
        if value.hasPrefix("object/public/") {
            return URL(string: "\(base)/storage/v1/\(value)")
        }

        // Bucket-prefixed object path, e.g. `product-images/products/<id>/1.jpg`
        if value.hasPrefix("product-images/") {
            let pathOnly = String(value.dropFirst("product-images/".count))
            let encoded = pathOnly.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pathOnly
            return URL(string: "\(base)/storage/v1/object/public/product-images/\(encoded)")
        }

        let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
        return URL(string: "\(base)/storage/v1/object/public/product-images/\(encoded)")
    }
}
