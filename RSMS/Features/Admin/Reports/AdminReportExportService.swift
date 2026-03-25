//
//  AdminReportExportService.swift
//  infosys2
//
//  Service for generating and exporting admin reports in various formats
//  (PDF, CSV, Numbers) based on AdminInsightsSnapshot data.
//

import Foundation
import PDFKit

enum AdminReportExportService {
    
    /// Exports a report based on scope, format, and snapshot data
    /// - Parameters:
    ///   - scope: The scope of the report (all stores, single store, regional)
    ///   - format: The desired export format (PDF, CSV, Numbers)
    ///   - snapshot: The data snapshot containing all relevant business data
    ///   - generatedBy: Name of the user generating the report
    /// - Returns: URL to the generated file
    static func export(
        scope: AdminReportScope,
        format: AdminReportFormat,
        snapshot: AdminInsightsSnapshot,
        generatedBy: String
    ) throws -> URL {
        switch format {
        case .pdf:
            return try exportPDF(scope: scope, snapshot: snapshot, generatedBy: generatedBy)
        case .csv:
            return try exportCSV(scope: scope, snapshot: snapshot, generatedBy: generatedBy)
        case .numbers:
            return try exportNumbers(scope: scope, snapshot: snapshot, generatedBy: generatedBy)
        }
    }
    
    // MARK: - PDF Export
    
