import SwiftUI

struct CreateEventSheet: View {
    let onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Create Event Form")
                .navigationTitle("New Event")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            onCreated()
                            dismiss()
                        }
                    }
                }
        }
    }
}
