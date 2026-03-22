//
//  CSVProductRow.swift
//  RSMS
//

import Foundation

struct CSVProductRow: Identifiable {
    let id = UUID()
    
    // Raw parsed fields
    var name: String
    var sku: String
    var priceStr: String
    var brand: String
    var description: String
    
    // Validation State
    var isValid: Bool = true
    var validationErrors: [String] = []
    
    // Normalized Final Values (Only populated if price parsed successfully)
    var parsedPrice: Double = 0.0
}
