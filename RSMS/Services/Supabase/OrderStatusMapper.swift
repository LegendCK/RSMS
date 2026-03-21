import Foundation

enum OrderStatusMapper {
    static func canonical(_ rawStatus: String) -> String {
        switch rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "new", "pending":
            return "pending"
        case "confirmed":
            return "confirmed"
        case "in_progress", "in progress", "in-progress", "processing", "picking", "packing", "picked", "packed", "fulfillment_started":
            return "processing"
        case "ready_for_pickup", "ready for pickup", "ready-for-pickup", "ready_for_collection", "ready":
            return "ready_for_pickup"
        case "shipped", "dispatched", "in_transit", "in transit", "out_for_delivery", "out for delivery":
            return "shipped"
        case "delivered":
            return "delivered"
        case "completed", "closed":
            return "completed"
        case "cancelled", "canceled":
            return "cancelled"
        default:
            return rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    static func writeCandidates(for targetStatus: String) -> [String] {
        // Return only the single canonical value that the DB constraint accepts.
        // The constraint allows: pending, new, confirmed, processing,
        //   ready_for_pickup, shipped, delivered, completed, cancelled, canceled
        switch canonical(targetStatus) {
        case "pending":         return ["pending"]
        case "confirmed":       return ["confirmed"]
        case "processing":      return ["processing"]
        case "ready_for_pickup": return ["ready_for_pickup"]
        case "shipped":         return ["shipped"]
        case "delivered":       return ["delivered"]
        case "completed":       return ["completed"]
        case "cancelled":       return ["cancelled"]
        default:
            return [targetStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
        }
    }
}
