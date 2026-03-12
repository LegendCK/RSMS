//
//  GoldDivider.swift
//  infosys2
//
//  Thin champagne gold separator line.
//

import SwiftUI

struct GoldDivider: View {
    var opacity: Double = 0.3

    var body: some View {
        Rectangle()
            .fill(AppColors.accent.opacity(opacity))
            .frame(height: 1)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 20) {
            Text("Above").foregroundColor(.white)
            GoldDivider()
            Text("Below").foregroundColor(.white)
        }
        .padding()
    }
}
