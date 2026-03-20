//
//  TagOrderToEventSheet.swift
//  RSMS
//
//  Manager picks a boutique event to tag to an order in-app (no SQL needed).
//

import SwiftUI

struct TagOrderToEventSheet: View {
    let order: OrderDTO
    let events: [EventDTO]
    let onTagged: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedEventId: UUID? = nil
    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: AppSpacing.md) {
                    // Order info card
                    orderInfoCard

                    // Event picker list
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("SELECT EVENT")
                            .font(AppTypography.overline)
                            .tracking(2)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, AppSpacing.screenHorizontal)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: AppSpacing.sm) {
                                ForEach(events) { event in
                                    eventRow(event)
                                }
                            }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }
                    }

                    Spacer()

                    // Confirm button
                    Button {
                        Task { await tag() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                        } else {
                            Text("Tag to Event")
                                .font(AppTypography.label)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                        }
                    }
                    .background(selectedEventId != nil ? AppColors.accent : AppColors.neutral500)
                    .cornerRadius(AppSpacing.radiusMedium)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .disabled(selectedEventId == nil || isSubmitting)
                    .padding(.bottom, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.md)
            }
            .navigationTitle("Tag Order to Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Order Info Card

    private var orderInfoCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(order.orderNumber ?? order.id.uuidString.prefix(8).description)
                    .font(AppTypography.monoID)
                    .foregroundColor(AppColors.accent)
                Spacer()
                Text(order.formattedTotal)
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            HStack {
                Label(order.channel.replacingOccurrences(of: "_", with: " ").capitalized,
                      systemImage: "bag")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.neutral500)
            }
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Event Row

    private func eventRow(_ event: EventDTO) -> some View {
        let isSelected = selectedEventId == event.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedEventId = isSelected ? nil : event.id
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.neutral500)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.eventName)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    HStack(spacing: 8) {
                        Text(event.eventType)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                        Text("·")
                            .foregroundColor(AppColors.neutral500)
                        Text(event.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.neutral500)
                    }
                }
                Spacer()

                // Status badge
                let sc: Color = event.status == "Confirmed" || event.status == "In Progress"
                    ? AppColors.success : AppColors.warning
                Text(event.status.uppercased())
                    .font(AppTypography.nano)
                    .foregroundColor(sc)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(sc.opacity(0.12)).cornerRadius(4)
            }
            .padding(AppSpacing.sm)
            .background(isSelected ? AppColors.accent.opacity(0.07) : AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(isSelected ? AppColors.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
    }

    // MARK: - Action

    private func tag() async {
        guard let eventId = selectedEventId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await EventSalesService.shared.tagOrder(orderId: order.id, eventId: eventId)
            onTagged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
