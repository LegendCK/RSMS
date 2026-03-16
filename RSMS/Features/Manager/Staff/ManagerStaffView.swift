//
//  ManagerStaffView.swift
//  infosys2
//
//  Boutique Manager staff management — roster, shifts, performance.
//  Store-scoped: only shows staff assigned to this boutique.
//

import SwiftUI
import SwiftData
import UIKit

struct ManagerStaffView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("Roster").tag(0)
                        Text("Shifts").tag(1)
                        Text("Performance").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.sm)

                    switch selectedSection {
                    case 0: StaffRosterSubview(storeId: appState.currentStoreId)
                    case 1: StaffShiftsSubview(storeId: appState.currentStoreId)
                    case 2: StaffPerformanceSubview()
                    default: StaffRosterSubview(storeId: appState.currentStoreId)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Staff").font(AppTypography.navTitle).foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }
}

// MARK: - Roster

struct StaffRosterSubview: View {
    let storeId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var allUsers: [User]
    @Query(sort: \StoreLocation.name) private var allStores: [StoreLocation]

    @State private var showCreateStaff = false
    @State private var syncMessage = ""
    @State private var showSyncMessage = false

    private var storeStaff: [User] {
        allUsers
            .filter { $0.role == .salesAssociate || $0.role == .inventoryController || $0.role == .serviceTechnician }
            .filter { user in
                guard let storeId else { return true }
                return user.storeId == storeId
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var storeName: String {
        guard let storeId else { return "Unassigned Boutique" }
        return allStores.first(where: { $0.id == storeId })?.name ?? "Current Boutique"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Boutique Team")
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text(storeName)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Button {
                        showCreateStaff = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(AppTypography.iconSmall)
                            Text("CREATE STAFF")
                                .font(AppTypography.actionSmall)
                                .tracking(0.6)
                        }
                        .foregroundColor(AppColors.textPrimaryDark)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .glassPill()
                        .liquidShadow(LiquidShadow.subtle)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                HStack(spacing: AppSpacing.sm) {
                    rosterStat(value: "\(storeStaff.count)", label: "Total", color: managerAccent)
                    rosterStat(value: "\(storeStaff.filter { $0.isActive }.count)", label: "Active", color: managerSuccess)
                    rosterStat(value: "\(storeStaff.filter { $0.role == .salesAssociate }.count)", label: "Sales", color: managerInfo)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)

                if storeStaff.isEmpty {
                    emptyState
                }

                ForEach(storeStaff) { user in
                    staffCard(user)
                }
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
        .task {
            await syncStaff()
        }
        .sheet(isPresented: $showCreateStaff) {
            ManagerCreateStaffSheet(storeId: storeId, storeName: storeName)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(28)
        }
        .alert("Staff Sync", isPresented: $showSyncMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncMessage)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(AppColors.neutral500)
            Text("No staff assigned yet")
                .font(AppTypography.label)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Create staff accounts for this boutique to get started.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func staffCard(_ user: User) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(roleClr(user.role).opacity(0.15)).frame(width: 48, height: 48)
                Text(initials(user.name)).font(AppTypography.avatarLarge).foregroundColor(roleClr(user.role))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    if !user.isActive {
                        Text("OFF")
                            .font(AppTypography.pico)
                            .foregroundColor(managerOff)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(managerOff.opacity(0.14))
                            .cornerRadius(3)
                    }
                }
                Text(user.email).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                Text(user.role.rawValue).font(AppTypography.roleTag).foregroundColor(roleClr(user.role))
            }
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func roleClr(_ role: UserRole) -> Color {
        switch role {
        case .salesAssociate: return managerInfo
        case .inventoryController: return managerSuccess
        case .serviceTechnician: return managerWarning
        default: return AppColors.neutral400
        }
    }

    private func initials(_ n: String) -> String {
        let p = n.split(separator: " ")
        return p.count >= 2 ? "\(p[0].prefix(1))\(p[1].prefix(1))".uppercased() : String(n.prefix(2)).uppercased()
    }

    private func rosterStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(AppTypography.heading2).foregroundColor(color)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
    }

    private func syncStaff() async {
        do {
            try await StaffSyncService.shared.syncStaff(modelContext: modelContext)
        } catch {
            syncMessage = error.localizedDescription
            showSyncMessage = true
        }
    }

