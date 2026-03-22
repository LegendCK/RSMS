import SwiftUI

struct EventSalesReportView: View {
    let event: EventDTO
    var body: some View {
        Text("Sales Report for \(event.eventName)")
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.textSecondaryDark)
    }
}
