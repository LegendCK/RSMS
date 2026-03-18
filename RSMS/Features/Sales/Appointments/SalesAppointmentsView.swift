//
//  SalesAppointmentsView.swift
//  infosys2
//
//  Sales Associate appointment management — booking, reminders, schedule.
//

import SwiftUI
import SwiftData

struct SalesAppointmentsView: View {
    @State private var vm = SalesAppointmentsViewModel()
    @State private var selectedSection = 0 // 0 = Today, 1 = Upcoming, 2 = Past, 3 = Requests
    @State private var showCreateForm = false
    @State private var selectedAppointment: AppointmentDTO?
    @State private var requestToAccept: AppointmentDTO?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Today").tag(0)
                        Text("Upcoming").tag(1)
                        Text("Past").tag(2)
                        Text("Requests").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)

                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md, pinnedViews: [.sectionHeaders]) {
                            if selectedSection == 3 {
                                renderRequestsSection()
                            } else {
                                listSection
                            }
                        }
                    }
                    .refreshable {
                        await vm.loadSchedule()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("APPOINTMENTS")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateForm = true
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreateForm) {
                CreateAppointmentView { _ in
                    Task { await vm.loadSchedule() }
                }
            }
            .sheet(item: $selectedAppointment) { appt in
                CreateAppointmentView(appointmentToEdit: appt) { _ in
                    Task { await vm.loadSchedule() }
                }
            }
            .task {
                await vm.loadSchedule()
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(vm.errorMessage)
            }
            .alert("Appointment Requests", isPresented: $vm.showRequestAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.requestAlertMessage)
            }
            .alert("Accept Appointment", isPresented: Binding(
                get: { requestToAccept != nil },
                set: { if !$0 { requestToAccept = nil } }
            )) {
                Button("Accept") {
                    if let request = requestToAccept {
                        Task { await vm.acceptRequest(request) }
                    }
                    requestToAccept = nil
                }
                Button("Cancel", role: .cancel) {
                    requestToAccept = nil
                }
            } message: {
                if let request = requestToAccept {
                    Text("Confirm \(request.scheduledAt.formatted(date: .abbreviated, time: .shortened)) • \(request.durationMinutes) min?")
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderRequestsSection() -> some View {
        if vm.requestedAppointments.isEmpty {
            emptyStateView(message: "No open requests", icon: "envelope.open")
                .padding(.top, 40)
        } else {
            ForEach(vm.requestedAppointments) { request in
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let customer = vm.customer(for: request) {
                            Text(customer.fullName)
                                .font(AppTypography.bodyMedium.bold())
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text(customer.email)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        } else {
                            Text("Customer #\(request.clientId.uuidString.prefix(8))")
                                .font(AppTypography.bodyMedium.bold())
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                        Text(request.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text("\(request.type.capitalized) • \(request.durationMinutes) min")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Button("Accept") {
                        requestToAccept = request
                    }
                    .font(AppTypography.buttonPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.accent)
                    .foregroundColor(AppColors.backgroundPrimary)
                    .cornerRadius(8)
                }
                .padding()
                .background(AppColors.surfaceDark)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.top, AppSpacing.sm)
        }
    }
    
    private func currentList() -> [AppointmentDTO] {
        switch selectedSection {
        case 0: return vm.todayAppointments
        case 1: return vm.upcomingAppointments
        case 2: return vm.pastAppointments
        default: return []
        }
    }
    
    @ViewBuilder
    private func emptyStateView(message: String = "No appointments scheduled", icon: String = "calendar.badge.clock") -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(AppTypography.emptyStateIcon)
                .foregroundColor(AppColors.accent.opacity(0.5))
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
            if selectedSection != 3 {
                Text("Book appointments to provide personalized experiences")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var listSection: some View {
        let list = currentList()
        if list.isEmpty {
            emptyStateView()
                .padding(.top, 40)
        } else {
            ForEach(list) { appointment in
                Button {
                    selectedAppointment = appointment
                } label: {
                    appointmentCard(appointment)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
        }
    }
    
    @ViewBuilder
    private func appointmentCard(_ appointment: AppointmentDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let customer = vm.customer(for: appointment) {
                        Text(customer.fullName)
                            .font(AppTypography.bodyMedium.bold())
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text(customer.email)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    } else {
                        Text("Customer #\(appointment.clientId.uuidString.prefix(8))")
                            .font(AppTypography.bodyMedium.bold())
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
                Spacer()
                Text(appointment.type.uppercased())
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)

            if let notes = appointment.notes {
                Text(notes)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(AppColors.surfaceDark)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}
