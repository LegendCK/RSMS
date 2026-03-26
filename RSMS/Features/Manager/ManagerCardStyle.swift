//
//  ManagerCardStyle.swift
//  RSMS
//
//  Shared card styling for Boutique Manager modules.
//

import SwiftUI

extension View {
    func managerCardSurface(cornerRadius: CGFloat = AppSpacing.radiusMedium) -> some View {
        self
            .background(AppColors.backgroundSecondary.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
