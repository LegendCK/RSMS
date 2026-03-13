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
    @State private var dateOfBirth = ""
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
                            LuxuryTextField(placeholder: "Date of Birth (YYYY-MM-DD)", text: $dateOfBirth, icon: "calendar")
                            LuxuryTextField(placeholder: "Preferred Language (e.g. en)", text: $preferredLanguage, icon: "character.book.closed")
                            LuxuryTextField(placeholder: "Nationality (2-letter code)", text: $nationality, icon: "globe")
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "square.and.pencil")
                        .font(AppTypography.iconSmall)
                        .foregroundColor(AppColors.accent)
                    Text("Edit Profile")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
        .task {
            await loadProfile()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @MainActor
    private func loadProfile() async {
        isInitialLoading = true
        defer { isInitialLoading = false }

        do {
            let profile = try await ProfileService.shared.fetchMyClientProfile()
            appState.updateCurrentClientProfile(profile)

            firstName = profile.firstName
            lastName = profile.lastName
            email = profile.email
            phone = profile.phone ?? ""
            dateOfBirth = profile.dateOfBirth ?? ""
            preferredLanguage = profile.preferredLanguage ?? ""
            nationality = profile.nationality ?? ""
            addressLine1 = profile.addressLine1 ?? ""
            addressLine2 = profile.addressLine2 ?? ""
            city = profile.city ?? ""
            state = profile.state ?? ""
            postalCode = profile.postalCode ?? ""
            country = profile.country ?? ""
            marketingOptIn = profile.marketingOptIn
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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

        let dob = optionalTrimmed(dateOfBirth)
        if let dob, !isISODate(dob) {
            errorMessage = "Date of birth must use YYYY-MM-DD format."
            showError = true
            return
        }

        isLoading = true
        Task { @MainActor in
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

                try? await Task.sleep(nanoseconds: 900_000_000)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func optionalTrimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isISODate(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) != nil
    }
}

#Preview {
    NavigationStack {
        ClientProfileEditView()
            .environment(AppState())
    }
}