    private var managerInfo: Color { Color(hex: "1E4C8F") }
    private var managerSuccess: Color { Color(hex: "1F6B3A") }
    private var managerWarning: Color { Color(hex: "8A5300") }
    private var managerAccent: Color { Color(hex: "6E3C86") }
    private var managerOff: Color { Color(hex: "7A2E46") }
}

// MARK: - Shifts

struct StaffShiftsSubview: View {
    let storeId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var allUsers: [User]
    @Query(sort: \StaffShift.startAt) private var allShifts: [StaffShift]

    @State private var selectedDate = Date()
    @State private var showCreateShift = false
    @State private var editingShift: StaffShift?
    @State private var syncMessage = ""
    @State private var showSyncMessage = false

    private var storeStaff: [User] {
        allUsers
            .filter { $0.role == .salesAssociate || $0.role == .inventoryController || $0.role == .serviceTechnician }
            .filter { user in
                guard let storeId else { return true }
                return user.storeId == storeId
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var storeShifts: [StaffShift] {
        allShifts
            .filter { shift in
                guard let storeId else { return true }
                return shift.storeId == storeId
            }
            .sorted { $0.startAt < $1.startAt }
    }

    private var selectedDayShifts: [StaffShift] {
        storeShifts.filter { Calendar.current.isDate($0.startAt, inSameDayAs: selectedDate) }
    }

    private func staff(for shift: StaffShift) -> User? {
        storeStaff.first(where: { $0.id == shift.staffUserId })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusLarge)
                .padding(.horizontal, AppSpacing.screenHorizontal)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shifts on \(selectedDate.formatted(.dateTime.day().month().year()))")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("Tap any shift to edit")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Button {
                        showCreateShift = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                                .font(AppTypography.iconSmall)
                            Text("CREATE SHIFT")
                                .font(AppTypography.actionSmall)
                                .tracking(0.6)
                        }
                        .foregroundColor(AppColors.textPrimaryDark)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .glassPill()
                        .liquidShadow(LiquidShadow.subtle)
                    }
                    .disabled(storeId == nil || storeStaff.isEmpty)
                    .opacity((storeId == nil || storeStaff.isEmpty) ? 0.5 : 1)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)

                if selectedDayShifts.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(AppColors.neutral500)
                        Text("No shifts on this date")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("Create a shift to schedule your boutique team.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                } else {
                    ForEach(selectedDayShifts) { shift in
                        Button {
                            editingShift = shift
                        } label: {
                            shiftCard(shift)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .sheet(isPresented: $showCreateShift) {
            if let storeId {
                ShiftEditorSheet(
                    storeId: storeId,
                    staffMembers: storeStaff,
                    existingShifts: storeShifts,
                    shiftToEdit: nil
                )
            }
        }
        .sheet(item: $editingShift) { shift in
            if let storeId {
                ShiftEditorSheet(
                    storeId: storeId,
                    staffMembers: storeStaff,
                    existingShifts: storeShifts,
                    shiftToEdit: shift
                )
            }
        }
        .task {
            await syncShifts()
        }
        .alert("Shift Sync", isPresented: $showSyncMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncMessage)
        }
    }

    private func syncShifts() async {
        do {
            try await StaffShiftSyncService.shared.syncShifts(
                modelContext: modelContext,
                storeId: storeId
            )
        } catch {
            syncMessage = error.localizedDescription
            showSyncMessage = true
        }
    }

    private func shiftCard(_ shift: StaffShift) -> some View {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let name = staff(for: shift)?.name ?? "Unassigned"

        return HStack(spacing: AppSpacing.md) {
            VStack(spacing: 2) {
                Text(shift.startAt.formatted(.dateTime.hour().minute()))
                    .font(AppTypography.actionSmall)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("to")
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textSecondaryDark)
                Text(shift.endAt.formatted(.dateTime.hour().minute()))
                    .font(AppTypography.actionSmall)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .frame(width: 72)
            .padding(.vertical, AppSpacing.xs)
            .background(Color(hex: "F3ECE3"))
            .cornerRadius(AppSpacing.radiusSmall)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(formatter.string(from: shift.startAt, to: shift.endAt))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                if !shift.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(shift.notes)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "square.and.pencil")
                .foregroundColor(Color(hex: "1E4C8F"))
                .font(AppTypography.iconSmall)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Performance

struct StaffPerformanceSubview: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(AppColors.neutral400)
            Text("No Performance Data")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Performance metrics are not yet available.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Shift Editor

struct ShiftEditorSheet: View {
    let storeId: UUID
    let staffMembers: [User]
    let existingShifts: [StaffShift]
    let shiftToEdit: StaffShift?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedStaffId: UUID?
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var notes: String

    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isSaving = false

    init(
        storeId: UUID,
        staffMembers: [User],
        existingShifts: [StaffShift],
        shiftToEdit: StaffShift?
    ) {
        self.storeId = storeId
        self.staffMembers = staffMembers
        self.existingShifts = existingShifts
        self.shiftToEdit = shiftToEdit

        let defaultStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
        let defaultEnd = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date().addingTimeInterval(8 * 3600)

        _selectedStaffId = State(initialValue: shiftToEdit?.staffUserId ?? staffMembers.first?.id)
        _startAt = State(initialValue: shiftToEdit?.startAt ?? defaultStart)
        _endAt = State(initialValue: shiftToEdit?.endAt ?? defaultEnd)
        _notes = State(initialValue: shiftToEdit?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Staff") {
                    Picker("Team Member", selection: Binding(
                        get: { selectedStaffId ?? staffMembers.first?.id ?? UUID() },
                        set: { selectedStaffId = $0 }
                    )) {
                        ForEach(staffMembers) { staff in
                            Text(staff.name).tag(staff.id)
                        }
                    }
                }

                Section("Timing") {
                    DatePicker("Start", selection: $startAt)
                    DatePicker("End", selection: $endAt)
                }

                Section("Notes") {
                    TextField("Optional shift notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(shiftToEdit == nil ? "Create Shift" : "Edit Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveShift()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Shift Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveShift() {
        guard let staffId = selectedStaffId else {
            errorMessage = "Please select a team member."
            showError = true
            return
        }

        guard endAt > startAt else {
            errorMessage = "Shift end time must be after start time."
            showError = true
            return
        }

        if hasOverlap(staffId: staffId, newStart: startAt, newEnd: endAt, excludingShiftId: shiftToEdit?.id) {
            errorMessage = "This staff member already has an overlapping shift."
            showError = true
            return
        }

        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }

            do {
                let dto: StaffShiftDTO
                if let existing = shiftToEdit {
                    dto = try await StaffShiftSyncService.shared.updateShift(
                        id: existing.id,
                        staffUserId: staffId,
                        startAt: startAt,
                        endAt: endAt,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                    )
                } else {
                    dto = try await StaffShiftSyncService.shared.createShift(
                        storeId: storeId,
                        staffUserId: staffId,
                        startAt: startAt,
                        endAt: endAt,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                    )
                }

                StaffShiftSyncService.shared.applyToLocal(dto, modelContext: modelContext)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func hasOverlap(
        staffId: UUID,
        newStart: Date,
        newEnd: Date,
        excludingShiftId: UUID?
    ) -> Bool {
        existingShifts
            .filter { $0.staffUserId == staffId }
            .filter { shift in
                guard let excludingShiftId else { return true }
                return shift.id != excludingShiftId
            }
            .contains { shift in
                newStart < shift.endAt && newEnd > shift.startAt
            }
    }
}

// MARK: - Manager Create Staff

struct ManagerCreateStaffSheet: View {
    let storeId: UUID?
    let storeName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .salesAssociate

    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showDismissAlert = false

    private let roleOptions: [UserRole] = [
        .salesAssociate,
        .serviceTechnician
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.backgroundPrimary, AppColors.backgroundSecondary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {
                        Spacer()
                            .frame(height: AppSpacing.sm)

                        ModernCardView(
                            content: {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Text("Staff Details")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)

                                    HStack(spacing: AppSpacing.md) {
                                        LuxuryTextField(placeholder: "First Name", text: $firstName, icon: "person")
                                        LuxuryTextField(placeholder: "Last Name", text: $lastName, icon: "person")
                                    }

                                    LuxuryTextField(placeholder: "Email", text: $email, icon: "envelope")
                                        .keyboardType(.emailAddress)

                                    LuxuryTextField(placeholder: "Phone", text: $phone, icon: "phone")
                                        .keyboardType(.phonePad)

                                    LuxuryTextField(placeholder: "Temporary Password", text: $password, isSecure: true, icon: "lock")
                                }
                            },
                            glassConfig: .thin,
                            cornerRadius: AppSpacing.radiusLarge
                        )
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        ModernCardView(
                            content: {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Text("Role")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)

                                    Picker("Role", selection: $selectedRole) {
                                        ForEach(roleOptions, id: \.self) { role in
                                            Text(role.rawValue).tag(role)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    Text(roleEmailHint)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)

                                    Text("New staff member will be assigned to this boutique.")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            },
                            glassConfig: .thin,
                            cornerRadius: AppSpacing.radiusLarge
                        )
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        Button {
                            Task { await createStaff() }
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(AppColors.textPrimaryLight)
                                }

                                Text(isSubmitting ? "Creating Staff..." : "Create Staff")
                                    .font(AppTypography.buttonPrimary)
                                    .tracking(0.4)
                            }
                            .foregroundColor(AppColors.textPrimaryLight)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSpacing.touchTarget + 10)
                            .background(AppColors.accent)
                            .cornerRadius(AppSpacing.radiusLarge)
                            .liquidShadow(LiquidShadow.medium)
                        }
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.9 : 1)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.xs)
                    }
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle("Create Staff")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                DismissAttemptInterceptor(
                    isDisabled: hasUnsavedChanges,
                    onAttemptToDismiss: {
                        showDismissAlert = true
                    }
                )
                .frame(width: 0, height: 0)
            )
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("Create Staff", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Discard changes?", isPresented: $showDismissAlert) {
                Button("Keep Editing", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("You have unsaved staff details. Do you want to discard them?")
            }
        }
    }

    @MainActor
    private func createStaff() async {
        guard let storeId else {
            errorMessage = "Your manager account is not assigned to a boutique store."
            showError = true
            return
        }

        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = "\(trimmedFirstName) \(trimmedLastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedFirstName.isEmpty, !trimmedLastName.isEmpty, !trimmedEmail.isEmpty, password.count >= 8 else {
            errorMessage = "First name, last name, email, and an 8+ character password are required."
            showError = true
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await StaffSyncService.shared.createStaffWithAuth(
                name: fullName,
                email: trimmedEmail,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                role: selectedRole,
                //storeId: storeId
            )

            try await StaffSyncService.shared.syncStaff(modelContext: modelContext)
            dismiss()
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("users_email_domain_check") || msg.contains("violates check constraint") {
                if selectedRole == .salesAssociate {
                    errorMessage = "This environment enforces role-email domains. For Sales Associate use an @associate.com email."
                } else if selectedRole == .serviceTechnician {
                    errorMessage = "This environment enforces role-email domains. For After-Sales use an @aftersales.com email."
                } else {
                    errorMessage = "This environment enforces role-email domains. Please use the allowed domain for the selected role."
                }
            } else if msg.contains("row-level security") || msg.contains("permission") {
                errorMessage = "Permission denied by RLS policy while creating staff. Verify manager write policy on users table."
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
    }

    private var roleEmailHint: String {
        switch selectedRole {
        case .salesAssociate:
            return "Role email rule: use @associate.com"
        case .serviceTechnician:
            return "Role email rule: use @aftersales.com"
        default:
            return "Use the role-specific email domain configured in your environment."
        }
    }

    private var hasUnsavedChanges: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !password.isEmpty
    }
}

private struct DismissAttemptInterceptor: UIViewControllerRepresentable {
    let isDisabled: Bool
    let onAttemptToDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let presentationController = uiViewController.parent?.presentationController else {
            return
        }

        context.coordinator.isDisabled = isDisabled
        context.coordinator.onAttemptToDismiss = onAttemptToDismiss
        presentationController.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isDisabled: isDisabled, onAttemptToDismiss: onAttemptToDismiss)
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isDisabled: Bool
        var onAttemptToDismiss: () -> Void

        init(isDisabled: Bool, onAttemptToDismiss: @escaping () -> Void) {
            self.isDisabled = isDisabled
            self.onAttemptToDismiss = onAttemptToDismiss
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            return !isDisabled
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            if isDisabled {
                onAttemptToDismiss()
            }
        }
    }
}

#Preview {
    ManagerStaffView()
        .modelContainer(for: [User.self, StoreLocation.self, StaffShift.self], inMemory: true)
}
