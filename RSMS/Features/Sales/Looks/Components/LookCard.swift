//
//  LookCard.swift
//  RSMS
//

import SwiftUI

struct LookCard: View {
    let look: Look
    let itemCount: Int
    let totalPrice: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Visual Collage Placeholder
            ZStack {
                Color(.systemGray5)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundColor(.secondary)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
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
