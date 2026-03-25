import Foundation
import SwiftData


struct AdminInsightsSnapshot {
    var stores: [StoreDTO]
    var orders: [OrderDTO]
    var orderItems: [OrderItemDTO]
    var reservations: [ReservationDTO]
    var inventory: [InventoryDTO]
    var users: [UserDTO]
    var appointments: [AppointmentDTO]
    var clients: [ClientDTO]
    var serviceTickets: [ServiceTicketDTO]
    var products: [ProductDTO]
    var syncedAt: Date
}
