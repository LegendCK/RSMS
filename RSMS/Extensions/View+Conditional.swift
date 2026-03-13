//
//  View+Conditional.swift
//  RSMS
//
//  Conditional view modifier helper for cleaner syntax.
//

import SwiftUI

extension View {
    /// Apply a modifier conditionally based on a boolean value.
    /// Enables cleaner syntax than ternary operators for type-varying modifiers.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
