//
//  LiquidGlassTheme.swift
//  RSMS
//
//  iOS 26 Liquid Glass design system with dynamic refraction and blur effects.
//  Creates translucent, fluid surfaces that adapt to content.
//

import SwiftUI

/// iOS 26 Liquid Glass opacity and blur configuration
struct LiquidGlassConfig {
    /// Opacity of glass surface (0.0-1.0)
    let opacity: Double
    
    /// Blur radius in points
    let blurRadius: CGFloat
    
    /// Border opacity for definition
    let borderOpacity: Double
    
    /// Whether to add additional texture overlay
    let hasTextureOverlay: Bool
    
    // MARK: - Presets
    
    /// Ultra-thin for floating elements and prominence
    static let ultraThin = LiquidGlassConfig(
        opacity: 0.5,
        blurRadius: 8,
        borderOpacity: 0.15,
        hasTextureOverlay: false
    )
    
    /// Thin for interactive surfaces and inputs
    static let thin = LiquidGlassConfig(
        opacity: 0.65,
        blurRadius: 12,
        borderOpacity: 0.2,
        hasTextureOverlay: false
    )
    
    /// Regular for content cards and surfaces
    static let regular = LiquidGlassConfig(
        opacity: 0.75,
        blurRadius: 16,
        borderOpacity: 0.25,
        hasTextureOverlay: true
    )
    
    /// Thick for modals and strong separation
    static let thick = LiquidGlassConfig(
        opacity: 0.85,
        blurRadius: 20,
        borderOpacity: 0.3,
        hasTextureOverlay: true
    )
}

/// Dynamic glass effect that responds to content and state
struct DynamicLiquidGlass: ViewModifier {
    var config: LiquidGlassConfig = .regular
    var backgroundColor: Color = Color.white
    var cornerRadius: CGFloat = AppSpacing.radiusLarge
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base blur layer
                    backgroundColor
                        .opacity(config.opacity)
                        .blur(radius: config.blurRadius / 2)
                    
                    // Optional texture overlay for depth
                    if config.hasTextureOverlay {
                        Color.white
                            .opacity(0.05)
                            .noise(scale: 0.5)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(config.borderOpacity * 1.5),
                                Color.white.opacity(config.borderOpacity * 0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(cornerRadius)
    }
}

/// Adds subtle noise texture for depth
struct NoiseModifier: ViewModifier {
    var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .background(
                Canvas { context, size in
                    var random = SystemRandomNumberGenerator()
                    let strideValue = max(1, Int(scale))
                    for x in stride(from: 0, to: Int(size.width), by: strideValue) {
                        for y in stride(from: 0, to: Int(size.height), by: strideValue) {
                            let opacity = Double.random(in: 0.02...0.08, using: &random)
                            let rect = CGRect(
                                x: CGFloat(x),
                                y: CGFloat(y),
                                width: scale,
                                height: scale
                            )
                            context.fill(
                                Path(rect),
                                with: .color(Color.black.opacity(opacity))
                            )
                        }
                    }
                }
            )
    }
}

extension View {
    /// Apply iOS 26 Liquid Glass effect with dynamic configuration
    func liquidGlass(
        config: LiquidGlassConfig = .regular,
        backgroundColor: Color = Color.white,
        cornerRadius: CGFloat = AppSpacing.radiusLarge
    ) -> some View {
        modifier(DynamicLiquidGlass(
            config: config,
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius
        ))
    }
    
    /// Add subtle noise texture for depth and dimension
    func noise(scale: CGFloat = 1.0) -> some View {
        modifier(NoiseModifier(scale: scale))
    }
}

/// iOS 26 Shadow system with dynamic depth
struct LiquidShadow {
    /// Subtle elevation shadow for cards
    static let subtle = Shadow(
        color: Color.black.opacity(0.05),
        radius: 4,
        x: 0,
        y: 2
    )
    
    /// Medium elevation shadow for modals
    static let medium = Shadow(
        color: Color.black.opacity(0.08),
        radius: 12,
        x: 0,
        y: 4
    )
    
    /// Strong elevation shadow for important overlays
    static let strong = Shadow(
        color: Color.black.opacity(0.12),
        radius: 20,
        x: 0,
        y: 8
    )
}

struct Shadow: Equatable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    /// Apply iOS 26 shadow system
    func liquidShadow(_ shadow: Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}
