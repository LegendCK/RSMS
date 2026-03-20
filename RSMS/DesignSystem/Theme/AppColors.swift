//
//  AppColors.swift
//  RSMS
//
//  Adaptive color palette — every token responds to light and dark mode
//  automatically via UIColor trait-collection resolution.
//
//  Light mode  →  Maison Luxe white luxury aesthetic (original design)
//  Dark mode   →  Deep obsidian surfaces, brightened maroon accent,
//                 warm off-white text — premium & readable.
//

import SwiftUI

struct AppColors {

    // MARK: - Adaptive Helper

    /// Returns a Color that automatically switches between `light` and `dark`
    /// hex values when the system appearance changes.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    // MARK: - Primary Brand Colors

    /// Deep maroon in light; brightened maroon in dark for WCAG contrast on dark surfaces.
    static let primary     = adaptive(light: "800000", dark: "C04848")

    /// Primary interactive accent — CTAs, selections, iconography.
    static let accent      = adaptive(light: "800000", dark: "C04848")

    /// Pressed / hover state.
    static let accentLight = adaptive(light: "A00000", dark: "D06060")

    /// Deep shade for contrast layers.
    static let accentDark  = adaptive(light: "600000", dark: "A03030")

    // MARK: - Luxury Silver Accents

    /// Silverish-white surface tint / metallic feel.
    static let silver   = adaptive(light: "E8E8E8", dark: "2E2E2E")

    /// Platinum — premium metallic reference.
    static let platinum = adaptive(light: "F0EFED", dark: "262624")

    /// Pearl — ultra-light warm silver for cards.
    static let pearl    = adaptive(light: "F8F7F5", dark: "1F1F1D")

    // MARK: - Secondary Brand Colors

    /// Dark gray secondary accent.
    static let secondary      = adaptive(light: "333333", dark: "C8C5C0")

    /// Medium gray for subtle highlights.
    static let secondaryLight = adaptive(light: "808080", dark: "9A9590")

    /// Near-black depth layer.
    static let secondaryDark  = adaptive(light: "1A1A1A", dark: "E5E2DD")

    // MARK: - Backgrounds

    /// Primary screen canvas.
    /// Light: pure white  |  Dark: deep obsidian #0F0F0F
    static let backgroundPrimary = adaptive(light: "FFFFFF", dark: "0F0F0F")

    /// Elevated card / section surface.
    /// Light: off-white #F5F5F5  |  Dark: dark charcoal #1C1C1C
    static let backgroundSecondary = adaptive(light: "F5F5F5", dark: "1C1C1C")

    /// Further elevated surface (inputs, thumbnails).
    /// Light: light gray #EEEEEE  |  Dark: #252525
    static let backgroundTertiary = adaptive(light: "EEEEEE", dark: "252525")

    /// Maximum contrast white surface.
    static let backgroundWhite = adaptive(light: "FFFFFF", dark: "0F0F0F")

    /// Warm off-white accent surface.
    static let backgroundWarmWhite = adaptive(light: "F9F9F9", dark: "171717")

    /// Legacy card surface alias.
    static let surfaceDark = adaptive(light: "F5F5F5", dark: "1C1C1C")

    // MARK: - Neutrals

    /// A continuous tonal scale — each step adapts independently.
    /// In dark mode the scale is inverted so that 900 becomes the lightest.
    static let neutral900 = adaptive(light: "0A0A0A", dark: "F5F2EE")
    static let neutral800 = adaptive(light: "1A1A1A", dark: "E0DDD8")
    static let neutral700 = adaptive(light: "333333", dark: "C8C5C0")
    static let neutral600 = adaptive(light: "4D4D4D", dark: "A8A5A0")
    static let neutral500 = adaptive(light: "666666", dark: "888580")
    static let neutral400 = adaptive(light: "808080", dark: "686560")
    static let neutral300 = adaptive(light: "B3B3B3", dark: "484542")
    static let neutral200 = adaptive(light: "D3D3D3", dark: "323030")
    static let neutral100 = adaptive(light: "F0F0F0", dark: "1E1C1C")

    // MARK: - Text

    /// Primary body / heading text on the main canvas.
    /// Light: #000000 (black)  |  Dark: #F0EDE8 (warm off-white)
    static let textPrimaryDark = adaptive(light: "000000", dark: "F0EDE8")

    /// Secondary / muted text on the main canvas.
    /// Light: #808080  |  Dark: #9A9590
    static let textSecondaryDark = adaptive(light: "808080", dark: "9A9590")

    /// Text that sits on dark surfaces (buttons, image overlays).
    /// Always near-white — no change needed between modes.
    static let textPrimaryLight = adaptive(light: "FFFFFF", dark: "FFFFFF")

    /// Secondary text on dark surfaces — light gray.
    static let textSecondaryLight = adaptive(light: "D3D3D3", dark: "D3D3D3")

    // MARK: - Semantic

    /// Positive / in-stock / success state.
    /// Light: forest green #2D5F2E  |  Dark: vibrant green #4CAF50
    static let success = adaptive(light: "2D5F2E", dark: "4CAF50")

    /// Error / out-of-stock / destructive state.
    /// Light: deep red #8B3A3A  |  Dark: bright red #EF5350
    static let error = adaptive(light: "8B3A3A", dark: "EF5350")

    /// Warning / low-stock / caution state.
    /// Light: amber #8B6914  |  Dark: bright amber #FFA726
    static let warning = adaptive(light: "8B6914", dark: "FFA726")

    /// Informational / neutral state.
    /// Light: slate #4A4A5E  |  Dark: periwinkle #7986CB
    static let info = adaptive(light: "4A4A5E", dark: "7986CB")

    // MARK: - Dividers & Borders

    /// Standard horizontal rule.
    static let divider      = adaptive(light: "CCCCCC", dark: "333333")

    /// Subtle divider between closely related items.
    static let dividerLight = adaptive(light: "E6E6E6", dark: "252525")

    /// Outline border on inputs and cards.
    static let border       = adaptive(light: "999999", dark: "444444")
}
