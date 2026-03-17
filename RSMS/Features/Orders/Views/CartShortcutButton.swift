//
//  CartShortcutButton.swift
//  RSMS
//
//  Reusable cart shortcut with live numeric badge count.
//  Badge stays fully within the button frame — no clipping by iOS 26 automatic toolbar pill.
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
                // Bag icon — NO top padding so it stays vertically centred with
                // the adjacent bell icon in the toolbar HStack.
                // Trailing padding carves out space for the badge on the right.
                Image(systemName: "bag")
                    .font(.system(size: 17, weight: .light))
                    .foregroundColor(.primary)
                    .padding(.trailing, 10)   // room for badge; zero vertical shift

                // Numeric badge — sits at the top-trailing corner of the ZStack,
                // entirely within the frame so iOS 26's pill container cannot clip it.
                if itemCount > 0 {
                    Text("\(min(itemCount, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(AppColors.accent, in: Capsule())
                        .fixedSize()
                }
            }
        }
        .buttonStyle(.plain)
    }
}
