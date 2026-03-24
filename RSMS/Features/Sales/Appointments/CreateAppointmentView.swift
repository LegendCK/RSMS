//
//  CreateAppointmentView.swift
//  RSMS
//
//  A modal sheet to create an appointment.
//  Can be initialized with a preselected client ID if opened from the client profile.
//

import SwiftUI

struct CreateAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: CreateAppointmentViewModel
    
    // External callback when the appointment is successfully saved
    var onSaved: ((AppointmentDTO) -> Void)?
    
    init(
        preselectedClientId: UUID? = nil,
        preselectedClientName: String? = nil,
        appointmentToEdit: AppointmentDTO? = nil,
        onSaved: ((AppointmentDTO) -> Void)? = nil
    ) {
        _vm = State(initialValue: CreateAppointmentViewModel(
            preselectedClientId: preselectedClientId,
            preselectedClientName: preselectedClientName,
            editingAppointment: appointmentToEdit
        ))
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        clientPickerSection
                        dateTimeSection
                        detailsSection
                    }
                    .padding(AppSpacing.screenHorizontal)
                }
            }
            .navigationTitle(vm.isEditing ? "Edit Appointment" : "New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            if let newAppt = await vm.saveAppointment() {
                                onSaved?(newAppt)
                                dismiss()
                            }
                        }
                    }
                    .font(AppTypography.buttonPrimary)
                    .foregroundColor(vm.isFormValid ? AppColors.accent : AppColors.textSecondaryDark)
                    .disabled(!vm.isFormValid || vm.isSubmitting)
                }
            }
            .task { await vm.loadDataIfNeeded() }
            .alert("Error saving appointment", isPresented: $vm.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(vm.errorMessage)
            }
            .overlay {
                if vm.isSubmitting {
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
    
    // MARK: - Form Sections
    
    private var clientPickerSection: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("CLIENT")
                    .font(AppTypography.overline)
                    .foregroundColor(AppColors.textSecondaryDark)
                
                if vm.lockClientSelection {
                    Text("Selected: \(vm.selectedClientName)")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .padding(.vertical, 8)
                } else {
                    Picker("Select Client", selection: $vm.selectedClientId) {
                        Text("Select a Client").tag(UUID?.none)
                        ForEach(vm.clients) { client in
                            Text(client.fullName).tag(UUID?(client.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.textPrimaryDark)
                }
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var dateTimeSection: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("DATE & TIME")
                    .font(AppTypography.overline)
                    .foregroundColor(AppColors.textSecondaryDark)
                
                DatePicker("Starts At", selection: $vm.scheduledAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .tint(AppColors.accent)
                
                GoldDivider()
                
                Stepper(value: $vm.durationMinutes, in: 15...240, step: 15) {
                    HStack {
                        Text("Duration")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Spacer()
                        Text("\(vm.durationMinutes) min")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("DETAILS")
                    .font(AppTypography.overline)
                    .foregroundColor(AppColors.textSecondaryDark)
                
                HStack {
                    Text("Type")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    Picker("Appointment Type", selection: $vm.type) {
                        Text("In Store").tag("in_store")
                        Text("Video Call").tag("video_call")
                        Text("Phone").tag("phone")
                    }
                    .tint(AppColors.accent)
                }

                if vm.isEditing {
                    GoldDivider()
                    HStack {
                        Text("Status")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Spacer()
                        Picker("Status", selection: $vm.status) {
                            ForEach(vm.statusOptions) { option in
                                Text(option.title).tag(option.value)
                            }
                        }
                        .tint(AppColors.accent)
                    }
                }
                
                if vm.type == "video_call" {
                    GoldDivider()
                    TextField("Video Link (Optional)", text: $vm.videoLink)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                GoldDivider()
                Text("Notes")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                
                TextEditor(text: $vm.notes)
                    .font(AppTypography.bodyMedium)
                    .frame(height: 80)
                    .padding(8)
                    .background(AppColors.neutral100)
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden) 
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("ASSIGNMENT")
                    .font(AppTypography.overline)
                    .foregroundColor(AppColors.textSecondaryDark)
                
                Picker("Assigned To", selection: $vm.selectedAssociateId) {
                    if vm.selectedAssociateId == nil {
                        Text("Loading...").tag(UUID?.none)
                    }
                    ForEach(vm.associates) { associate in
                        Text(associate.fullName).tag(UUID?(associate.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
