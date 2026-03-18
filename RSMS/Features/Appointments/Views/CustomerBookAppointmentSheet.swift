import SwiftUI

/// Sheet that lets a logged-in customer request a new boutique appointment.
/// The appointment is created with status = "requested" so a sales associate
/// can review and confirm it from their Requests tab.
struct CustomerBookAppointmentSheet: View {
    let clientId: UUID
    let onBooked: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var stores: [StoreDTO] = []
    @State private var selectedStoreId: UUID? = nil
    @State private var appointmentType = "in_store"
    @State private var scheduledAt: Date = {
        // Default to tomorrow at 11 AM
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 1) + 1
        comps.hour = 11
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date().addingTimeInterval(86400)
    }()
    @State private var durationMinutes = 60
    @State private var notes = ""

    // Loading / submission
    @State private var isLoadingStores = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    }

    private var isFormValid: Bool {
        selectedStoreId != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // ── Boutique picker ──────────────────────────────────
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("BOUTIQUE")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            if isLoadingStores {
                                HStack {
                                    ProgressView().tint(AppColors.accent)
                                    Text("Loading boutiques…")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                .padding(.vertical, AppSpacing.sm)
                            } else if stores.isEmpty {
                                Text("No boutiques available")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                    .padding(.vertical, AppSpacing.sm)
                            } else {
                                Picker("Select boutique", selection: $selectedStoreId) {
                                    Text("Select a boutique").tag(UUID?.none)
                                    ForEach(stores) { store in
                                        Text(store.name).tag(UUID?(store.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppColors.textPrimaryDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )

                        // ── Appointment type ─────────────────────────────────
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("TYPE")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            Picker("Appointment type", selection: $appointmentType) {
                                Text("In Store").tag("in_store")
                                Text("Video Call").tag("video")
                                Text("Phone").tag("phone")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )

                        // ── Date & time ──────────────────────────────────────
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("PREFERRED DATE & TIME")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            DatePicker(
                                "Date and time",
                                selection: $scheduledAt,
                                in: minimumDate...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .tint(AppColors.accent)
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )

                        // ── Duration ─────────────────────────────────────────
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("DURATION")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            Stepper(value: $durationMinutes, in: 30...180, step: 15) {
                                HStack {
                                    Text("Duration")
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Spacer()
                                    Text("\(durationMinutes) min")
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )

                        // ── Notes ────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("NOTES (OPTIONAL)")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            TextEditor(text: $notes)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(AppColors.backgroundPrimary)
                                .cornerRadius(AppSpacing.radiusSmall)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )

                        // ── Info note ─────────────────────────────────────────
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: "info.circle")
                                .foregroundColor(AppColors.info)
                                .font(.system(size: 14))
                                .padding(.top, 1)
                            Text("Your request will be reviewed by a sales associate who will confirm or suggest an alternative time.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.info.opacity(0.08))
                        .cornerRadius(AppSpacing.radiusSmall)

                        // ── Submit ────────────────────────────────────────────
                        PrimaryButton(title: isSubmitting ? "Submitting…" : "Request Appointment") {
                            Task { await submit() }
                        }
                        .disabled(!isFormValid || isSubmitting)
                        .opacity(isFormValid ? 1 : 0.5)
                        .padding(.bottom, AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("BOOK APPOINTMENT")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .task { await loadStores() }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView()
                            .tint(AppColors.accent)
                            .padding()
                            .background(AppColors.backgroundPrimary)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Private

    private func loadStores() async {
        isLoadingStores = true
        defer { isLoadingStores = false }
        do {
            stores = try await StoreSyncService.shared.fetchActiveBoutiques()
            if selectedStoreId == nil, let first = stores.first {
                selectedStoreId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func submit() async {
        guard let storeId = selectedStoreId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let payload = AppointmentInsertDTO(
                clientId: clientId,
                storeId: storeId,
                associateId: nil,
                type: appointmentType,
                status: "requested",
                scheduledAt: scheduledAt,
                durationMinutes: durationMinutes,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                videoLink: nil
            )
            _ = try await AppointmentService.shared.createAppointment(payload)
            onBooked()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
