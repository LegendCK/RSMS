//
//  AppTypography.swift
//  infosys2
//
//  SF Pro typography system — native iOS luxury styling.
//  All text uses SF Pro (.default) for a clean, premium Apple-native feel.
//

import SwiftUI

struct AppTypography {

    // MARK: - Display / Headlines (SF Pro)

    /// Large display title — 34pt bold
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)

    /// Medium display — 28pt bold
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .default)

    /// Small display — 24pt semibold
    static let displaySmall = Font.system(size: 24, weight: .semibold, design: .default)

    // MARK: - Headings (SF Pro)

    /// Heading 1 — 22pt semibold
    static let heading1 = Font.system(size: 22, weight: .semibold, design: .default)

    /// Heading 2 — 20pt semibold
    static let heading2 = Font.system(size: 20, weight: .semibold, design: .default)

    /// Heading 3 — 18pt medium
    static let heading3 = Font.system(size: 18, weight: .medium, design: .default)

    // MARK: - Body (SF Pro — Default)

    /// Body large — 17pt (iOS standard body)
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)

    /// Body medium — 15pt
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)

    /// Body small — 13pt
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Labels & Captions

    /// Label — 15pt medium
    static let label = Font.system(size: 15, weight: .medium, design: .default)

    /// Caption — 12pt
    static let caption = Font.system(size: 12, weight: .regular, design: .default)

    /// Overline / Eyebrow — 11pt semibold uppercase
    static let overline = Font.system(size: 11, weight: .semibold, design: .default)

    // MARK: - Micro Tokens (for badges, status pills, inline metadata)

    /// Micro label — 10pt medium (stat labels, timestamps, role tags)
    static let micro = Font.system(size: 10, weight: .medium, design: .default)

    /// Nano badge — 9pt bold (status pills like "ACTIVE", "PENDING")
    static let nano = Font.system(size: 9, weight: .bold, design: .default)

    /// Pico badge — 8pt bold (inline tags like "LTD", "OFF", "INACTIVE")
    static let pico = Font.system(size: 8, weight: .bold, design: .default)

    // MARK: - Buttons

    /// Primary button — 16pt semibold
    static let buttonPrimary = Font.system(size: 16, weight: .semibold, design: .default)

    /// Secondary button — 14pt medium
    static let buttonSecondary = Font.system(size: 14, weight: .medium, design: .default)

    // MARK: - Navigation

    /// Tab bar label — 10pt medium
    static let tabLabel = Font.system(size: 10, weight: .medium, design: .default)

    /// Navigation bar title — 18pt semibold
    static let navTitle = Font.system(size: 18, weight: .semibold, design: .default)

    // MARK: - Price

    /// Price hero display — 22pt semibold
    static let priceDisplay = Font.system(size: 22, weight: .semibold, design: .default)

    /// Price small — 16pt medium
    static let priceSmall = Font.system(size: 16, weight: .medium, design: .default)

    // MARK: - Icons & Inline

    /// Icon label — 16pt (for SF Symbol icons in toolbars and rows)
    static let iconMedium = Font.system(size: 16)

    /// Icon small — 14pt (for smaller inline icons)
    static let iconSmall = Font.system(size: 14)

    /// Icon large — 22pt light (for action tile icons)
    static let iconAction = Font.system(size: 22, weight: .light)

    /// Icon hero — 48pt light (for onboarding/splash hero icons)
    static let iconHero = Font.system(size: 48, weight: .light)

    /// Icon decorative — 80pt ultraLight (for large decorative icons)
    static let iconDecorative = Font.system(size: 80, weight: .ultraLight)

    /// Icon category — 28pt light (for category card icons)
    static let iconCategory = Font.system(size: 28, weight: .light)

    /// Icon product large — 40pt light (for product card placeholders)
    static let iconProductLarge = Font.system(size: 40, weight: .light)

    /// Icon product medium — 36pt light (for product tile placeholders)
    static let iconProductMedium = Font.system(size: 36, weight: .light)

    /// Icon product small — 24pt light (for product row placeholders)
    static let iconProductSmall = Font.system(size: 24, weight: .light)

    /// Chevron — 12pt medium (for disclosure indicators)
    static let chevron = Font.system(size: 12, weight: .medium)

    /// Small arrow — 8pt (for inline directional indicators)
    static let arrowInline = Font.system(size: 8)

    /// Monospaced ID — 10pt semibold monospaced (for transaction IDs)
    static let monoID = Font.system(size: 10, weight: .semibold, design: .monospaced)

    /// Small semibold — 11pt semibold (for approve buttons, inline actions)
    static let actionSmall = Font.system(size: 11, weight: .semibold)

    /// Small medium — 11pt medium (for reorder buttons, inline links)
    static let actionLink = Font.system(size: 11, weight: .medium)

    /// Revenue small label — 11pt semibold (for percentage labels)
    static let statSmall = Font.system(size: 11, weight: .semibold)

    /// Edit link — 12pt medium (for inline edit links)
    static let editLink = Font.system(size: 12, weight: .medium)

    /// Price compact — 11pt semibold (for price in compact cards)
    static let priceCompact = Font.system(size: 11, weight: .semibold)

    /// Avatar initials small — 11pt semibold
    static let avatarSmall = Font.system(size: 11, weight: .semibold)

    /// Avatar initials medium — 13pt semibold
    static let avatarMedium = Font.system(size: 13, weight: .semibold)

    /// Avatar initials large — 14pt semibold
    static let avatarLarge = Font.system(size: 14, weight: .semibold)

    /// Staff role tag — 10pt semibold (for colored role labels)
    static let roleTag = Font.system(size: 10, weight: .semibold)

    /// Staff status — 10pt medium (for "On Floor", status text)
    static let statusTag = Font.system(size: 10, weight: .medium)

    /// Trend arrow — 12pt bold (for up/down arrows in metrics)
    static let trendArrow = Font.system(size: 12, weight: .bold)

    /// Toolbar icon — 20pt (for plus.circle.fill toolbar buttons)
    static let toolbarIcon = Font.system(size: 20)

    /// Empty state icon — 40pt light
    static let emptyStateIcon = Font.system(size: 40, weight: .light)

    /// Brand diamond — 32pt light (for login screen brand icon)
    static let brandIcon = Font.system(size: 32, weight: .light)

    /// Brand diamond splash — 44pt light (for splash screen brand icon)
    static let brandIconSplash = Font.system(size: 44, weight: .light)

    /// Wishlist heart — 16pt
    static let heartIcon = Font.system(size: 16)

    /// Wishlist heart small — 14pt
    static let heartIconSmall = Font.system(size: 14)

    /// Star rating — 12pt
    static let starRating = Font.system(size: 12)

    /// Category icon in catalog lists — 18pt light
    static let catalogIcon = Font.system(size: 18, weight: .light)

    /// Compact icon — 10pt (for health pills, small indicators)
    static let iconCompact = Font.system(size: 10)

    /// Alert icon — 14pt
    static let alertIcon = Font.system(size: 14)

    /// Small info icon — 12pt (for info hints)
    static let infoIcon = Font.system(size: 12)

    /// Sort icon — 12pt
    static let sortIcon = Font.system(size: 12)

    /// Product image icon in rows — 16pt light
    static let productRowIcon = Font.system(size: 16, weight: .light)

    /// Product image icon in inventory — 14pt
    static let inventoryIcon = Font.system(size: 14)

    /// Top product card icon — 28pt ultraLight
    static let topProductIcon = Font.system(size: 28, weight: .ultraLight)

    /// Category circle icon — 22pt
    static let categoryCircleIcon = Font.system(size: 22)

    /// Close button — 14pt medium
    static let closeButton = Font.system(size: 14, weight: .medium)

    /// Sign out icon — 16pt
    static let signOutIcon = Font.system(size: 16)

    /// Bell icon — 16pt
    static let bellIcon = Font.system(size: 16)

    /// Gear icon — 16pt
    static let gearIcon = Font.system(size: 16)

    /// Profile row icon — 16pt (for settings menu icons)
    static let menuIcon = Font.system(size: 16)

    /// Profile row icon large — 18pt (for customer profile menu)
    static let menuIconLarge = Font.system(size: 18)

    /// Key icon — 28pt light (for forgot password)
    static let keyIcon = Font.system(size: 28, weight: .light)

    /// Organization/Roles icon — 16pt
    static let orgIcon = Font.system(size: 16)

    /// Checkmark permission — 10pt bold
    static let checkmarkSmall = Font.system(size: 10, weight: .bold)

    /// Compliance icon — 14pt
    static let complianceIcon = Font.system(size: 14)

    /// Review button — 11pt semibold
    static let reviewButton = Font.system(size: 11, weight: .semibold)

    /// Low demand badge — 9pt bold
    static let demandBadge = Font.system(size: 9, weight: .bold)

    /// Trend badge — 10pt bold
    static let trendBadge = Font.system(size: 10, weight: .bold)

    /// Store/building icon — 10pt
    static let storeIcon = Font.system(size: 10)
}
