//
//  SACatalogView.swift
//  RSMS
//
//  Sales Associate catalog view — viewing products.
//

import SwiftUI

struct SACatalogView: View {
    var body: some View {
        NavigationStack {
            CatalogProductsSubview()
                .navigationTitle("Catalog")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SACatalogView()
}
