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
    @State private var requestToReject: AppointmentDTO?

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
                        // Force full rebuild when switching tabs so cached request cards
                        // never bleed into the Upcoming / Today / Past sections.
                        .id(selectedSection)
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
            .onChange(of: vm.pendingTabSwitch) { _, newTab in
                if let tab = newTab {
                    selectedSection = tab
                    vm.pendingTabSwitch = nil
                }
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
            .alert("Appointment Cancelled", isPresented: $vm.showCancellationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.cancellationAlertMessage)
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
            .alert("Reject Appointment", isPresented: Binding(
                get: { requestToReject != nil },
                set: { if !$0 { requestToReject = nil } }
            )) {
                Button("Reject", role: .destructive) {
                    if let request = requestToReject {
                        Task { await vm.rejectRequest(request) }
                    }
                    requestToReject = nil
                }
                Button("Cancel", role: .cancel) {
                    requestToReject = nil
                }
            } message: {
                if let request = requestToReject {
                    Text("Reject request for \(request.scheduledAt.formatted(date: .abbreviated, time: .shortened))?")
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
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let customer = vm.customer(for: request) {
                            Text(customer.fullName)
                                .font(AppTypography.bodyMedium.bold())
                                .foregroundColor(AppColors.textPrimaryDark)
                                .lineLimit(1)
                            Text(customer.email)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .lineLimit(1)
                        } else {
                            Text("Customer details unavailable")
                                .font(AppTypography.bodyMedium.bold())
                                .foregroundColor(AppColors.textPrimaryDark)
                        }

                        Text(request.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondaryDark)

                        Text("\(request.type.replacingOccurrences(of: "_", with: " ").capitalized) • \(request.durationMinutes) min")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }

                    GoldDivider()

                    HStack(spacing: AppSpacing.sm) {
                        Spacer(minLength: 0)

                        Button("Reject") {
                            requestToReject = request
                        }
                        .font(AppTypography.buttonPrimary)
                        .frame(minWidth: 96)
                        .padding(.vertical, 10)
                        .background(AppColors.error.opacity(0.12))
                        .foregroundColor(AppColors.error)
                        .clipShape(Capsule())

                        Button("Accept") {
                            requestToAccept = request
                        }
                        .font(AppTypography.buttonPrimary)
                        .frame(minWidth: 104)
                        .padding(.vertical, 10)
                        .background(AppColors.accent)
                        .foregroundColor(AppColors.backgroundPrimary)
                        .clipShape(Capsule())
                    }
                }
                .padding()
                .background(AppColors.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.accent.opacity(0.24), lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.top, AppSpacing.sm)
        }
    }
    
    private func currentList() -> [AppointmentDTO] {
        func nonRequested(_ list: [AppointmentDTO]) -> [AppointmentDTO] {
            list.filter {
                $0.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "requested"
            }
        }

        switch selectedSection {
        case 0: return nonRequested(vm.todayAppointments)
        case 1: return nonRequested(vm.upcomingAppointments)
        case 2: return nonRequested(vm.pastAppointments)
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
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
                        Text("Customer details unavailable")
                            .font(AppTypography.bodyMedium.bold())
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
                Spacer()
                Text(appointment.type.replacingOccurrences(of: "_", with: " ").uppercased())
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(Capsule())
            }

            GoldDivider()

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
