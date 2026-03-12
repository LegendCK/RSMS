//
//  Category.swift
//  infosys2
//
//  SwiftData model for product categories.
//

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var categoryDescription: String
    var displayOrder: Int
    var productTypes: String   // JSON array of sub-type names, e.g. ["Engagement Rings","Wedding Bands",...]

    init(
        name: String,
        icon: String,
        description: String,
        displayOrder: Int = 0,
        productTypes: String = "[]"
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.categoryDescription = description
        self.displayOrder = displayOrder
        self.productTypes = productTypes
    }

    /// Parses the `productTypes` JSON string into a String array.
    var parsedProductTypes: [String] {
        guard let data = productTypes.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return [] }
        return array
    }
}
