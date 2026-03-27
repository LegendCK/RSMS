import SwiftUI

struct CreateEventSheet: View {
    let onCreated: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var eventName       = ""
    @State private var eventType       = EventType.trunkShow
    @State private var scheduledDate   = Date().addingTimeInterval(86400) // tomorrow
    @State private var durationMinutes = 120
    @State private var capacity        = 30
    @State private var relatedCategory = ""
    @State private var description     = ""
    @State private var estimatedCost   = ""
    @State private var currency        = "INR"

    @State private var invitedSegment: String? = nil
    @State private var eligibleCount: Int?     = nil
    @State private var totalCount: Int?        = nil
    @State private var loadingEligible         = false

    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError    = false

    private let currencies = ["INR", "USD", "EUR", "GBP", "AED", "SGD", "JPY"]

    private var isValid: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {

                        // ── Event Name ──────────────────────────────────────
                        formField(label: "EVENT NAME") {
                            TextField("e.g. Spring Trunk Show 2026", text: $eventName)
                                .font(AppTypography.bodyMedium)
                                .padding(AppSpacing.sm)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }

                        // ── Type ────────────────────────────────────────────
                        formField(label: "EVENT TYPE") {
                            HStack {
                                Text(eventType.rawValue)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Spacer()
                                Menu {
                                    Picker("Event Type", selection: $eventType) {
                                        ForEach(EventType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                            .padding(AppSpacing.sm)
                            .background(AppColors.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
                                    .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                            )
                        }

                        // ── Date & Time ─────────────────────────────────────
                        formField(label: "DATE & TIME") {
                            HStack(spacing: AppSpacing.sm) {
                                DatePicker(
                                    "Date",
                                    selection: $scheduledDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(.horizontal, AppSpacing.sm)
                                .frame(height: 42)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
                                        .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                                )

                                DatePicker(
                                    "Time",
                                    selection: $scheduledDate,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(.horizontal, AppSpacing.sm)
                                .frame(height: 42)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
                                        .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                                )
                            }
                        }

                        // ── Duration & Capacity ─────────────────────────────
                        HStack(spacing: AppSpacing.sm) {
                            numericStepperField(
                                label: "DURATION (MIN)",
                                valueText: "\(durationMinutes)",
                                suffixText: "minutes"
                            ) {
                                Stepper("", value: $durationMinutes, in: 30...480, step: 30)
                                    .labelsHidden()
                                    .tint(AppColors.accent)
                            }
                            numericStepperField(
                                label: "CAPACITY",
                                valueText: "\(capacity)",
                                suffixText: "guests"
                            ) {
                                Stepper("", value: $capacity, in: 1...500, step: 5)
                                    .labelsHidden()
                                    .tint(AppColors.accent)
                            }
                        }

                        // ── Category ────────────────────────────────────────
                        formField(label: "RELATED CATEGORY (OPTIONAL)") {
                            TextField("e.g. Jewellery, Couture, Watches", text: $relatedCategory)
                                .font(AppTypography.bodySmall)
                                .padding(AppSpacing.sm)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }

                        // ── Estimated Cost ──────────────────────────────────
                        formField(label: "ESTIMATED EVENT COST (OPTIONAL)") {
                            HStack(spacing: AppSpacing.xs) {
                                Picker("", selection: $currency) {
                                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .padding(.horizontal, AppSpacing.sm)
                                .frame(height: 42)
                                .background(AppColors.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
                                        .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                                )

                                TextField("0.00", text: $estimatedCost)
                                    .keyboardType(.decimalPad)
                                    .font(AppTypography.bodyMedium)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .frame(height: 42)
                                    .background(AppColors.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
                                            .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            Text("Used to calculate ROI % in the sales report.")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }

                        // ── Description ─────────────────────────────────────
                        formField(label: "DESCRIPTION (OPTIONAL)") {
                            TextEditor(text: $description)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(height: 80)
                                .padding(AppSpacing.xs)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }

                        // ── Who to Invite ───────────────────────────────────
                        formField(label: "WHO TO INVITE (OPTIONAL)") {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack(spacing: AppSpacing.xs) {
                                    segmentChip(label: "None",    selected: invitedSegment == nil) { invitedSegment = nil }
                                    segmentChip(label: "Gold",    selected: invitedSegment == "gold") { invitedSegment = "gold" }
                                    segmentChip(label: "VIP",     selected: invitedSegment == "vip")  { invitedSegment = "vip"  }
                                }

                                if let seg = invitedSegment {
                                    if loadingEligible {
                                        ProgressView()
                                            .tint(AppColors.accent)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else if let eligible = eligibleCount {
                                        let excluded = (totalCount ?? eligible) - eligible
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(eligible) client\(eligible == 1 ? "" : "s") in the \(seg.capitalized) segment will receive an invitation.")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.success)
                                            if excluded > 0 {
                                                Text("\(excluded) excluded — missing GDPR/marketing consent.")
                                                    .font(AppTypography.micro)
                                                    .foregroundColor(AppColors.warning)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: invitedSegment) { _, newSeg in
                            Task { await refreshEligibleCount(segment: newSeg) }
                        }

                        // ── Submit ──────────────────────────────────────────
                        Button {
                            Task { await create() }
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Create Event", systemImage: "sparkles")
                                        .font(AppTypography.label)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                        }
                        .background(isValid ? AppColors.accent : AppColors.neutral500)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .disabled(!isValid || isSubmitting)

                        Spacer().frame(height: AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Create Event")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                if !isSubmitting {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") { Task { await create() } }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isValid ? AppColors.accent : AppColors.neutral500)
                            .disabled(!isValid)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Helpers

    private func segmentChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(selected ? .white : AppColors.textPrimaryDark)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(selected ? AppColors.accent : AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusSmall)
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                    .strokeBorder(selected ? Color.clear : AppColors.border, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func refreshEligibleCount(segment: String?) async {
        guard let seg = segment else {
            eligibleCount = nil
            totalCount    = nil
            return
        }
        loadingEligible = true
        defer { loadingEligible = false }
        async let eligible = EventInvitationService.shared.fetchEligibleClients(segment: seg)
        async let total    = EventInvitationService.shared.fetchSegmentTotalCount(segment: seg)
        eligibleCount = (try? await eligible)?.count
        totalCount    = try? await total
    }

    @ViewBuilder
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.overline)
                .tracking(1.6)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
    }

    @ViewBuilder
    private func numericStepperField<Content: View>(
        label: String,
        valueText: String,
        suffixText: String,
        @ViewBuilder stepper: () -> Content
    ) -> some View {
        formField(label: label) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(valueText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(suffixText)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                HStack {
                    Spacer()
                    stepper()
                        .frame(width: 112, alignment: .trailing)
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundSecondary, in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
                    .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private func create() async {
        guard let storeId = appState.currentStoreId else {
            errorMessage = "Store ID unavailable. Please log out and back in."
            showError = true
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let cost: Double? = estimatedCost.isEmpty ? nil : Double(estimatedCost)

        let dto = EventInsertDTO(
            storeId:         storeId,
            eventName:       eventName.trimmingCharacters(in: .whitespacesAndNewlines),
            eventType:       eventType.rawValue,
            status:          EventStatus.planned.rawValue,
            scheduledDate:   scheduledDate,
            durationMinutes: durationMinutes,
            capacity:        capacity,
            hostAssociateId: appState.currentUserProfile?.id,
            description:     description.trimmingCharacters(in: .whitespacesAndNewlines),
            relatedCategory: relatedCategory.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedCost:   cost,
            currency:        currency,
            invitedSegment:  invitedSegment
        )

        do {
            let created = try await EventSalesService.shared.createEvent(dto)
            if let seg = invitedSegment {
                let clients = (try? await EventInvitationService.shared.fetchEligibleClients(segment: seg)) ?? []
                _ = try? await EventInvitationService.shared.sendInvitations(event: created, clients: clients, storeId: storeId)
            }
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
