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
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.textPrimaryDark.opacity(0.12), lineWidth: 0.75)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 8)
    }
}
