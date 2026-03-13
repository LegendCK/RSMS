//
//  GlassEffect.swift
//  infosys2
//
//  iOS 26 glass effect (glassmorphism) utilities for consistent blur materials and transparency.
//  Uses native SwiftUI Material API for performance and consistency.
//

import SwiftUI

/// iOS 26 glass effect levels matching Apple's design system
enum GlassLevel {
    case ultraThin  // `.ultraThinMaterial` - Maximum transparency
    case thin       // `.thinMaterial` - High transparency with subtle blur
    case regular    // `.regularMaterial` - Balanced blur and transparency
    case thick      // `.thickMaterial` - Strong blur with reduced transparency
    
    var material: Material {
        switch self {
        case .ultraThin: return .ultraThinMaterial
        case .thin: return .thinMaterial
        case .regular: return .regularMaterial
        case .thick: return .thickMaterial
        }
    }
}

/// Glass effect modifier that applies iOS 26 blur material with border
struct GlassEffectModifier: ViewModifier {
    var level: GlassLevel = .regular
    var borderOpacity: Double = 0.2
    var cornerRadius: CGFloat = AppSpacing.radiusLarge
    
    func body(content: Content) -> some View {
        content
            .background(level.material)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color.white.opacity(borderOpacity),
                        lineWidth: 1
                    )
            )
            .cornerRadius(cornerRadius)
    }
}

extension View {
    /// Apply iOS 26 glass effect with customizable level and styling
    /// - Parameters:
    ///   - level: Glass transparency level (.ultraThin, .thin, .regular, .thick, .chrome)
    ///   - borderOpacity: Opacity of the white border (0.0-1.0)
    ///   - cornerRadius: Corner radius of the glass surface
    func glassEffect(
        level: GlassLevel = .regular,
        borderOpacity: Double = 0.2,
        cornerRadius: CGFloat = AppSpacing.radiusLarge
    ) -> some View {
        modifier(
            GlassEffectModifier(
                level: level,
                borderOpacity: borderOpacity,
                cornerRadius: cornerRadius
            )
        )
    }
}

// MARK: - Preset Glass Styles

/// Floating button/pill glass effect (maximum transparency)
struct GlassPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(level: .ultraThin, borderOpacity: 0.2, cornerRadius: 12)
    }
}

/// Card glass effect (balanced blur and visibility)
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(level: .regular, borderOpacity: 0.2, cornerRadius: AppSpacing.radiusLarge)
    }
}

/// Modal/Sheet glass effect (strong blur for overlays)
struct GlassModal: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(level: .thick, borderOpacity: 0.15, cornerRadius: 20)
    }
}

/// Input field glass effect (thin material for readability)
struct GlassInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(level: .thin, borderOpacity: 0.25, cornerRadius: AppSpacing.radiusMedium)
    }
}

extension View {
    /// Apply glass pill styling (buttons, tabs)
    func glassPill() -> some View {
        modifier(GlassPill())
    }
    
    /// Apply glass card styling (product cards, list items)
    func glassCard() -> some View {
        modifier(GlassCard())
    }
    
    /// Apply glass modal styling (sheets, overlays)
    func glassModal() -> some View {
        modifier(GlassModal())
    }
    
    /// Apply glass input styling (text fields, search bars)
    func glassInput() -> some View {
        modifier(GlassInput())
    }
}

#Preview {
    ZStack {
        LinearGradient(
            gradient: Gradient(colors: [AppColors.backgroundPrimary, AppColors.accent.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Ultra Thin Glass
            Text("Ultra Thin Glass")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
                .frame(maxWidth: .infinity)
                .padding()
                .glassEffect(level: .ultraThin)
            
            // Thin Glass
            Text("Thin Glass (Input)")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
                .frame(maxWidth: .infinity)
                .padding()
                .glassInput()
            
            // Regular Glass (Card)
            VStack(spacing: 8) {
                Text("Luxury Product")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Premium glass effect for cards")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .glassCard()
            
            // Thick Glass
            Text("Thick Glass (Modal)")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
                .frame(maxWidth: .infinity)
                .padding()
                .glassEffect(level: .thick)
            
            Spacer()
        }
        .padding()
    }
}
