//
//  MaisonLuxeLogo.swift
//  RSMS
//
//  Native vectorized representation of the Maison Luxe logo.
//  Scales perfectly, zero white background issues, perfectly transparent bounds.
//

import SwiftUI

struct MaisonLuxeLogo: View {
    var size: CGFloat = 80
    
    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MaisonLuxeLogo(size: 100)
    }
}
