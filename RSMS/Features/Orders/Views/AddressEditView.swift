//
//  AddressEditView.swift
//  RSMS
//
//  Form to add or edit a SavedAddress.
//

import SwiftUI
import SwiftData

struct AddressEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // Pass nil to create new; pass existing address to edit
    var address: SavedAddress?

    @State private var label:   String = "Home"
    @State private var line1:   String = ""
    @State private var line2:   String = ""
    @State private var city:    String = ""
    @State private var state:   String = ""
    @State private var zip:     String = ""
    @State private var country: String = "IN"
    @State private var isDefault: Bool = false
    @State private var showValidationError = false

    private let labelOptions = ["Home", "Work", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {

                        // Label picker
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sectionHeader("ADDRESS LABEL")
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(labelOptions, id: \.self) { opt in
                                    Button(action: { label = opt }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: labelIcon(opt))
                                                .font(.system(size: 13))
                                            Text(opt)
                                                .font(AppTypography.label)
                                        }
                                        .foregroundColor(label == opt ? AppColors.textPrimaryLight : AppColors.textPrimaryDark)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(label == opt ? AppColors.accent : AppColors.backgroundSecondary)
                                        .cornerRadius(AppSpacing.radiusMedium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                                .stroke(label == opt ? AppColors.accent : AppColors.border.opacity(0.5), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }

                        // Street
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sectionHeader("STREET")
                            LuxuryTextField(placeholder: "Address Line 1*", text: $line1)
                            LuxuryTextField(placeholder: "Apartment, Suite, etc. (Optional)", text: $line2)
                        }

                        // City / State / ZIP
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sectionHeader("CITY & PINCODE")
                            LuxuryTextField(placeholder: "City*", text: $city)
                            HStack(spacing: AppSpacing.sm) {
                                LuxuryTextField(placeholder: "State*", text: $state)
                                LuxuryTextField(placeholder: "PIN*", text: $zip)
                                    .keyboardType(.numberPad)
                                    .frame(maxWidth: 120)
                            }
                            LuxuryTextField(placeholder: "Country", text: $country)
                        }

                        // Default toggle
                        Toggle(isOn: $isDefault) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Set as default")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text("Used automatically at checkout")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }
                        .tint(AppColors.accent)
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)

                        if showValidationError {
                            Text("Please fill in all required fields (*).")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(title: address == nil ? "Save Address" : "Update Address") {
                            save()
                        }
                        .padding(.top, AppSpacing.sm)

                        Spacer().frame(height: AppSpacing.xxl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(address == nil ? "New Address" : "Edit Address")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accent)
                }
            }
            .onAppear { populate() }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
    }

    private func labelIcon(_ l: String) -> String {
        switch l {
        case "Home": return "house.fill"
        case "Work": return "briefcase.fill"
        default:     return "mappin.circle.fill"
        }
    }

    private func populate() {
        guard let a = address else { return }
        label     = a.label
        line1     = a.line1
        line2     = a.line2
        city      = a.city
        state     = a.state
        zip       = a.zip
        country   = a.country
        isDefault = a.isDefault
    }

    private func save() {
        guard !line1.isEmpty, !city.isEmpty, !state.isEmpty, !zip.isEmpty else {
            showValidationError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        let currentId: UUID
        if let a = address {
            a.label     = label
            a.line1     = line1
            a.line2     = line2
            a.city      = city
            a.state     = state
            a.zip       = zip
            a.country   = country
            a.isDefault = isDefault
            currentId = a.id
        } else {
            let a = SavedAddress(
                customerEmail: appState.currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                label: label,
                line1: line1,
                line2: line2,
                city: city,
                state: state,
                zip: zip,
                country: country,
                isDefault: isDefault
            )
            modelContext.insert(a)
            currentId = a.id
        }

        // Ensure only one default address exists for this user.
        if isDefault {
            let all = (try? modelContext.fetch(FetchDescriptor<SavedAddress>())) ?? []
            let mine = all.filter {
                $0.customerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    == appState.currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            for addr in mine where addr.id != currentId {
                addr.isDefault = false
            }
        }

        try? modelContext.save()

        // Best-effort sync of the default address to Supabase client profile.
        if !appState.isGuest,
           let clientId = appState.currentUserProfile?.id ?? appState.currentClientProfile?.id,
           isDefault {
            let all = (try? modelContext.fetch(FetchDescriptor<SavedAddress>())) ?? []
            if let defaultAddr = all.first(where: {
                $0.customerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    == appState.currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    && $0.isDefault
            }) {
                Task {
                    await AddressSyncService.shared.syncDefaultAddressToClient(address: defaultAddr, clientId: clientId)
                }
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
