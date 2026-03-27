//
//  LookCard.swift
//  RSMS
//

import SwiftUI

struct LookCard: View {
    let look: SalesLookDTO
    let itemCount: Int
    let totalPrice: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProductArtworkView(
                imageSource: look.thumbnailSource ?? "",
                fallbackSymbol: "photo.on.rectangle.angled",
                cornerRadius: 12
            )
            .frame(height: 160)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(look.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("By \(look.creatorName) • \(itemCount) items")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(totalPrice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}
