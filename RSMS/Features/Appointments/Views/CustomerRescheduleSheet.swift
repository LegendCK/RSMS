import SwiftUI

/// Sheet allowing the customer to pick a new preferred date/time and submit a reschedule request.
/// The appointment status is set back to "requested" so the sales associate can accept/reject the
/// new slot from their Requests tab.
struct CustomerRescheduleSheet: View {
    let appointment: AppointmentDTO
    let onSubmit: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Default to tomorrow at the same time of day, but never earlier than 2 hours from now.
    @State private var selectedDate: Date

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    }

    init(appointment: AppointmentDTO, onSubmit: @escaping (Date) -> Void) {
        self.appointment = appointment
        self.onSubmit = onSubmit
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        _selectedDate = State(initialValue: tomorrow)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // ── Current appointment summary ──────────────────────
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("CURRENT APPOINTMENT")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColors.accent)
                                Text(appointment.scheduledAt.formatted(date: .complete, time: .shortened))
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                            }

                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "clock")
                                    .foregroundColor(AppColors.textSecondaryDark)
                                Text("\(appointment.type.replacingOccurrences(of: "_", with: " ").capitalized) · \(appointment.durationMinutes) min")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )

                        // ── New time picker ───────────────────────────────────
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("PREFERRED NEW TIME")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            DatePicker(
                                "Select date and time",
                                selection: $selectedDate,
                                in: minimumDate...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .tint(AppColors.accent)
                        }

                        // ── Info note ─────────────────────────────────────────
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: "info.circle")
                                .foregroundColor(AppColors.info)
                                .font(.system(size: 14))
                                .padding(.top, 1)
                            Text("Your associate will review the new time and confirm or suggest an alternative.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.info.opacity(0.08))
                        .cornerRadius(AppSpacing.radiusSmall)

                        // ── Actions ───────────────────────────────────────────
                        VStack(spacing: AppSpacing.sm) {
                            PrimaryButton(title: "Submit Reschedule Request") {
                                onSubmit(selectedDate)
                                dismiss()
                            }
                            SecondaryButton(title: "Keep Current Appointment") {
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("REQUEST RESCHEDULE")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}
