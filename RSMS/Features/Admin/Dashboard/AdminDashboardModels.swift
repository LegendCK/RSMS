import Foundation
import SwiftData

enum AdminReportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case csv = "CSV"
    case numbers = "Numbers"
    var id: String { rawValue }
}

enum AdminReportScope: String, CaseIterable, Identifiable {
    case all = "All Stores"
    case singleStore = "Single Store"
    case regional = "Regional"
    var id: String { rawValue }
}

struct AdminInsightsSnapshot {
    var stores: [StoreDTO]
    var orders: [OrderDTO]
    var orderItems: [OrderItemDTO]
    var inventory: [InventoryDTO]
    var users: [UserDTO]
    var appointments: [AppointmentDTO]
    var clients: [ClientDTO]
    var serviceTickets: [ServiceTicketDTO]
    var syncedAt: Date
}
