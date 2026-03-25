//
//  TicketPickupView.swift
//  RSMS
//
//  Pickup scheduling and handover sheet for a completed service ticket.
//  Presented as a sheet from ServiceTicketDetailView.
//

import SwiftUI

@MainActor
struct TicketPickupView: View {
    @State var vm: TicketPickupViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    if vm.isLoading {
                        ProgressView("Loading pickup info…")
                            .padding(.top, AppSpacing.xl)
                    } else {
                        pickupStatusCard
                        scheduleCard
                        handoverNotesCard
                        actionsCard
                        documentCard

                        if let msg = vm.successMessage { successBanner(msg) }
                        if let err = vm.errorMessage   { errorBanner(err) }
                    }

                    Spacer(minLength: AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Pickup & Handover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(AppTypography.buttonSecondary)
                }
            }
            .task { await vm.loadPickup() }
            .sheet(isPresented: $vm.showShareSheet) {
                if let url = vm.generatedDocumentURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Confirm Handover", isPresented: $vm.showHandoverConfirm) {
                Button("Confirm", role: .destructive) {
                    Task { await vm.confirmHandover() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the product as handed over to the client. This action cannot be undone.")
            }
        }
    }

    // MARK: - Pickup status card

    private var pickupStatusCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PICKUP STATUS")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

            HStack(spacing: AppSpacing.sm) {
                let status = vm.pickup?.pickupStatus ?? .pending
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(status.displayName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(.primary)

                    if let sched = vm.pickup?.scheduledAt {
                        Text("Scheduled: \(sched.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    if let handedAt = vm.pickup?.handedOverAt {
                        Text("Handed over: \(handedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.success)
                    }
                }
                Spacer()
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    // MARK: - Schedule card

    @ViewBuilder
    private var scheduleCard: some View {
        if !vm.isHandedOver {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("SCHEDULE PICKUP")
                    .font(AppTypography.overline)
                    .tracking(1.8)
                    .foregroundColor(.secondary)

                DatePicker(
                    "Pickup Date & Time",
                    selection: $vm.scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .font(AppTypography.bodySmall)
                .tint(AppColors.accent)
                .disabled(vm.isHandedOver)

                Button {
                    Task { await vm.schedulePickup() }
                } label: {
                    actionButtonLabel(
                        title: vm.isSaving ? "Saving…" : "Confirm Schedule",
                        icon: "calendar.badge.checkmark",
                        loading: vm.isSaving
                    )
                }
                .buttonStyle(FilledActionButtonStyle(enabled: vm.canSchedule))
                .disabled(!vm.canSchedule)
            }
            .padding(AppSpacing.cardPadding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    // MARK: - Handover notes card

    @ViewBuilder
    private var handoverNotesCard: some View {
        if !vm.isHandedOver {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("HANDOVER NOTES")
                    .font(AppTypography.overline)
                    .tracking(1.8)
                    .foregroundColor(.secondary)

                TextField("e.g. Dust bag included, authenticity card returned", text: $vm.handoverNotes, axis: .vertical)
                    .lineLimit(3...5)
                    .font(AppTypography.bodySmall)
                    .padding(AppSpacing.sm)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                    .disabled(vm.isHandedOver)
            }
            .padding(AppSpacing.cardPadding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    // MARK: - Actions card

    @ViewBuilder
    private var actionsCard: some View {
        if !vm.isHandedOver {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("ACTIONS")
                    .font(AppTypography.overline)
                    .tracking(1.8)
                    .foregroundColor(.secondary)

                // Mark ready
                Button {
                    Task { await vm.markReadyForPickup() }
                } label: {
                    actionButtonLabel(
                        title: vm.isSaving ? "Updating…" : "Mark Ready for Pickup",
                        icon: "shippingbox.fill",
                        loading: vm.isSaving
                    )
                }
                .buttonStyle(FilledActionButtonStyle(enabled: vm.canMarkReady))
                .disabled(!vm.canMarkReady)

                // Confirm handover
                Button {
                    vm.showHandoverConfirm = true
                } label: {
                    actionButtonLabel(
                        title: "Confirm Handover to Client",
                        icon: "checkmark.seal.fill",
                        loading: false
                    )
                }
                .buttonStyle(FilledActionButtonStyle(enabled: vm.canConfirmHandover, isDestructive: false, isPrimary: true))
                .disabled(!vm.canConfirmHandover)
            }
            .padding(AppSpacing.cardPadding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    // MARK: - Document card

    private var documentCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("HANDOVER DOCUMENT")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(.secondary)

            Text("Generate a PDF with product details, repair summary, parts used, cost, and pickup confirmation for the client.")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)

            Button {
                vm.generateHandoverDocument()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if vm.isGeneratingDoc {
                        ProgressView().tint(AppColors.accent).scaleEffect(0.8)
                    } else {
                        Image(systemName: "doc.badge.arrow.up")
                    }
                    Text(vm.isGeneratingDoc ? "Generating…" : "Generate & Share Document")
                        .font(AppTypography.buttonSecondary)
                }
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.accent, lineWidth: 1.2)
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isGeneratingDoc)
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }

    // MARK: - Reusable label builder

    private func actionButtonLabel(title: String, icon: String, loading: Bool) -> some View {
        HStack(spacing: AppSpacing.xs) {
            if loading {
                ProgressView().tint(.white).scaleEffect(0.8)
            } else {
                Image(systemName: icon)
            }
            Text(title).font(AppTypography.buttonSecondary)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
    }

    // MARK: - Banners

    private func successBanner(_ msg: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success)
            Text(msg).font(AppTypography.bodySmall)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).fill(AppColors.success.opacity(0.1)))
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
            Text(msg).font(AppTypography.bodySmall)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium).fill(AppColors.error.opacity(0.1)))
    }
}

// MARK: - Button style

private struct FilledActionButtonStyle: ButtonStyle {
    let enabled: Bool
    var isDestructive: Bool = false
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(
                        !enabled
                            ? Color(.systemGray3)
                            : isPrimary
                                ? AppColors.success
                                : AppColors.accent
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
