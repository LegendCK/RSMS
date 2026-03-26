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
        .managerStaffCardSurface(cornerRadius: AppSpacing.radiusMedium)
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
        .managerStaffCardSurface(cornerRadius: AppSpacing.radiusMedium)
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
    @State private var showAutoAssign = false
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
                VStack(spacing: AppSpacing.xs) {
                    HStack {
                        Text("Schedule Date")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Spacer()
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppColors.accent)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Button {
                            shiftDay(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(AppTypography.iconSmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(width: 32, height: 32)
                                .background(AppColors.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                        }
                        .buttonStyle(.plain)

                        Text(selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .frame(maxWidth: .infinity)

                        Button {
                            shiftDay(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(AppTypography.iconSmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .frame(width: 32, height: 32)
                                .background(AppColors.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedDate = Date()
                        } label: {
                            Text("Today")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 7)
                                .glassPill()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.sm)
                .managerStaffCardSurface(cornerRadius: AppSpacing.radiusMedium)
                .padding(.horizontal, AppSpacing.screenHorizontal)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shifts on \(selectedDate.formatted(.dateTime.day().month().year()))")
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("Auto-assign or tap any shift to edit manually")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Button {
                        showAutoAssign = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(AppTypography.iconSmall)
                            Text("AUTO ASSIGN")
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
        .sheet(isPresented: $showAutoAssign) {
            if let storeId {
                AutoAssignShiftsSheet(
                    storeId: storeId,
                    anchorDate: selectedDate,
                    staffMembers: storeStaff,
                    existingShifts: storeShifts
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
        .managerStaffCardSurface(cornerRadius: AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func shiftDay(by offset: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) {
            selectedDate = next
        }
    }
}

private enum AutoAssignShiftTemplate: String, CaseIterable, Identifiable {
    case fullDay = "Full Day"
    case splitDay = "Split Day"

    var id: String { rawValue }
}

private struct AutoAssignedShiftDraft: Identifiable {
    let id = UUID()
    let staffUserId: UUID
    let startAt: Date
    let endAt: Date
    let notes: String
}

struct AutoAssignShiftsSheet: View {
    let storeId: UUID
    let anchorDate: Date
    let staffMembers: [User]
    let existingShifts: [StaffShift]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var windowDays: Int = 14
    @State private var template: AutoAssignShiftTemplate = .fullDay
    @State private var drafts: [AutoAssignedShiftDraft] = []
    @State private var isGenerating = false
    @State private var isApplying = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var activeStaff: [User] {
        let active = staffMembers.filter { $0.isActive }
        return active.isEmpty ? staffMembers : active
    }

    private var availableRoles: Set<UserRole> {
        Set(activeStaff.map(\.role))
    }

    private var requiredCoverageRoles: [UserRole] {
        var roles: [UserRole] = []
        if availableRoles.contains(.salesAssociate) { roles.append(.salesAssociate) }
        if availableRoles.contains(.inventoryController) { roles.append(.inventoryController) }
        if availableRoles.contains(.serviceTechnician) { roles.append(.serviceTechnician) }
        return roles
    }

    private var daySlots: [(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int)] {
        switch template {
        case .fullDay:
            return [(10, 0, 18, 0)]
        case .splitDay:
            return [(10, 0, 14, 0), (14, 0, 18, 0)]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Auto Assign Setup") {
                    Picker("Range", selection: $windowDays) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                    .pickerStyle(.segmented)

                    Picker("Shift Pattern", selection: $template) {
                        ForEach(AutoAssignShiftTemplate.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Hybrid mode: role-aware baseline coverage with balanced distribution across staff.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Section {
                    Button {
                        Task { await generateDrafts() }
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView()
                            }
                            Text(isGenerating ? "Generating..." : "Generate Auto-Assign Plan")
                        }
                    }
                    .disabled(isGenerating || isApplying || activeStaff.isEmpty)
                }

                Section("Preview (\(drafts.count) Shifts)") {
                    if drafts.isEmpty {
                        Text("Generate a plan to preview assignments before applying.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    } else {
                        ForEach(drafts.prefix(40)) { draft in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(staffName(for: draft.staffUserId))
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text("\(draft.startAt.formatted(date: .abbreviated, time: .shortened)) - \(draft.endAt.formatted(date: .omitted, time: .shortened))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                Text(draft.notes)
                                    .font(AppTypography.micro)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        }

                        if drafts.count > 40 {
                            Text("+\(drafts.count - 40) more shifts")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                    }
                }
            }
            .navigationTitle("Auto Assign Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await applyDrafts() }
                    } label: {
                        if isApplying {
                            ProgressView()
                        } else {
                            Text("Apply")
                        }
                    }
                    .disabled(drafts.isEmpty || isApplying || isGenerating)
                }
            }
            .alert("Auto Assign", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    @MainActor
    private func generateDrafts() async {
        guard !activeStaff.isEmpty else {
            errorMessage = "No staff available for auto-assignment."
            showError = true
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: anchorDate)

        var generated: [AutoAssignedShiftDraft] = []
        var loadByStaff: [UUID: Int] = [:]
        var slotLoadByStaff: [UUID: [Int: Int]] = [:]

        for staff in activeStaff {
            loadByStaff[staff.id] = existingShifts.filter { $0.staffUserId == staff.id }.count
            slotLoadByStaff[staff.id] = [:]
        }

        for offset in 0..<windowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            var assignedToday = Set<UUID>()

            for role in requiredCoverageRoles {
                let candidates = activeStaff.filter { $0.role == role && !assignedToday.contains($0.id) }
                guard let selected = pickCandidate(candidates: candidates, loadByStaff: loadByStaff) else { continue }

                let slotIndex = pickSlotIndex(for: selected.id, slotLoadByStaff: slotLoadByStaff)
                let slot = daySlots[min(slotIndex, daySlots.count - 1)]
                guard let startAt = calendar.date(bySettingHour: slot.startHour, minute: slot.startMinute, second: 0, of: day),
                      let endAt = calendar.date(bySettingHour: slot.endHour, minute: slot.endMinute, second: 0, of: day)
                else { continue }

                if hasConflict(staffId: selected.id, startAt: startAt, endAt: endAt, generated: generated) {
                    continue
                }

                generated.append(AutoAssignedShiftDraft(
                    staffUserId: selected.id,
                    startAt: startAt,
                    endAt: endAt,
                    notes: "Auto-assigned: role coverage"
                ))

                assignedToday.insert(selected.id)
                loadByStaff[selected.id, default: 0] += 1
                var slotLoads = slotLoadByStaff[selected.id, default: [:]]
                slotLoads[slotIndex, default: 0] += 1
                slotLoadByStaff[selected.id] = slotLoads
            }

            let extraCandidates = activeStaff.filter { !assignedToday.contains($0.id) }
            if let extra = pickCandidate(candidates: extraCandidates, loadByStaff: loadByStaff) {
                let slotIndex = pickSlotIndex(for: extra.id, slotLoadByStaff: slotLoadByStaff)
                let slot = daySlots[min(slotIndex, daySlots.count - 1)]
                if let startAt = calendar.date(bySettingHour: slot.startHour, minute: slot.startMinute, second: 0, of: day),
                   let endAt = calendar.date(bySettingHour: slot.endHour, minute: slot.endMinute, second: 0, of: day),
                   !hasConflict(staffId: extra.id, startAt: startAt, endAt: endAt, generated: generated) {
                    generated.append(AutoAssignedShiftDraft(
                        staffUserId: extra.id,
                        startAt: startAt,
                        endAt: endAt,
                        notes: "Auto-assigned: balanced distribution"
                    ))

                    loadByStaff[extra.id, default: 0] += 1
                    var slotLoads = slotLoadByStaff[extra.id, default: [:]]
                    slotLoads[slotIndex, default: 0] += 1
                    slotLoadByStaff[extra.id] = slotLoads
                }
            }
        }

        if generated.isEmpty {
            errorMessage = "No shifts were generated. Try a different pattern or date range."
            showError = true
        }

        drafts = generated.sorted { $0.startAt < $1.startAt }
    }

    @MainActor
    private func applyDrafts() async {
        guard !drafts.isEmpty else { return }

        isApplying = true
        defer { isApplying = false }

        do {
            for draft in drafts {
                let dto = try await StaffShiftSyncService.shared.createShift(
                    storeId: storeId,
                    staffUserId: draft.staffUserId,
                    startAt: draft.startAt,
                    endAt: draft.endAt,
                    notes: draft.notes
                )
                StaffShiftSyncService.shared.applyToLocal(dto, modelContext: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func pickCandidate(candidates: [User], loadByStaff: [UUID: Int]) -> User? {
        candidates.sorted {
            let lhsLoad = loadByStaff[$0.id, default: 0]
            let rhsLoad = loadByStaff[$1.id, default: 0]
            if lhsLoad != rhsLoad { return lhsLoad < rhsLoad }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }.first
    }

    private func pickSlotIndex(for staffId: UUID, slotLoadByStaff: [UUID: [Int: Int]]) -> Int {
        let loads = slotLoadByStaff[staffId, default: [:]]
        return daySlots.indices.min { loads[$0, default: 0] < loads[$1, default: 0] } ?? 0
    }

    private func hasConflict(
        staffId: UUID,
        startAt: Date,
        endAt: Date,
        generated: [AutoAssignedShiftDraft]
    ) -> Bool {
        let existingConflict = existingShifts
            .filter { $0.staffUserId == staffId }
            .contains { startAt < $0.endAt && endAt > $0.startAt }

        if existingConflict { return true }

        return generated
            .filter { $0.staffUserId == staffId }
            .contains { startAt < $0.endAt && endAt > $0.startAt }
    }

    private func staffName(for id: UUID) -> String {
        staffMembers.first(where: { $0.id == id })?.name ?? "Unknown"
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

private extension View {
    func managerStaffCardSurface(cornerRadius: CGFloat = AppSpacing.radiusMedium) -> some View {
        self
            .background(AppColors.backgroundSecondary.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.border.opacity(0.2), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
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
    @State private var corporateEmail = ""
    @State private var personalEmail = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .salesAssociate

    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showDismissAlert = false

    private let roleOptions: [UserRole] = [
        .salesAssociate,
        .inventoryController,
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

                                    LuxuryTextField(placeholder: "Corporate Email (@maisonluxe.me)", text: $corporateEmail, icon: "building.2")
                                        .keyboardType(.emailAddress)

                                    LuxuryTextField(placeholder: "Personal Email (Gmail, etc.)", text: $personalEmail, icon: "envelope")
                                        .keyboardType(.emailAddress)

                                    LuxuryTextField(placeholder: "Phone", text: $phone, icon: "phone")
                                        .keyboardType(.phonePad)

                                    LuxuryTextField(placeholder: "Temporary Password", text: $password, isSecure: true, icon: "lock")
                                }
                            },
                            glassConfig: .thin,
                            cornerRadius: AppSpacing.radiusMedium,
                            showShadow: false,
                            borderColor: AppColors.textPrimaryDark.opacity(0.12),
                            borderWidth: 0.75
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 8)
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
                            cornerRadius: AppSpacing.radiusMedium,
                            showShadow: false,
                            borderColor: AppColors.textPrimaryDark.opacity(0.12),
                            borderWidth: 0.75
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 8)
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
        guard storeId != nil else {
            errorMessage = "Your manager account is not assigned to a boutique store."
            showError = true
            return
        }

        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = "\(trimmedFirstName) \(trimmedLastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCorporateEmail = corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPersonalEmail  = personalEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedFirstName.isEmpty, !trimmedLastName.isEmpty,
              !trimmedCorporateEmail.isEmpty, !trimmedPersonalEmail.isEmpty,
              password.count >= 8 else {
            errorMessage = "First name, last name, both emails, and an 8+ character password are required."
            showError = true
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await StaffSyncService.shared.createStaffWithAuth(
                name: fullName,
                email: trimmedCorporateEmail,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                role: selectedRole,
                storeId: storeId,
                corporateEmail: trimmedCorporateEmail,
                personalEmail: trimmedPersonalEmail
            )

            try await StaffSyncService.shared.syncStaff(modelContext: modelContext)
            dismiss()
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("users_email_domain_check") || msg.contains("violates check constraint") {
                if selectedRole == .salesAssociate {
                    errorMessage = "This environment enforces role-email domains. For Sales Associate use an @associate.com email."
                } else if selectedRole == .inventoryController {
                    errorMessage = "This environment enforces role-email domains. For Inventory Controller use the inventory domain configured for your org."
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
        case .inventoryController:
            return "Role email rule: use your org's inventory-controller domain"
        case .serviceTechnician:
            return "Role email rule: use @aftersales.com"
        default:
            return "Use the role-specific email domain configured in your environment."
        }
    }

    private var hasUnsavedChanges: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !personalEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
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
