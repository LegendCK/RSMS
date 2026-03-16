//
//  ClientEditView.swift
//  RSMS
//
//  Edit sheet for updating a client profile (personal details + preferences + sizes).
//  Opened as a sheet from ClientDetailView.
//

import SwiftUI

struct ClientEditView: View {
    @Bindable var vm: ClientDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let segments = ["standard", "silver", "gold", "vip", "ultra_vip"]
    private let communicationOptions = ["Email", "Phone", "SMS", "WhatsApp"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // Personal Details
                        sectionHeader("PERSONAL DETAILS")
                        LuxuryCardView {
                            VStack(spacing: AppSpacing.md) {
                                LuxuryTextField(placeholder: "First Name *", text: $vm.editFirstName, icon: "person")
                                LuxuryTextField(placeholder: "Last Name *", text: $vm.editLastName, icon: "person")
                                LuxuryTextField(placeholder: "Phone", text: $vm.editPhone, icon: "phone")
                                    .keyboardType(.phonePad)
                                LuxuryDatePicker(label: "Date of Birth", date: $vm.editDobDate, maximumDate: Date())
                                LuxuryMenuPicker(
                                    label: "Nationality",
                                    icon: "globe",
                                    items: LuxuryPickerItem.nationalities,
                                    selection: $vm.editNationality
                                )
                                LuxuryMenuPicker(
                                    label: "Preferred Language",
                                    icon: "text.bubble",
                                    items: LuxuryPickerItem.languages,
                                    selection: $vm.editPreferredLanguage
                                )
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        // Address
                        sectionHeader("ADDRESS")
                        LuxuryCardView {
                            VStack(spacing: AppSpacing.md) {
                                LuxuryTextField(placeholder: "Address Line 1", text: $vm.editAddressLine1)
                                LuxuryTextField(placeholder: "Address Line 2", text: $vm.editAddressLine2)
                                HStack(spacing: AppSpacing.md) {
                                    LuxuryTextField(placeholder: "City", text: $vm.editCity)
                                    LuxuryTextField(placeholder: "State", text: $vm.editState)
                                }
                                HStack(spacing: AppSpacing.md) {
                                    LuxuryTextField(placeholder: "Zip/Postal", text: $vm.editPostalCode)
                                    LuxuryTextField(placeholder: "Country", text: $vm.editCountry)
                                }
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        // Segment & Privacy
                        sectionHeader("ADMIN")
                        LuxuryCardView {
                            VStack(spacing: AppSpacing.md) {
                                HStack {
                                    Text("Client Segment")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Spacer()
                                    Picker("", selection: $vm.editSegment) {
                                        ForEach(segments, id: \.self) { seg in
                                            Text(seg.replacingOccurrences(of: "_", with: " ").capitalized).tag(seg)
                                        }
                                    }
                                    .tint(AppColors.textPrimaryDark)
                                }
                                GoldDivider()
                                Toggle("Marketing Opt-In", isOn: $vm.editMarketingOptIn)
                                    .font(AppTypography.bodyMedium)
                                    .tint(AppColors.accent)
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        // Preferences
                        sectionHeader("PREFERENCES")
                        LuxuryCardView {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Text("Interested Categories")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                FlowLayout(spacing: AppSpacing.xs) {
                                    ForEach(vm.availableCategories, id: \.self) { cat in
                                        let selected = vm.editPreferredCategories.contains(cat)
                                        Text(cat)
                                            .font(AppTypography.caption)
                                            .padding(.horizontal, AppSpacing.sm).padding(.vertical, 4)
                                            .background(selected ? AppColors.accent : AppColors.backgroundSecondary)
                                            .foregroundColor(selected ? .white : AppColors.textPrimaryDark)
                                            .cornerRadius(AppSpacing.radiusSmall)
                                            .onTapGesture { vm.toggleCategory(cat) }
                                    }
                                }

                                GoldDivider()

                                Text("Favourite Brands")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                if !vm.editPreferredBrands.isEmpty {
                                    FlowLayout(spacing: AppSpacing.xs) {
                                        ForEach(vm.editPreferredBrands, id: \.self) { brand in
                                            HStack(spacing: 4) {
                                                Text(brand).font(AppTypography.caption)
                                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                            }
                                            .padding(.horizontal, AppSpacing.sm).padding(.vertical, 4)
                                            .background(AppColors.accent).foregroundColor(.white)
                                            .cornerRadius(AppSpacing.radiusSmall)
                                            .onTapGesture { vm.removeBrand(brand) }
                                        }
                                    }
                                }
                                HStack {
                                    TextField("Add Brand...", text: $vm.newBrandText)
                                        .font(AppTypography.bodyMedium).textFieldStyle(.plain)
                                    Button { vm.addBrand() } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(vm.newBrandText.isEmpty ? AppColors.neutral300 : AppColors.accent)
                                    }
                                    .disabled(vm.newBrandText.isEmpty)
                                }
                                .padding(AppSpacing.xs)
                                .background(AppColors.backgroundSecondary)
                                .cornerRadius(AppSpacing.radiusSmall)

                                GoldDivider()

                                Text("Communication Preference")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Picker("", selection: $vm.editCommunicationPreference) {
                                    ForEach(communicationOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        // Sizes
                        sectionHeader("SIZES")
                        LuxuryCardView {
                            VStack(spacing: AppSpacing.md) {
                                HStack(spacing: AppSpacing.md) {
                                    LuxuryTextField(placeholder: "Ring", text: $vm.editSizeRing)
                                    LuxuryTextField(placeholder: "Wrist", text: $vm.editSizeWrist)
                                }
                                HStack(spacing: AppSpacing.md) {
                                    LuxuryTextField(placeholder: "Shoe", text: $vm.editSizeShoe)
                                    LuxuryTextField(placeholder: "Dress/Suit", text: $vm.editSizeDress)
                                }
                                LuxuryTextField(placeholder: "Jacket", text: $vm.editSizeJacket)
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        // Anniversaries
                        sectionHeader("ANNIVERSARIES & EVENTS")
                        LuxuryCardView {
                            VStack(spacing: AppSpacing.md) {
                                ForEach(vm.editAnniversaries.indices, id: \.self) { idx in
                                    HStack(spacing: AppSpacing.sm) {
                                        TextField("Label", text: $vm.editAnniversaries[idx].label)
                                            .font(AppTypography.bodyMedium).textFieldStyle(.plain)
                                            .padding(AppSpacing.xs)
                                            .background(AppColors.backgroundSecondary)
                                            .cornerRadius(4)
                                        DatePicker("", selection: vm.anniversaryDateBinding(for: idx), displayedComponents: .date)
                                            .datePickerStyle(.compact).labelsHidden()
                                            .tint(AppColors.accent)
                                            .frame(maxWidth: 130)
                                            .padding(.horizontal, AppSpacing.xs)
                                            .background(AppColors.backgroundSecondary)
                                            .cornerRadius(4)
                                        Button { vm.removeAnniversary(at: idx) } label: {
                                            Image(systemName: "trash").foregroundColor(AppColors.error)
                                        }
                                    }
                                }
                                Button { vm.addAnniversary() } label: {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("Add Event")
                                    }
                                    .font(AppTypography.actionLink)
                                    .foregroundColor(AppColors.accent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        // Free-form notes
                        sectionHeader("ASSOCIATE NOTES")
                        LuxuryCardView {
                            TextEditor(text: $vm.editFreeNotes)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(minHeight: 80)
                                .padding(AppSpacing.xs)
                        }

                        // Save button
                        PrimaryButton(title: "Save Changes", isLoading: vm.isSaving) {
                            Task { await vm.saveEdits() }
                        }
                        .padding(.top, AppSpacing.md)

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT PROFILE")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { vm.cancelEditing() }
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.sm)
    }
}
