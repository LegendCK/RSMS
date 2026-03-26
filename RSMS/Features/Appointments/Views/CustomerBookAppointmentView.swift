import SwiftUI

struct CustomerBookAppointmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CustomerBookAppointmentViewModel()
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if !canBook {
                unavailableState
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        storeSection
                        dateTimeSection
                        detailsSection
                    }
                    .padding(AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .navigationTitle("Book Appointment")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Submit") {
                    Task {
                        if await vm.submitAppointmentRequest(clientId: appState.currentUserProfile?.id) != nil {
                            showSuccess = true
                        }
                    }
                }
                .disabled(!vm.canSubmit || vm.isSubmitting || !canBook)
                .foregroundColor((vm.canSubmit && canBook) ? AppColors.accent : AppColors.textSecondaryDark)
            }
        }
        .task {
            if canBook {
                await vm.loadStores()
            }
        }
        .onChange(of: vm.selectedStoreId) { _, _ in
            Task { await vm.refreshAvailabilityForSelectedStore() }
        }
        .alert("Request Submitted", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your appointment request has been sent to the boutique team. You'll receive confirmation soon.")
        }
        .alert("Unable to book", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage)
        }
        .overlay {
            if vm.isSubmitting {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView().tint(AppColors.accent)
                }
            }
        }
    }

    private var canBook: Bool {
        appState.isAuthenticated && !appState.isGuest && appState.currentUserRole == .customer
    }

    private var unavailableState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(AppTypography.iconDecorative)
                .foregroundColor(AppColors.warning)
            Text("Sign in as a customer to book appointments")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var storeSection: some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("BOUTIQUE")
                    .font(AppTypography.overline)
                    .foregroundColor(AppColors.textSecondaryDark)

                if vm.isLoadingStores {
                    ProgressView().tint(AppColors.accent)
                } else {
                    Picker("Select Boutique", selection: $vm.selectedStoreId) {
                        Text("Select a Boutique").tag(UUID?.none)
                        ForEach(vm.stores) { store in
                            Text(storeLabel(store)).tag(UUID?(store.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.textPrimaryDark)

                    if let store = vm.selectedStore {
                        Text(storeAddress(store))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
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

                DatePicker("Preferred Time", selection: $vm.scheduledAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .tint(AppColors.accent)

                GoldDivider()

                Stepper(value: $vm.durationMinutes, in: 15...180, step: 15) {
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

                if let message = vm.slotConflictMessage {
                    GoldDivider()
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.error)
                }
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

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

                GoldDivider()

                Text("Notes")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)

                TextEditor(text: $vm.notes)
                    .font(AppTypography.bodyMedium)
                    .frame(height: 96)
                    .padding(8)
                    .background(AppColors.neutral100)
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func storeLabel(_ store: StoreDTO) -> String {
        return store.name
    }

    private func storeAddress(_ store: StoreDTO) -> String {
        return "Maison Luxe Location"
    }
}

#Preview {
    NavigationStack {
        CustomerBookAppointmentView()
            .environment(AppState())
    }
}