    private static func exportPDF(
        scope: AdminReportScope,
        snapshot: AdminInsightsSnapshot,
        generatedBy: String
    ) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "RSMS - Retail Store Management System",
            kCGPDFContextAuthor: generatedBy,
            kCGPDFContextTitle: "Admin Report - \(scope.rawValue)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            let leftMargin: CGFloat = 50
            let rightMargin: CGFloat = 562
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let title = "Admin Report - \(scope.rawValue)"
            title.draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Metadata
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            
            let metadata = """
            Generated: \(dateFormatter.string(from: snapshot.syncedAt))
            By: \(generatedBy)
            Scope: \(scope.rawValue)
            """
            metadata.draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: metaAttributes)
            yPosition += 50
            
            // Section: Summary
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            "SUMMARY".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: sectionAttributes)
            yPosition += 25
            
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let totalRevenue = snapshot.orders.reduce(0.0) { $0 + $1.grandTotal }
            let totalOrders = snapshot.orders.count
            let totalProducts = snapshot.products.count
            let activeStores = snapshot.stores.filter { $0.isActive }.count
            let onlineRevenue = snapshot.orders
                .filter { $0.channel.lowercased() != "in_store" }
                .reduce(0.0) { $0 + $1.grandTotal }
            let inStoreRevenue = snapshot.orders
                .filter { $0.channel.lowercased() == "in_store" }
                .reduce(0.0) { $0 + $1.grandTotal }
            
            let summary = """
            Total Revenue: $\(String(format: "%.2f", totalRevenue))
            Total Orders: \(totalOrders)
            Active Stores: \(activeStores)
            Total Products: \(totalProducts)
            Total Clients: \(snapshot.clients.count)
            Active Reservations: \(snapshot.reservations.count)
            Service Tickets: \(snapshot.serviceTickets.count)
            Online / Omnichannel Revenue: $\(String(format: "%.2f", onlineRevenue))
            In-Store Revenue: $\(String(format: "%.2f", inStoreRevenue))
            """
            
            summary.draw(
                in: CGRect(x: leftMargin, y: yPosition, width: rightMargin - leftMargin, height: 200),
                withAttributes: bodyAttributes
            )
            yPosition += 120
            
            // Section: Top Products
            "TOP PRODUCTS".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: sectionAttributes)
            yPosition += 25
            
            let productSales = calculateProductSales(snapshot: snapshot)
            let topProducts = productSales.prefix(5)
            
            for (index, item) in topProducts.enumerated() {
                let productLine = "\(index + 1). \(item.name) - Revenue: $\(String(format: "%.2f", item.revenue)) (\(item.quantity) units)"
                productLine.draw(at: CGPoint(x: leftMargin + 10, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 20
            }
            
            yPosition += 20
            
            // Section: Store Performance
            if yPosition > 650 {
                context.beginPage()
                yPosition = 50
            }
            
            "STORE PERFORMANCE".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: sectionAttributes)
            yPosition += 25
            
            let storePerformance = calculateStorePerformance(snapshot: snapshot)
            
            for store in storePerformance.prefix(10) {
                if yPosition > 720 {
                    context.beginPage()
                    yPosition = 50
                }
                let storeLine = "\(store.name): $\(String(format: "%.2f", store.revenue)) (\(store.orderCount) orders)"
                storeLine.draw(at: CGPoint(x: leftMargin + 10, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 20
            }
        }
        
        let fileName = "AdminReport_\(scope.rawValue.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    // MARK: - CSV Export
    
    private static func exportCSV(
        scope: AdminReportScope,
        snapshot: AdminInsightsSnapshot,
        generatedBy: String
    ) throws -> URL {
        var csvText = "Admin Report - \(scope.rawValue)\n"
        csvText += "Generated: \(ISO8601DateFormatter().string(from: snapshot.syncedAt))\n"
        csvText += "By: \(generatedBy)\n\n"
        
        // Orders Section
        csvText += "ORDERS\n"
        csvText += "Order Number,Client ID,Store ID,Channel,Status,Grand Total,Currency,Created At\n"
        
        for order in snapshot.orders {
            let orderNumber = order.orderNumber ?? "N/A"
            let clientId = order.clientId?.uuidString ?? "Guest"
            let storeId = order.storeId.uuidString
            let createdAt = ISO8601DateFormatter().string(from: order.createdAt)
            
            csvText += "\(csvEscape(orderNumber)),\(csvEscape(clientId)),\(csvEscape(storeId)),\(csvEscape(order.channel)),\(csvEscape(order.status)),\(order.grandTotal),\(csvEscape(order.currency)),\(csvEscape(createdAt))\n"
        }
        
        csvText += "\n"
        
        // Product Sales
        csvText += "PRODUCT SALES\n"
        csvText += "Rank,Product Name,Category,Total Revenue,Total Quantity,Average Price\n"
        
        let productSales = calculateProductSales(snapshot: snapshot)
        for (index, item) in productSales.enumerated() {
            let avgPrice = item.quantity > 0 ? item.revenue / Double(item.quantity) : 0
            csvText += "\(index + 1),\(csvEscape(item.name)),\(csvEscape(item.category)),\(item.revenue),\(item.quantity),\(avgPrice)\n"
        }
        
        csvText += "\n"
        
        // Store Performance
        csvText += "STORE PERFORMANCE\n"
        csvText += "Store Name,City,Country,Total Revenue,Order Count,Active\n"
        
        let storePerformance = calculateStorePerformance(snapshot: snapshot)
        for store in storePerformance {
            csvText += "\(csvEscape(store.name)),\(csvEscape(store.city)),\(csvEscape(store.country)),\(store.revenue),\(store.orderCount),\(store.isActive)\n"
        }

        csvText += "\n"

        csvText += "CHANNEL COMPARISON\n"
        csvText += "Channel,Order Count,Revenue\n"
        for item in calculateChannelPerformance(snapshot: snapshot) {
            csvText += "\(csvEscape(item.name)),\(item.orderCount),\(item.revenue)\n"
        }

        csvText += "\n"

        csvText += "RESERVATIONS\n"
        csvText += "Reservation ID,Client ID,Product ID,Store ID,Status,Expires At,Created At\n"
        for reservation in snapshot.reservations {
            csvText += "\(reservation.id.uuidString),\(reservation.clientId.uuidString),\(reservation.productId.uuidString),\(reservation.storeId?.uuidString ?? "N/A"),\(csvEscape(reservation.status)),\(ISO8601DateFormatter().string(from: reservation.expiresAt)),\(ISO8601DateFormatter().string(from: reservation.createdAt))\n"
        }
        
        let fileName = "AdminReport_\(scope.rawValue.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    // MARK: - Numbers Export (CSV variant for Numbers)
    
    private static func exportNumbers(
        scope: AdminReportScope,
        snapshot: AdminInsightsSnapshot,
        generatedBy: String
    ) throws -> URL {
        // For Numbers format, we'll create a CSV that Numbers can open nicely
        // In a production app, you might use a library to generate actual .numbers files
        let csvURL = try exportCSV(scope: scope, snapshot: snapshot, generatedBy: generatedBy)
        
        // Rename to indicate it's optimized for Numbers
        let numbersFileName = csvURL.lastPathComponent.replacingOccurrences(of: ".csv", with: "_Numbers.csv")
        let numbersURL = FileManager.default.temporaryDirectory.appendingPathComponent(numbersFileName)
        
        if FileManager.default.fileExists(atPath: numbersURL.path) {
            try FileManager.default.removeItem(at: numbersURL)
        }
        
        try FileManager.default.copyItem(at: csvURL, to: numbersURL)
        try FileManager.default.removeItem(at: csvURL)
        
        return numbersURL
    }
    
    // MARK: - Helper Methods
    
    private static func csvEscape(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
    
    private static func calculateProductSales(snapshot: AdminInsightsSnapshot) -> [(name: String, category: String, revenue: Double, quantity: Int)] {
        var productMap: [UUID: (name: String, category: String, revenue: Double, quantity: Int)] = [:]
        
        // Build product lookup
        let productsById = Dictionary(uniqueKeysWithValues: snapshot.products.map { ($0.id, $0) })
        
        // Aggregate sales from order items
        for item in snapshot.orderItems {
            let product = productsById[item.productId]
            let existing = productMap[item.productId] ?? (
                name: product?.name ?? "Unknown Product",
                category: product?.categoryId?.uuidString ?? "Uncategorized",
                revenue: 0,
                quantity: 0
            )
            
            productMap[item.productId] = (
                name: existing.name,
                category: existing.category,
                revenue: existing.revenue + item.lineTotal,
                quantity: existing.quantity + item.quantity
            )
        }
        
        return productMap.values.sorted { $0.revenue > $1.revenue }
    }
    
    private static func calculateStorePerformance(snapshot: AdminInsightsSnapshot) -> [(name: String, city: String, country: String, revenue: Double, orderCount: Int, isActive: Bool)] {
        var storeMap: [UUID: (revenue: Double, orderCount: Int)] = [:]
        
        // Aggregate orders by store
        for order in snapshot.orders {
            let existing = storeMap[order.storeId] ?? (revenue: 0, orderCount: 0)
            storeMap[order.storeId] = (
                revenue: existing.revenue + order.grandTotal,
                orderCount: existing.orderCount + 1
            )
        }
        
        // Join with store information
        return snapshot.stores.map { store in
            let performance = storeMap[store.id] ?? (revenue: 0, orderCount: 0)
            return (
                name: store.name,
                city: store.city ?? "Unknown",
                country: store.country,
                revenue: performance.revenue,
                orderCount: performance.orderCount,
                isActive: store.isActive
            )
        }.sorted { $0.revenue > $1.revenue }
    }

    private static func calculateChannelPerformance(snapshot: AdminInsightsSnapshot) -> [(name: String, orderCount: Int, revenue: Double)] {
        let grouped = Dictionary(grouping: snapshot.orders) { order in
            switch order.channel.lowercased() {
            case "in_store": return "In-Store"
            case "online": return "Online Delivery"
            case "bopis": return "BOPIS"
            case "ship_from_store": return "Ship From Store"
            default: return order.channel.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }

        return grouped.map { key, orders in
            (name: key, orderCount: orders.count, revenue: orders.reduce(0.0) { $0 + $1.grandTotal })
        }
        .sorted { $0.revenue > $1.revenue }
    }

    static func exportChannelComparisonCSV(
        snapshot: AdminInsightsSnapshot,
        generatedBy: String
    ) throws -> URL {
        let iso = ISO8601DateFormatter()
        let onlineOrders = snapshot.orders.filter { $0.channel.lowercased() != "in_store" }
        let inStoreOrders = snapshot.orders.filter { $0.channel.lowercased() == "in_store" }
        let onlineRevenue = onlineOrders.reduce(0.0) { $0 + $1.grandTotal }
        let inStoreRevenue = inStoreOrders.reduce(0.0) { $0 + $1.grandTotal }
        let returnsCount = snapshot.serviceTickets.filter { ticket in
            let type = ticket.type.lowercased()
            let notes = ticket.notes?.lowercased() ?? ""
            return type == "warranty_claim" || notes.contains("exchange") || notes.contains("return")
        }.count

        var csvText = "Client Activity Channel Report\n"
        csvText += "Generated: \(iso.string(from: snapshot.syncedAt))\n"
        csvText += "By: \(generatedBy)\n\n"
        csvText += "SUMMARY\n"
        csvText += "Metric,Value\n"
        csvText += "Online / Omnichannel Orders,\(onlineOrders.count)\n"
        csvText += "Online / Omnichannel Revenue,\(onlineRevenue)\n"
        csvText += "In-Store Orders,\(inStoreOrders.count)\n"
        csvText += "In-Store Revenue,\(inStoreRevenue)\n"
        csvText += "Reservations,\(snapshot.reservations.count)\n"
        csvText += "Returns / Exchange Tickets,\(returnsCount)\n\n"
        csvText += "CHANNEL PERFORMANCE\n"
        csvText += "Channel,Order Count,Revenue\n"

        for item in calculateChannelPerformance(snapshot: snapshot) {
            csvText += "\(csvEscape(item.name)),\(item.orderCount),\(item.revenue)\n"
        }

        csvText += "\nPORTAL ORDERS\n"
        csvText += "Order Number,Channel,Status,Store ID,Client ID,Grand Total,Currency,Created At\n"
        for order in onlineOrders {
            csvText += "\(csvEscape(order.orderNumber ?? "N/A")),\(csvEscape(order.channel)),\(csvEscape(order.status)),\(order.storeId.uuidString),\(order.clientId?.uuidString ?? "Guest"),\(order.grandTotal),\(csvEscape(order.currency)),\(iso.string(from: order.createdAt))\n"
        }

        let fileName = "ClientActivity_ChannelReport_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
