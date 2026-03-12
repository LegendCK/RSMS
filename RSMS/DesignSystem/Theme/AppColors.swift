//
//  AppColors.swift
//  infosys2
//
//  Luxury brand color palette — deep black, champagne gold, regal purple, ivory.
//  Inspired by Tom Ford, Versace, and haute couture aesthetics.
//

import SwiftUI

struct AppColors {

    // MARK: - Primary

    /// Deep black — primary brand color
    static let primary = Color(hex: "0A0A0A")

    /// Champagne gold — luxury accent highlight
    static let accent = Color(hex: "C9A84C")

    /// Lighter gold for hover / pressed states
    static let accentLight = Color(hex: "D4BC6A")

    /// Darker gold for contrast
    static let accentDark = Color(hex: "A8893A")

    // MARK: - Purple / Plum Accent

    /// Muted regal purple — secondary luxury accent
    static let purple = Color(hex: "6B4C8A")

    /// Light lavender for subtle highlights
    static let purpleLight = Color(hex: "8B6FAE")

    /// Deep plum for depth
    static let purpleDark = Color(hex: "4A3066")

    // MARK: - Backgrounds

    /// Deep black — primary screen background
    static let backgroundPrimary = Color(hex: "0A0A0A")

    /// Slightly lighter dark surface
    static let backgroundSecondary = Color(hex: "151515")

    /// Card / elevated surface with purple tint
    static let backgroundTertiary = Color(hex: "1E1A24")

    /// Ivory — used for contrast highlights and text
    static let backgroundIvory = Color(hex: "FFFFF0")

    /// Warm white for light accents
    static let backgroundWarmWhite = Color(hex: "FAF8F5")

    // MARK: - Neutrals

    static let neutral900 = Color(hex: "1A1A1A")
    static let neutral800 = Color(hex: "2D2D2D")
    static let neutral700 = Color(hex: "3D3D3D")
    static let neutral600 = Color(hex: "555555")
    static let neutral500 = Color(hex: "737373")
    static let neutral400 = Color(hex: "9A9A9A")
    static let neutral300 = Color(hex: "BFBFBF")
    static let neutral200 = Color(hex: "E0E0E0")
    static let neutral100 = Color(hex: "F0F0F0")

    // MARK: - Text

    /// Ivory / off-white — primary text on dark backgrounds
    static let textPrimaryDark = Color(hex: "FAF8F0")

    /// Muted light grey — secondary text on dark backgrounds
    static let textSecondaryDark = Color(hex: "9A9A9A")

    /// Dark text for any light surfaces
    static let textPrimaryLight = Color(hex: "1A1A1A")

    /// Secondary dark text
    static let textSecondaryLight = Color(hex: "555555")

    // MARK: - Semantic

    static let success = Color(hex: "4CAF7D")
    static let error = Color(hex: "E05555")
    static let warning = Color(hex: "D4A84C")
    static let info = Color(hex: "5C9BD6")

    // MARK: - Divider / Border

    static let divider = Color(hex: "2A2A2A")
    static let dividerLight = Color(hex: "E0E0E0")
    static let border = Color(hex: "333333")
}

