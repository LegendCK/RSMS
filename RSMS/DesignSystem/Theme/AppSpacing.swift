//
//  AppSpacing.swift
//  infosys2
//
//  4-point grid spacing system following Apple HIG principles.
//

import SwiftUI

struct AppSpacing {

    // MARK: - Base Grid (4pt)

    /// 4pt — minimal spacing
    static let xxs: CGFloat = 4

    /// 8pt — tight spacing
    static let xs: CGFloat = 8

    /// 12pt — compact spacing
    static let sm: CGFloat = 12

    /// 16pt — standard spacing (iOS default)
    static let md: CGFloat = 16

    /// 20pt — comfortable spacing
    static let lg: CGFloat = 20

    /// 24pt — generous spacing
    static let xl: CGFloat = 24

    /// 32pt — section spacing
    static let xxl: CGFloat = 32

    /// 40pt — large section spacing
    static let xxxl: CGFloat = 40

    /// 48pt — hero spacing
    static let hero: CGFloat = 48

    // MARK: - Layout

    /// Standard horizontal padding for screen content
    static let screenHorizontal: CGFloat = 20

    /// Standard vertical padding for screen content
    static let screenVertical: CGFloat = 16

    /// Card internal padding
    static let cardPadding: CGFloat = 16

    /// Minimum touch target size (Apple HIG: 44pt)
    static let touchTarget: CGFloat = 44

    // MARK: - Corner Radius

    /// Small radius — tags, badges
    static let radiusSmall: CGFloat = 6

    /// Medium radius — buttons, inputs
    static let radiusMedium: CGFloat = 12

    /// Large radius — cards, sheets
    static let radiusLarge: CGFloat = 16

    /// Extra large radius — modals
    static let radiusXL: CGFloat = 24
}
