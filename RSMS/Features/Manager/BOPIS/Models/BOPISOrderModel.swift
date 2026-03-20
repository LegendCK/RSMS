//
//  BOPISOrderModel.swift
//  RSMS
//
//  Data model for BOPIS and Ship-from-Store orders monitored by Boutique Managers.
//  Includes SLA deadline computation and offline-cache persistence via UserDefaults.
//

import Foundation

// MARK: - Fulfillment Channel

enum BOPISChannel: String, Codable, CaseIterable {
    case bopis          = "bopis"
    case shipFromStore  = "ship_from_store"

    var displayName: String {
        switch self {
        case .bopis:         return "Pick-Up In Store"
        case .shipFromStore: return "Ship From Store"
        }
    }

    var systemIcon: String {
        switch self {
        case .bopis:         return "bag.fill"
        case .shipFromStore: return "shippingbox.fill"
        }
    }

    /// SLA window in hours from order placement
    var slaHours: Double {
        switch self {
        case .bopis:         return 4   // 4-hour ready-for-pickup SLA
        case .shipFromStore: return 24  // 24-hour ship-out SLA
        }
    }
}

// MARK: - SLA Status

enum SLAStatus: String, Codable {
    case onTime    = "on_time"
    case atRisk    = "at_risk"      // < 1 hour remaining
    case breached  = "breached"     // deadline passed, not yet completed

    var label: String {
        switch self {
        case .onTime:   return "On Time"
        case .atRisk:   return "At Risk"
        case .breached: return "Overdue"
        }
    }
}

// MARK: - BOPISOrder

struct BOPISOrder: Identifiable, Codable, Equatable {
    let id: UUID
    let orderNumber: String
    let channel: BOPISChannel
    let status: String          // mirrors OrderDTO.status
    let clientEmail: String
    let grandTotal: Double
    let currency: String
    let placedAt: Date
    let pickupDeadline: Date    // placedAt + channel.slaHours

    // MARK: - Computed

    var slaStatus: SLAStatus {
        guard !isTerminal else { return .onTime }
        let remaining = pickupDeadline.timeIntervalSinceNow
        if remaining <= 0       { return .breached }
        if remaining <= 3600    { return .atRisk }
        return .onTime
    }

    var isTerminal: Bool {
        ["completed", "cancelled", "delivered"].contains(status.lowercased())
    }

    var timeRemainingLabel: String {
        if isTerminal { return status.capitalized }
        let remaining = pickupDeadline.timeIntervalSinceNow
        if remaining <= 0 {
            let overdue = abs(remaining)
            return "Overdue \(formatDuration(overdue))"
        }
        return "\(formatDuration(remaining)) left"
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: grandTotal)) ?? "\(currency) \(grandTotal)"
    }

    var formattedDeadline: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let dateStr = RelativeDateTimeFormatter().localizedString(for: pickupDeadline, relativeTo: Date())
        return "\(formatter.string(from: pickupDeadline)) (\(dateStr))"
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Factory from OrderDTO

    static func from(dto: _BOPISOrderDTO) -> BOPISOrder? {
        guard let channel = BOPISChannel(rawValue: dto.channel) else { return nil }
        let placed = dto.createdAt
        let deadline = placed.addingTimeInterval(channel.slaHours * 3600)
        return BOPISOrder(
            id: dto.id,
            orderNumber: dto.orderNumber ?? "#\(dto.id.uuidString.prefix(8).uppercased())",
            channel: channel,
            status: dto.status,
            clientEmail: dto.clientEmail ?? "—",
            grandTotal: dto.grandTotal,
            currency: dto.currency,
            placedAt: placed,
            pickupDeadline: deadline
        )
    }
}

// MARK: - Lightweight DTO used internally for decoding

struct _BOPISOrderDTO: Codable {
    let id: UUID
    let orderNumber: String?
    let channel: String
    let status: String
    let clientEmail: String?
    let grandTotal: Double
    let currency: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber  = "order_number"
        case channel, status
        case clientEmail  = "client_email"
        case grandTotal   = "grand_total"
        case currency
        case createdAt    = "created_at"
    }
}

// MARK: - Offline Cache

struct BOPISOrderCache {
    private static let key = "rsms_bopis_order_cache_v1"

    static func save(_ orders: [BOPISOrder]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(orders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [BOPISOrder] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([BOPISOrder].self, from: data)) ?? []
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
