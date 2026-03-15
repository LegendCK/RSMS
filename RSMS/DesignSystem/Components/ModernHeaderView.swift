//
//  ModernHeaderView.swift
//  RSMS
//
//  iOS 26 modern header with Liquid Glass, dynamic blur, and refined typography.
//

import SwiftUI

struct ModernHeaderView: View {
    let title: String
    let subtitle: String?
    var backgroundColor: Color = AppColors.backgroundPrimary
    var showBackButton: Bool = false
    var onBack: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: String = "ellipsis"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header container with liquid glass
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // Top action row
                HStack {
                    if showBackButton {
                        Button(action: { onBack?() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Spacer()
                    
                    if let action = trailingAction {
                        Button(action: action) {
                            Image(systemName: trailingIcon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.heading1)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .lineLimit(2)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .lineLimit(1)
                    }
                }
            }
            .padding(AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
            .liquidGlass(
                config: .thin,
                backgroundColor: backgroundColor,
                cornerRadius: AppSpacing.radiusLarge
            )
            .padding(AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
        }
        .background(backgroundColor)
    }
}

/// Navigation header for tab views
struct TabNavigationHeader: View {
    let title: String
    var backgroundColor: Color = AppColors.backgroundPrimary
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.heading2)
                .foregroundColor(AppColors.textPrimaryDark)
            
            Spacer()
        }
        .padding(AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.md)
        .background(backgroundColor)
    }
}

/// iOS 26 section header with divider
struct SectionHeader: View {
    let title: String
    var showDivider: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(AppTypography.overline)
                .tracking(1.5)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.screenHorizontal)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        
        VStack(spacing: 0) {
            ModernHeaderView(
                title: "Welcome",
                subtitle: "March 13, 2026"
            )
            
            Spacer()
        }
    }
}
