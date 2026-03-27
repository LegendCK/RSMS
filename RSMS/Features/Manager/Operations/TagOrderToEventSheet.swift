import SwiftUI

struct TagOrderToEventSheet: View {
    let order: OrderDTO
    let events: [EventDTO]
    let onTagged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(events) { event in
                Button {
                    Task { await tagOrder(to: event) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.eventName)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text(event.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        Spacer()
                        if isSubmitting {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isSubmitting)
            }
            .navigationTitle("Tag Order to Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Tagging Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unable to tag order.")
            }
        }
    }

    private func tagOrder(to event: EventDTO) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await EventSalesService.shared.tagOrder(orderId: order.id, eventId: event.id)
            onTagged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
