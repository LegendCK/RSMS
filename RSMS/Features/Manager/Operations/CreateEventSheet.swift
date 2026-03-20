//
//  CreateEventSheet.swift
//  RSMS
//
//  Form for Boutique Managers to create a new boutique event in Supabase.
//  After creation the event appears in the VIP Events tab and sales can be tagged to it.
//

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

    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError    = false

    private let currencies = ["INR", "USD", "EUR", "GBP", "AED", "SGD", "JPY"]

    private var isValid: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
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
                        Picker("Event Type", selection: $eventType) {
                            ForEach(EventType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.sm)
                        .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                    }

                    // ── Date & Time ─────────────────────────────────────
                    formField(label: "DATE & TIME") {
                        DatePicker("", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .padding(AppSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                    }

                    // ── Duration & Capacity ─────────────────────────────
                    HStack(spacing: AppSpacing.sm) {
                        formField(label: "DURATION (MIN)") {
                            Stepper("\(durationMinutes) min", value: $durationMinutes, in: 30...480, step: 30)
                                .font(AppTypography.bodySmall)
                                .padding(AppSpacing.sm)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                        }
                        formField(label: "CAPACITY") {
                            Stepper("\(capacity) guests", value: $capacity, in: 1...500, step: 5)
                                .font(AppTypography.bodySmall)
                                .padding(AppSpacing.sm)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
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
                            .padding(AppSpacing.xs)
                            .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)

                            TextField("0.00", text: $estimatedCost)
                                .keyboardType(.decimalPad)
                                .font(AppTypography.bodyMedium)
                                .padding(AppSpacing.sm)
                                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
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

                    // ── Submit ──────────────────────────────────────────
                    Button {
                        Task { await create() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                        } else {
                            Label("Create Event", systemImage: "star.fill")
                                .font(AppTypography.label)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                        }
                    }
                    .background(isValid ? AppColors.accent : AppColors.neutral500)
                    .cornerRadius(AppSpacing.radiusMedium)
                    .disabled(!isValid || isSubmitting)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("New Event")
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

    // MARK: - Helpers

    @ViewBuilder
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.md)
        .managerCardSurface(cornerRadius: AppSpacing.radiusMedium)
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
            currency:        currency
        )

        do {
            _ = try await EventSalesService.shared.createEvent(dto)
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
