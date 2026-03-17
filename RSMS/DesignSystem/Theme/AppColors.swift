//
//  AppColors.swift
//  RSMS
//
//  Professional color palette — neutral and accessible.
//  Aligned with Apple HIG and WCAG accessibility standards.
//

import SwiftUI

struct AppColors {

    // MARK: - Primary Brand Colors

    /// Deep maroon — primary brand accent for selections, CTAs, and iconography
    static let primary = Color(hex: "800000")

    /// Deep maroon accent — primary interactive elements
    static let accent = Color(hex: "800000")

    /// Medium maroon for hover / pressed states
    static let accentLight = Color(hex: "A00000")

    /// Deeper maroon for contrast
    static let accentDark = Color(hex: "600000")

    // MARK: - Luxury Silver Accents

    /// Silverish-white — luxury surface tint
    static let silver = Color(hex: "E8E8E8")

    /// Platinum — premium metallic reference
    static let platinum = Color(hex: "F0EFED")

    /// Pearl — ultra-light warm silver for cards
    static let pearl = Color(hex: "F8F7F5")

    // MARK: - Secondary Brand Colors

    /// Dark gray — secondary accent
    static let secondary = Color(hex: "333333")

    /// Medium gray for subtle highlights
    static let secondaryLight = Color(hex: "808080")

    /// Lighter gray for depth
    static let secondaryDark = Color(hex: "1A1A1A")

    // MARK: - Backgrounds

    /// White — primary screen background
    static let backgroundPrimary = Color(hex: "FFFFFF")

    /// Off-white surface
    static let backgroundSecondary = Color(hex: "F5F5F5")

    /// Light gray for elevated surface
    static let backgroundTertiary = Color(hex: "EEEEEE")

    /// Pure white for maximum contrast
    static let backgroundWhite = Color(hex: "FFFFFF")

    /// Off-white for light accents
    static let backgroundWarmWhite = Color(hex: "F9F9F9")

    // MARK: - Neutrals

    static let neutral900 = Color(hex: "0A0A0A")
    static let neutral800 = Color(hex: "1A1A1A")
    static let neutral700 = Color(hex: "333333")
    static let neutral600 = Color(hex: "4D4D4D")
    static let neutral500 = Color(hex: "666666")
    static let neutral400 = Color(hex: "808080")
    static let neutral300 = Color(hex: "B3B3B3")
    static let neutral200 = Color(hex: "D3D3D3")
    static let neutral100 = Color(hex: "F0F0F0")

    // MARK: - Text

    /// Black — primary text on light backgrounds
    static let textPrimaryDark = Color(hex: "000000")

    /// Medium gray — secondary text on light backgrounds
    static let textSecondaryDark = Color(hex: "808080")

    /// White text for any dark surfaces
    static let textPrimaryLight = Color(hex: "FFFFFF")

    /// Light gray secondary text
    static let textSecondaryLight = Color(hex: "D3D3D3")


    // MARK: - Semantic

    static let success = Color(hex: "2D5F2E")
    static let error = Color(hex: "8B3A3A")
    static let warning = Color(hex: "8B6914")
    static let info = Color(hex: "4A4A5E")

    // MARK: - Divider / Border

    static let divider = Color(hex: "CCCCCC")
    static let dividerLight = Color(hex: "E6E6E6")
    static let border = Color(hex: "999999")
}

