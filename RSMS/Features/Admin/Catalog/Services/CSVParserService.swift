//
//  CSVParserService.swift
//  RSMS
//

import Foundation

final class CSVParserService {
    
    /// Parses a CSV string into a list of `CSVProductRow` objects, validating each row.
    /// Expected format: name,sku,price,brand,description
    static func parseCSV(url: URL) throws -> [CSVProductRow] {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "CSVParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied to access the file."])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseString(content)
    }
    
    static func parseString(_ content: String) -> [CSVProductRow] {
        var rows: [CSVProductRow] = []
        var seenSKUs = Set<String>()
        
        // Handle potentially different line endings
        let lines = content.components(separatedBy: .newlines)
        
        // Skip header if it exists. A heuristic logic is to check if the first row has "name" and "sku"
        var startIndex = 0
        if let firstLine = lines.first?.lowercased(), firstLine.contains("name") && firstLine.contains("sku") {
            startIndex = 1
        }
        
        for i in startIndex..<lines.count {
            let line = lines[i]
            
            // Skip completely empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let fields = parseCSVLine(line)
            
            // Expected: name, sku, price, brand, description
            // At least 3 fields are needed: name, sku, price
            var row = CSVProductRow(
                name: (fields.count > 0 ? fields[0] : "").trimmingCharacters(in: .whitespaces),
                sku: (fields.count > 1 ? fields[1] : "").trimmingCharacters(in: .whitespaces),
                priceStr: (fields.count > 2 ? fields[2] : "").trimmingCharacters(in: .whitespaces),
                brand: (fields.count > 3 ? fields[3] : "").trimmingCharacters(in: .whitespaces),
                description: (fields.count > 4 ? fields[4] : "").trimmingCharacters(in: .whitespaces)
            )
            
            // --- VALIDATION ---
            
            // 1. Name is required
            if row.name.isEmpty {
                row.isValid = false
                row.validationErrors.append("Name is required.")
            }
            
            // 2. SKU is required and must be unique in this file
            if row.sku.isEmpty {
                row.isValid = false
                row.validationErrors.append("SKU is required.")
            } else if seenSKUs.contains(row.sku) {
                row.isValid = false
                row.validationErrors.append("Duplicate SKU within this CSV.")
            } else {
                seenSKUs.insert(row.sku)
            }
            
            // 3. Price Validation
            if row.priceStr.isEmpty {
                row.isValid = false
                row.validationErrors.append("Price is required.")
            } else {
                // Normalize price: remove currency symbols and commas
                var normalizedPrice = row.priceStr
                normalizedPrice = normalizedPrice.replacingOccurrences(of: "$", with: "")
                normalizedPrice = normalizedPrice.replacingOccurrences(of: "€", with: "")
                normalizedPrice = normalizedPrice.replacingOccurrences(of: "£", with: "")
                normalizedPrice = normalizedPrice.replacingOccurrences(of: ",", with: "")
                normalizedPrice = normalizedPrice.trimmingCharacters(in: .whitespaces)
                
                if let price = Double(normalizedPrice), price >= 0 {
                    row.parsedPrice = price
                } else {
                    row.isValid = false
                    row.validationErrors.append("Invalid price format.")
                }
            }
            
            rows.append(row)
        }
        
        return rows
    }
    
    /// Parses a single line properly splitting on commas, ignoring commas inside double quotes.
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        result.append(currentField)
        
        // Cleanup surrounding quotes for each field
        return result.map { field in
            if field.hasPrefix("\"") && field.hasSuffix("\"") && field.count >= 2 {
                let start = field.index(field.startIndex, offsetBy: 1)
                let end = field.index(field.endIndex, offsetBy: -1)
                return String(field[start..<end]).replacingOccurrences(of: "\"\"", with: "\"")
            }
            return field
        }
    }
    
    /// Generates a valid sample CSV String templates.
    static func generateTemplate() -> String {
        return """
        name,sku,price,brand,description
        "Soleil Eternity Ring",ML-JEW-ER-001,12800.00,"Maison Luxe","Brilliant-cut diamond eternity ring."
        "Heritage Wedding Band",ML-JEW-WB-002,3200.00,"Maison Luxe","Classic platinum wedding band."
        """
    }
}
