import SwiftUI

struct CustomerAppointmentsView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = CustomerAppointmentsViewModel()
    @State private var selectedSection = 0 // 0 upcoming, 1 past

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if !canViewAppointments {
                    unavailableState
                } else {
                    VStack(spacing: 0) {
                        Picker("", selection: $selectedSection) {
                            Text("Upcoming").tag(0)
                            Text("Past").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.vertical, AppSpacing.sm)

                        ScrollView {
                            if vm.isLoading && currentList.isEmpty {
                                ProgressView()
                                    .tint(AppColors.accent)
                                    .padding(.top, 60)
                            } else if currentList.isEmpty {
                                emptyState
                                    .padding(.top, 56)
                            } else {
                                LazyVStack(spacing: AppSpacing.md) {
                                    ForEach(currentList) { appointment in
                                        appointmentCard(appointment)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                                .padding(.top, AppSpacing.sm)
                            }
                        }
                        .refreshable {
                            await vm.loadAppointments(clientId: appState.currentUserProfile?.id)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MY APPOINTMENTS")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
            }
            .task {
                await vm.loadAppointments(clientId: appState.currentUserProfile?.id)
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage)
            }
        }
    }

    private var canViewAppointments: Bool {
        appState.isAuthenticated && !appState.isGuest && appState.currentUserRole == .customer
    }

    private var currentList: [AppointmentDTO] {
        selectedSection == 0 ? vm.upcomingAppointments : vm.pastAppointments
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: selectedSection == 0 ? "calendar.badge.clock" : "calendar.badge.checkmark")
                .font(AppTypography.emptyStateIcon)
                .foregroundColor(AppColors.accent.opacity(0.55))
            Text(selectedSection == 0 ? "No upcoming appointments" : "No past appointments")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
    }

    private var unavailableState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(AppTypography.iconDecorative)
                .foregroundColor(AppColors.warning)
            Text("Sign in as a customer to view appointments")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func appointmentCard(_ appointment: AppointmentDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.storeName(for: appointment))
                        .font(AppTypography.bodyMedium.bold())
                        .foregroundColor(AppColors.textPrimaryDark)

                    Text(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Spacer(minLength: 8)

                Text(vm.statusLabel(appointment.status).uppercased())
                    .font(AppTypography.caption)
                    .foregroundColor(statusColor(appointment.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(appointment.status).opacity(0.12))
                    .clipShape(Capsule())
            }

            GoldDivider()

            HStack(spacing: AppSpacing.sm) {
                Text(vm.normalizedType(appointment.type))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Text("•")
                    .foregroundColor(AppColors.textSecondaryDark)
                Text("\(appointment.durationMinutes) min")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            if let notes = appointment.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(AppColors.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private func statusColor(_ status: String) -> Color {
        switch vm.normalizedStatus(status) {
        case "requested":
            return AppColors.warning
        case "scheduled", "confirmed", "in_progress":
            return AppColors.info
        case "completed":
            return AppColors.success
        case "cancelled", "no_show":
            return AppColors.error
        default:
            return AppColors.accent
        }
    }
}

#Preview {
    NavigationStack {
        CustomerAppointmentsView()
            .environment(AppState())
    }
}
