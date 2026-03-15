//
//  CreateClientProfileView.swift
//  infosys2
//

import SwiftUI

import SwiftUI

struct CreateClientProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var vm = CreateClientProfileViewModel()

    /// Local Date state for the DOB picker — synced to vm.dateOfBirth (String) via onChange.
    @State private var dobDate: Date = Calendar.current.date(
        byAdding: .year, value: -30, to: Date()
    ) ?? Date()

    var onSave: (() -> Void)?

    private let communicationOptions = ["Email", "Phone", "SMS", "WhatsApp"]
    private let segments = ["standard", "silver", "gold", "vip", "ultra_vip"]

    // MARK: - ISO date formatter (yyyy-MM-dd — required by Supabase)
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Creates a two-way Date ↔ String binding for a specific anniversary index.
    private func anniversaryDateBinding(for index: Int) -> Binding<Date> {
        Binding<Date>(
            get: {
                Self.isoFormatter.date(from: vm.anniversaries[index].date) ?? Date()
            },
            set: { newDate in
                vm.anniversaries[index].date = Self.isoFormatter.string(from: newDate)
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                
                if vm.currentStep == 1 {
                    stepOneView
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                } else {
                    stepTwoView
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("NEW CLIENT (\(vm.currentStep)/2)")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.currentStep == 2 {
                        Button {
                            withAnimation { vm.currentStep = 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(AppColors.textPrimaryDark)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
            .alert("Validation Error", isPresented: $vm.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(vm.errorMessage)
            }
        }
    }
    
    // MARK: - Step 1
    private var stepOneView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xl) {
                // Header
                formHeader(title: "Personal Details", subtitle: "Please provide the client's core contact information.")
                
                // Personal Details
                LuxuryCardView {
                    VStack(spacing: AppSpacing.md) {
                        LuxuryTextField(placeholder: "First Name *", text: $vm.firstName, icon: "person")
                        LuxuryTextField(placeholder: "Last Name *", text: $vm.lastName, icon: "person")
                        LuxuryTextField(placeholder: "Email *", text: $vm.email, icon: "envelope")
                            .keyboardType(.emailAddress)
                        LuxuryTextField(placeholder: "Phone", text: $vm.phone, icon: "phone")
                            .keyboardType(.phonePad)
                        // Calendar picker — eliminates manual YYYY-MM-DD entry and format errors
                        LuxuryDatePicker(label: "Date of Birth", date: $dobDate, maximumDate: Date())
                            .onChange(of: dobDate) { _, newDate in
                                vm.dateOfBirth = Self.isoFormatter.string(from: newDate)
                            }
                            .onAppear {
                                // Seed vm.dateOfBirth with the initial picker value
                                vm.dateOfBirth = Self.isoFormatter.string(from: dobDate)
                            }
                    }
                    .padding(AppSpacing.cardPadding)
                }
                
                // Address
                sectionHeader("ADDRESS")
                LuxuryCardView {
                    VStack(spacing: AppSpacing.md) {
                        LuxuryTextField(placeholder: "Address Line 1", text: $vm.addressLine1)
                        LuxuryTextField(placeholder: "Address Line 2", text: $vm.addressLine2)
                        HStack(spacing: AppSpacing.md) {
                            LuxuryTextField(placeholder: "City", text: $vm.city)
                            LuxuryTextField(placeholder: "State", text: $vm.state)
                        }
                        HStack(spacing: AppSpacing.md) {
                            LuxuryTextField(placeholder: "Zip/Postal", text: $vm.postalCode)
                            LuxuryTextField(placeholder: "Country", text: $vm.country)
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                }
                
                // Next Button
                PrimaryButton(title: "Next Step") {
                    withAnimation { vm.goNextStep() }
                }
                .padding(.top, AppSpacing.md)
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }
    
    // MARK: - Step 2
    private var stepTwoView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xl) {
                // Header
                formHeader(title: "Preferences & Sizes", subtitle: "Customize the profile for personalized service.")
                
                // Preferences
                sectionHeader("PREFERENCES")
                LuxuryCardView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Interested Categories")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        
                        FlowLayout(spacing: AppSpacing.xs) {
                            ForEach(vm.availableCategories, id: \.self) { cat in
                                categoryPill(cat)
                            }
                        }
                        
                        HStack {
                            TextField("Add Custom Category...", text: $vm.newCategoryText)
                                .font(AppTypography.bodyMedium)
                                .textFieldStyle(.plain)
                            Button {
                                vm.addNewCategory()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(vm.newCategoryText.isEmpty ? AppColors.neutral300 : AppColors.accent)
                            }
                            .disabled(vm.newCategoryText.isEmpty)
                        }
                        .padding(AppSpacing.xs)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusSmall)
                        
                        GoldDivider().padding(.vertical, AppSpacing.xs)
                        
                        Text("Favorite Brands")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        
                        if !vm.preferredBrands.isEmpty {
                            FlowLayout(spacing: AppSpacing.xs) {
                                ForEach(vm.preferredBrands, id: \.self) { brand in
                                    HStack(spacing: 4) {
                                        Text(brand)
                                            .font(AppTypography.caption)
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(AppColors.accent)
                                    .foregroundColor(.white)
                                    .cornerRadius(AppSpacing.radiusSmall)
                                    .onTapGesture {
                                        vm.removeBrand(brand)
                                    }
                                }
                            }
                        }
                        
                        HStack {
                            TextField("Add Brand...", text: $vm.newBrandText)
                                .font(AppTypography.bodyMedium)
                                .textFieldStyle(.plain)
                            Button {
                                vm.addBrand()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(vm.newBrandText.isEmpty ? AppColors.neutral300 : AppColors.accent)
                            }
                            .disabled(vm.newBrandText.isEmpty)
                        }
                        .padding(AppSpacing.xs)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusSmall)
                        
                        GoldDivider().padding(.vertical, AppSpacing.xs)
                        
                        Text("Communication Preference")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        
                        Picker("", selection: $vm.communicationPreference) {
                            ForEach(communicationOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(AppSpacing.cardPadding)
                }
                
                // Sizes
                sectionHeader("SIZES & MEASUREMENTS")
                LuxuryCardView {
                    VStack(spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.md) {
                            LuxuryTextField(placeholder: "Ring", text: $vm.sizeRing)
                            LuxuryTextField(placeholder: "Wrist", text: $vm.sizeWrist)
                        }
                        HStack(spacing: AppSpacing.md) {
                            LuxuryTextField(placeholder: "Shoe", text: $vm.sizeShoe)
                            LuxuryTextField(placeholder: "Dress/Suit", text: $vm.sizeDress)
                        }
                        LuxuryTextField(placeholder: "Jacket", text: $vm.sizeJacket)
                    }
                    .padding(AppSpacing.cardPadding)
                }
                
                // Anniversaries
                sectionHeader("ANNIVERSARIES & EVENTS")
                LuxuryCardView {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(vm.anniversaries.indices, id: \.self) { index in
                            HStack(spacing: AppSpacing.sm) {
                                TextField("Label (e.g. Wedding)", text: $vm.anniversaries[index].label)
                                    .textFieldStyle(.plain)
                                    .font(AppTypography.bodyMedium)
                                    .padding(AppSpacing.xs)
                                    .background(AppColors.backgroundSecondary)
                                    .cornerRadius(4)

                                // Calendar picker — no free-text date entry
                                DatePicker(
                                    "",
                                    selection: anniversaryDateBinding(for: index),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppColors.accent)
                                .frame(maxWidth: 130)
                                .padding(.horizontal, AppSpacing.xs)
                                .background(AppColors.backgroundSecondary)
                                .cornerRadius(4)

                                Button {
                                    vm.removeAnniversary(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(AppColors.error)
                                }
                            }
                        }
                        
                        Button {
                            vm.addAnniversary()
                        } label: {
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
                
                // Admin & Privacy
                sectionHeader("ADMIN & PRIVACY")
                LuxuryCardView {
                    VStack(spacing: AppSpacing.md) {
                        HStack {
                            Text("Client Segment")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Spacer()
                            Picker("", selection: $vm.segment) {
                                ForEach(segments, id: \.self) { segment in
                                    Text(segment.capitalized.replacingOccurrences(of: "_", with: " ")).tag(segment)
                                }
                            }
                            .tint(AppColors.textPrimaryDark)
                        }
                        
                        GoldDivider().padding(.vertical, AppSpacing.xs)
                        
                        Toggle("Privacy Policy / GDPR Consent *", isOn: $vm.gdprConsent)
                            .font(AppTypography.bodyMedium)
                            .tint(AppColors.accent)
                        
                        Toggle("Marketing Opt-In", isOn: $vm.marketingOptIn)
                            .font(AppTypography.bodyMedium)
                            .tint(AppColors.accent)
                    }
                    .padding(AppSpacing.cardPadding)
                }
                
                // Submit Button
                PrimaryButton(title: "Create Profile", isLoading: vm.isLoading) {
                    Task {
                        if let _ = await vm.save(creatorId: appState.currentUserProfile?.id) {
                            onSave?()
                            dismiss()
                        }
                    }
                }
                .padding(.top, AppSpacing.md)
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }
    
    // MARK: - View Helpers
    
    private func categoryPill(_ cat: String) -> some View {
        let isSelected = vm.preferredCategories.contains(cat)
        return Text(cat)
            .font(AppTypography.caption)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(isSelected ? AppColors.accent : AppColors.backgroundSecondary)
            .foregroundColor(isSelected ? .white : AppColors.textPrimaryDark)
            .cornerRadius(AppSpacing.radiusSmall)
            .onTapGesture {
                vm.toggleCategory(cat)
            }
    }
    
    private func formHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "person.badge.plus")
                .font(AppTypography.iconAction)
                .foregroundColor(AppColors.accent)
            Text(title)
                .font(AppTypography.heading2)
                .foregroundColor(AppColors.textPrimaryDark)
            Text(subtitle)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppSpacing.md)
    }
    
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.md)
    }
}

// FlowLayout for dynamic pill wrapping
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                // Wrap
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height = currentY + rowHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(width: size.width, height: size.height))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
