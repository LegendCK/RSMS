//
//  AppColors.swift
//  infosys2
//
//  Luxury brand color palette — nude and warm tones.
//  Inspired by Davis Humphries Design nude palette for sophisticated, minimalist aesthetics.
//

import SwiftUI

struct AppColors {

    // MARK: - Primary

    /// Deep maroon — primary brand color
    static let primary = Color(hex: "6B3E3E")

    /// Maroon accent highlight
    static let accent = Color(hex: "8B4949")

    /// Lighter maroon for hover / pressed states
    static let accentLight = Color(hex: "A85555")

    /// Darker maroon for contrast
    static let accentDark = Color(hex: "4A2A2A")

    // MARK: - Purple / Plum Accent (replaced with warm beige)

    /// Warm beige — secondary luxury accent
    static let purple = Color(hex: "D1C7BD")

    /// Light pale beige for subtle highlights
    static let purpleLight = Color(hex: "EBE3DB")

    /// Deeper taupe for depth
    static let purpleDark = Color(hex: "A48374")

    // MARK: - Backgrounds

    /// Off-white — primary screen background
    static let backgroundPrimary = Color(hex: "FAFAF8")

    /// Slightly warmer surface
    static let backgroundSecondary = Color(hex: "F5F3F0")

    /// Card / elevated surface with warm undertone
    static let backgroundTertiary = Color(hex: "EFEFEC")

    /// Deep maroon — used for contrast highlights and text
    static let backgroundIvory = Color(hex: "6B3E3E")

    /// Warm white for light accents
    static let backgroundWarmWhite = Color(hex: "FAFAF8")

    // MARK: - Neutrals

    static let neutral900 = Color(hex: "3A2D28")
    static let neutral800 = Color(hex: "5A4D48")
    static let neutral700 = Color(hex: "8B7B73")
    static let neutral600 = Color(hex: "A48374")
    static let neutral500 = Color(hex: "B5A5A0")
    static let neutral400 = Color(hex: "CBAD8D")
    static let neutral300 = Color(hex: "D1C7BD")
    static let neutral200 = Color(hex: "EBE3DB")
    static let neutral100 = Color(hex: "F1EDE6")

    // MARK: - Text

    /// Deep brown — primary text on light backgrounds
    static let textPrimaryDark = Color(hex: "3A2D28")

    /// Warm taupe — secondary text on light backgrounds
    static let textSecondaryDark = Color(hex: "8B7B73")

    /// Light text for any dark surfaces
    static let textPrimaryLight = Color(hex: "F1EDE6")

    /// Secondary light text
    static let textSecondaryLight = Color(hex: "D1C7BD")


    // MARK: - Semantic

    static let success = Color(hex: "6B9B5C")
    static let error = Color(hex: "A5605A")
    static let warning = Color(hex: "A48374")
    static let info = Color(hex: "8B8B9A")

    // MARK: - Divider / Border

    static let divider = Color(hex: "D1C7BD")
    static let dividerLight = Color(hex: "EBE3DB")
    static let border = Color(hex: "CBAD8D")
}

