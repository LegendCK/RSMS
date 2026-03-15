//
//  CartShortcutButton.swift
//  RSMS
//
//  Reusable cart shortcut with live badge count.
//

import SwiftUI
import SwiftData

struct CartShortcutButton: View {
    @Environment(AppState.self) private var appState
    @Query private var allCartItems: [CartItem]

    private var itemCount: Int {
        allCartItems
            .filter { $0.customerEmail == appState.currentUserEmail }
            .reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        NavigationLink(destination: CartView()) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bag")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimaryDark)

                if itemCount > 0 {
                    Text("\(min(itemCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.accent, in: Capsule())
                        .offset(x: 10, y: -10)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

