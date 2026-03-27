//
//  ClientProfileEditView.swift
//  RSMS
//
//  Edit screen for authenticated customer profile fields stored in `clients`.
//

import SwiftUI

struct ClientProfileEditView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    // Date picker state — always holds a valid Date; defaults to 30 years ago when profile has no DOB
    @State private var dobDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var preferredLanguage = ""
    @State private var nationality = ""
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var marketingOptIn = false

    @State private var isLoading = false
    @State private var isInitialLoading = true
    @State private var showError = false
    @State private var showSuccessBanner = false
    @State private var errorMessage = ""
    @State private var loadTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?

    // MARK: - ISO date formatter (yyyy-MM-dd — required by Supabase)
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            if isInitialLoading {
                ProgressView("Loading profile...")
                    .tint(AppColors.accent)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(AppTypography.iconAction)
                                .foregroundColor(AppColors.accent)

                            Text("Profile Details")
                                .font(AppTypography.heading2)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .multilineTextAlignment(.center)

                            Text("Keep your account details up to date")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: AppSpacing.lg) {
                            LuxuryTextField(placeholder: "First Name", text: $firstName, icon: "person")
                            LuxuryTextField(placeholder: "Last Name", text: $lastName, icon: "person")
                            LuxuryTextField(placeholder: "Email (Read Only)", text: $email, icon: "envelope")
                                .disabled(true)
                                .opacity(0.7)
                            LuxuryTextField(placeholder: "Phone Number", text: $phone, icon: "phone")
                                .keyboardType(.phonePad)
                            // Calendar picker — eliminates manual date entry and YYYY-MM-DD format errors
                            LuxuryDatePicker(label: "Date of Birth", date: $dobDate, maximumDate: Date())
                            // Pull-down menu pickers — liquid glass style on iOS 26
                            LuxuryMenuPicker(
                                label: "Preferred Language",
                                icon: "character.book.closed",
                                items: LuxuryPickerItem.languages,
                                selection: $preferredLanguage,
                                placeholder: "Select language…"
                            )
                            LuxuryMenuPicker(
                                label: "Nationality",
                                icon: "globe",
                                items: LuxuryPickerItem.nationalities,
                                selection: $nationality,
                                placeholder: "Select nationality…"
                            )
                            LuxuryTextField(placeholder: "Address Line 1", text: $addressLine1, icon: "house")
                            LuxuryTextField(placeholder: "Address Line 2", text: $addressLine2, icon: "house")
                            LuxuryTextField(placeholder: "City", text: $city, icon: "building.2")
                            LuxuryTextField(placeholder: "State", text: $state, icon: "map")
                            LuxuryTextField(placeholder: "Postal Code", text: $postalCode, icon: "number")
                            LuxuryTextField(placeholder: "Country (2-letter code)", text: $country, icon: "globe.europe.africa")
                        }

                        Toggle(isOn: $marketingOptIn) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("Marketing Updates")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text("Receive offers and campaign updates")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }
                        .tint(AppColors.accent)

                        PrimaryButton(title: "Save Changes", isLoading: isLoading) {
                            saveProfile()
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.xl)
                }
            }

            if showSuccessBanner {
                VStack {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text("Profile updated")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusMedium)

                    Spacer()
                }
                .padding(.top, AppSpacing.xl)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Edit Profile")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
        }
        .task {
            loadTask?.cancel()
            loadTask = Task { await loadProfile() }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
            saveTask?.cancel()
            saveTask = nil
        }
    }

    @MainActor
    private func loadProfile() async {
        guard !Task.isCancelled else { return }
        isInitialLoading = true
        defer { isInitialLoading = false }

        do {
            let profile = try await ProfileService.shared.fetchMyClientProfile()
            appState.updateCurrentClientProfile(profile)

            firstName = profile.firstName
            lastName = profile.lastName
            email = profile.email
            phone = profile.phone ?? ""
            // Parse stored "yyyy-MM-dd" string back to Date; fall back to 30 years ago if absent/invalid
            if let dobString = profile.dateOfBirth,
               let parsed = Self.isoFormatter.date(from: dobString) {
                dobDate = parsed
            }
            preferredLanguage = profile.preferredLanguage ?? ""
            nationality = profile.nationality ?? ""
            addressLine1 = profile.addressLine1 ?? ""
            addressLine2 = profile.addressLine2 ?? ""
            city = profile.city ?? ""
            state = profile.state ?? ""
            postalCode = profile.postalCode ?? ""
            country = profile.country ?? ""
            marketingOptIn = profile.marketingOptIn
            loadTask = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            showError = true
            loadTask = nil
        }
    }

    private func saveProfile() {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirstName.isEmpty, !trimmedLastName.isEmpty else {
            errorMessage = "First name and last name are required."
            showError = true
            return
        }

        // Format Date → "yyyy-MM-dd" string for the DTO (always valid — came from a DatePicker)
        let dob = Self.isoFormatter.string(from: dobDate)

        isLoading = true
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            defer { isLoading = false }

            do {
                let payload = ClientUpdateDTO(
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    phone: optionalTrimmed(phone),
                    dateOfBirth: dob,
                    nationality: optionalTrimmed(nationality)?.uppercased(),
                    preferredLanguage: optionalTrimmed(preferredLanguage),
                    addressLine1: optionalTrimmed(addressLine1),
                    addressLine2: optionalTrimmed(addressLine2),
                    city: optionalTrimmed(city),
                    state: optionalTrimmed(state),
                    postalCode: optionalTrimmed(postalCode),
                    country: optionalTrimmed(country)?.uppercased(),
                    marketingOptIn: marketingOptIn
                )

                let updated = try await ProfileService.shared.updateMyClientProfile(payload)
                appState.updateCurrentClientProfile(updated)

                withAnimation(.easeInOut(duration: 0.2)) {
                    showSuccessBanner = true
                }
                saveTask = nil
                dismiss()
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                showError = true
                saveTask = nil
            }
        }
    }

    private func optionalTrimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}

#Preview {
    NavigationStack {
        ClientProfileEditView()
            .environment(AppState())
    }
}
