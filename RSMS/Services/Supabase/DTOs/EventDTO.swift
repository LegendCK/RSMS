import Foundation

struct EventDTO: Identifiable, Codable {
    var id: UUID
    var storeId: String?
    var eventName: String
    var eventType: String
    var description: String?
    var scheduledDate: Date
    var capacity: Int
    var status: String // "Confirmed", "In Progress", "Cancelled", "Scheduled"
    var relatedCategory: String
    var createdBy: UUID?
    var createdAt: Date
}
