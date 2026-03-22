import SwiftUI

struct TagOrderToEventSheet: View {
    let order: OrderDTO
    let events: [EventDTO]
    let onTagged: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(events) { event in
                Button(event.eventName) {
                    onTagged()
                    dismiss()
                }
            }
            .navigationTitle("Tag Order to Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
