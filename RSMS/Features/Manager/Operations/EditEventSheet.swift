//
//  EditEventSheet.swift
//  RSMS
//
//  Edit sheet for an existing boutique event.
//  — Status is automated (Planned → In Progress → Completed via server function).
//  — Manager can edit details only while Planned or Confirmed.
//  — Manager can cancel any non-final event from this sheet.
//

import SwiftUI

struct EditEventSheet: View {
    let event:     EventDTO
    let onUpdated: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss)     private var dismiss

    // Form state — pre-populated from event
    @State private var eventName:       String
    @State private var eventType:       EventType
    @State private var scheduledDate:   Date
    @State private var durationMinutes: Int
    @State private var capacity:        Int
    @State private var relatedCategory: String
    @State private var description:     String
    @State private var estimatedCost:   String
    @State private var currency:        String
    @State private var invitedSegment:  String?

    @State private var isSubmitting      = false
    @State private var errorMessage      = ""
    @State private var showError         = false
    @State private var showCancelConfirm = false

    private let currencies = ["INR", "USD", "EUR", "GBP", "AED", "SGD", "JPY"]

    /// Fields are editable only before the event starts.
    private var fieldsEditable: Bool { event.isEditable }

    init(event: EventDTO, onUpdated: @escaping () -> Void) {
        self.event     = event
        self.onUpdated = onUpdated
        _eventName       = State(initialValue: event.eventName)
        _eventType       = State(initialValue: EventType(rawValue: event.eventType) ?? .trunkShow)
        _scheduledDate   = State(initialValue: event.scheduledDate)
        _durationMinutes = State(initialValue: event.durationMinutes)
        _capacity        = State(initialValue: event.capacity)
        _relatedCategory = State(initialValue: event.relatedCategory)
        _description     = State(initialValue: event.description)
        _estimatedCost   = State(initialValue: event.estimatedCost.map { String($0) } ?? "")
        _currency        = State(initialValue: event.currency)
        _invitedSegment  = State(initialValue: event.invitedSegment)
    }

    private var isValid: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {

                    // Status banner (read-only — system managed)
                    statusBanner

                    if fieldsEditable {
                        editableFields
                    } else {
                        // In Progress: show read-only summary
                        readOnlySummary
                    }

                    // Cancel Event — destructive, for any non-final event
                    if event.isCancellable {
                        Button(role: .destructive) {
                            showCancelConfirm = true
                        } label: {
                            Label("Cancel Event", systemImage: "xmark.circle")
                                .font(AppTypography.label)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.error)
                        .confirmationDialog(
                            "Cancel \"\(event.eventName)\"?",
                            isPresented: $showCancelConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Cancel Event", role: .destructive) {
                                Task { await cancelEvent() }
                            }
                            Button("Keep Event", role: .cancel) {}
                        } message: {
                            Text("Invited guests will not be automatically notified of the cancellation.")
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if fieldsEditable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(isValid ? AppColors.accent : AppColors.neutral500)
                            .disabled(!isValid || isSubmitting)
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

    // MARK: - Status Banner

    private var statusBanner: some View {
        let (icon, color, label, subtitle): (String, Color, String, String) = {
            switch event.status {
            case "Planned":     return ("clock",                AppColors.warning, "Planned",     "Awaiting confirmation")
            case "Confirmed":   return ("checkmark.circle",     AppColors.success, "Confirmed",   "Event is confirmed")
            case "In Progress": return ("star.circle.fill",     AppColors.accent,  "In Progress", "Event is happening now — editing locked")
            case "Completed":   return ("checkmark.seal.fill",  AppColors.neutral500, "Completed", "This event has ended")
            case "Cancelled":   return ("xmark.circle.fill",    AppColors.error,   "Cancelled",   "This event was cancelled")
            default:            return ("circle",               AppColors.neutral500, event.status, "")
            }
        }()

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
            Spacer()
            Text("AUTO")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(AppSpacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }

    // MARK: - Editable Fields (Planned / Confirmed)

    private var editableFields: some View {
        VStack(spacing: AppSpacing.md) {

            formField(label: "EVENT NAME") {
                TextField("e.g. Spring Trunk Show 2026", text: $eventName)
                    .font(AppTypography.bodyMedium)
                    .padding(AppSpacing.sm)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
            }

            formField(label: "EVENT TYPE") {
                Picker("Event Type", selection: $eventType) {
                    ForEach(EventType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
            }

            formField(label: "DATE & TIME") {
                DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
            }

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

            formField(label: "RELATED CATEGORY (OPTIONAL)") {
                TextField("e.g. Jewellery, Couture, Watches", text: $relatedCategory)
                    .font(AppTypography.bodySmall)
                    .padding(AppSpacing.sm)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
            }

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
            }

            formField(label: "DESCRIPTION (OPTIONAL)") {
                TextEditor(text: $description)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .frame(height: 80)
                    .padding(AppSpacing.xs)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
            }

            if let seg = invitedSegment {
                formField(label: "INVITED SEGMENT") {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(AppColors.secondary)
                        Text(seg.uppercased())
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Spacer()
                        Text("Invitations already sent")
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(AppSpacing.sm)
                    .managerCardSurface(cornerRadius: AppSpacing.radiusSmall)
                }
            }
        }
    }

    // MARK: - Read-Only Summary (In Progress)

    private var readOnlySummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EVENT DETAILS")
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.bottom, AppSpacing.sm)

            VStack(spacing: AppSpacing.sm) {
                summaryRow(icon: "textformat",   label: "Name",     value: event.eventName)
                summaryRow(icon: "theatermasks", label: "Type",     value: event.eventType)
                summaryRow(icon: "calendar",     label: "Date",     value: event.scheduledDate.formatted(date: .long, time: .shortened))
                summaryRow(icon: "clock",        label: "Duration", value: "\(event.durationMinutes) min")
                summaryRow(icon: "person.2",     label: "Capacity", value: "\(event.capacity) guests")
            }

            if !event.description.isEmpty {
                Divider().padding(.vertical, AppSpacing.sm)
                Text(event.description)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.accent)
                .frame(width: 18, alignment: .center)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
        }
    }

    // MARK: - Actions

    private func save() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let cost: Double? = estimatedCost.isEmpty ? nil : Double(estimatedCost)

        let dto = EventUpdateDTO(
            eventName:       eventName.trimmingCharacters(in: .whitespacesAndNewlines),
            eventType:       eventType.rawValue,
            status:          nil,   // status is system-managed
            scheduledDate:   scheduledDate,
            durationMinutes: durationMinutes,
            capacity:        capacity,
            description:     description.trimmingCharacters(in: .whitespacesAndNewlines),
            relatedCategory: relatedCategory.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedCost:   cost,
            currency:        currency,
            invitedSegment:  invitedSegment
        )

        do {
            try await EventSalesService.shared.updateEvent(eventId: event.id, dto: dto)
            onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func cancelEvent() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await EventSalesService.shared.cancelEvent(eventId: event.id)
            onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Form Field Helper

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
}
