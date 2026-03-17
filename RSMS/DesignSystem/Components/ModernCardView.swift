//
//  ModernCardView.swift
//  RSMS
//
//  iOS 26 card component with Liquid Glass, dynamic updates, and refined spacing.
//

import SwiftUI

struct ModernCardView<Content: View>: View {
    @ViewBuilder let content: Content
    var backgroundColor: Color = AppColors.backgroundSecondary
    var glassConfig: LiquidGlassConfig = .regular
    var cornerRadius: CGFloat = AppSpacing.radiusLarge
    var padding: CGFloat = AppSpacing.md
    var showShadow: Bool = true
    var shadowStyle: Shadow = LiquidShadow.subtle
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 0
    
    var body: some View {
        content
            .padding(padding)
            .liquidGlass(
                config: glassConfig,
                backgroundColor: backgroundColor,
                cornerRadius: cornerRadius
            )
            .overlay {
                if borderWidth > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }
            }
            .if(showShadow) { view in
                view.liquidShadow(shadowStyle)
            }
    }
}

/// Modern list card for displaying items
struct ModernListCard<Content: View>: View {
    @ViewBuilder let content: Content
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ModernCardButtonStyle(isSelected: isSelected))
    }
}

struct ModernCardButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(AppSpacing.md)
            .liquidGlass(
                config: isSelected ? .thin : .regular,
                backgroundColor: AppColors.backgroundSecondary,
                cornerRadius: AppSpacing.radiusLarge
            )
            .liquidShadow(isSelected ? LiquidShadow.medium : LiquidShadow.subtle)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Modern metric card for displaying KPIs
struct MetricCard: View {
    let label: String
    let value: String
    let trend: String?
    var trendIsPositive: Bool = true
    var icon: String? = nil
    
    var body: some View {
        ModernCardView(
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Text(label)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                        
                        Spacer()
                        
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    
                    Text(value)
                        .font(AppTypography.heading2)
                        .foregroundColor(AppColors.textPrimaryDark)
                    
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Image(systemName: trendIsPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 12, weight: .semibold))
                            
                            Text(trend)
                                .font(AppTypography.caption)
                        }
                        .foregroundColor(trendIsPositive ? AppColors.success : AppColors.error)
                    }
                }
            },
            glassConfig: .thin,
            cornerRadius: AppSpacing.radiusMedium
        )
    }
}

/// Action card with button states
struct ActionCard: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let icon: String
    let action: () -> Void
    var isLoading: Bool = false
    
    var body: some View {
        modifiedActionCardContent()
    }
    
    @ViewBuilder
    private func modifiedActionCardContent() -> some View {
        ModernCardView(
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            
                            Text(subtitle)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                    
                    Button(action: action) {
                        if isLoading {
                            ProgressView()
                                .tint(AppColors.textPrimaryLight)
                        } else {
                            Text(actionTitle.uppercased())
                                .font(AppTypography.buttonSecondary)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .disabled(isLoading)
                }
            },
            glassConfig: .regular,
            cornerRadius: AppSpacing.radiusLarge
        )
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        
        VStack(spacing: AppSpacing.lg) {
            MetricCard(
                label: "Total Revenue",
                value: "₹1,24,567",
                trend: "+12.5%",
                trendIsPositive: true,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            ModernCardView(
                content: {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Featured Product")
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        
                        Text("Explore our latest collection")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                },
                cornerRadius: AppSpacing.radiusLarge
            )
            
            Spacer()
        }
        .padding(AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.lg)
    }
}
