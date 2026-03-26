//
//  OrganizationView.swift
//  infosys2
//
//  Enterprise organization — boutique locations, staff management, role access templates.
//

import SwiftUI
import SwiftData

struct OrganizationView: View {
    @State private var selectedSection = 0

    @State private var showCreateBoutique = false
    @State private var showCreateStaff = false
    @State private var showCreateRole = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("", selection: $selectedSection) {
                    Text("Boutiques").tag(0)
                    Text("Staff").tag(1)
                    Text("Roles").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)

                switch selectedSection {
                case 0:
                    OrgBoutiquesSubview(showCreateBoutique: $showCreateBoutique)
                case 1:
                    OrgStaffSubview(showCreateStaff: $showCreateStaff)
                case 2:
                    OrgRolesSubview(showCreateRole: $showCreateRole)
                default:
                    OrgBoutiquesSubview(showCreateBoutique: $showCreateBoutique)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Organization")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: handleCreateTap) {
                    Image(systemName: "plus.circle.fill")
                        .font(AppTypography.toolbarIcon)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func handleCreateTap() {
        switch selectedSection {
        case 0: showCreateBoutique = true
        case 1: showCreateStaff = true
        case 2: showCreateRole = true
        default: break
        }
    }
}

// MARK: - Boutiques

struct OrgBoutiquesSubview: View {
    @Binding var showCreateBoutique: Bool
    @Query(sort: \StoreLocation.name) private var stores: [StoreLocation]
    @Query(sort: \User.createdAt, order: .reverse) private var allUsers: [User]
    @Environment(\.modelContext) private var modelContext

    @State private var editingStore: StoreLocation?
    @State private var syncMessage: String?
    @State private var isSyncing = false

    private var boutiqueStores: [StoreLocation] {
        stores.filter { $0.type == .boutique }
    }

    private var activeStores: [StoreLocation] {
        boutiqueStores.filter { $0.isOperational }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    statPill(value: "\(activeStores.count)", label: "Active", color: AppColors.success)
                    statPill(value: "\(boutiqueStores.reduce(0) { $0 + max(1, $1.capacityUnits / 100) })", label: "Capacity", color: AppColors.secondary)
                    statPill(value: "\(boutiqueStores.count)", label: "Total", color: AppColors.accent)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                if isSyncing {
                    HStack(spacing: AppSpacing.xs) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(AppColors.accent)
                        Text("Syncing boutiques with Supabase...")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let syncMessage {
                    Text(syncMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if boutiqueStores.isEmpty {
                    emptyCard
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                } else {
                    ForEach(boutiqueStores) { store in
                        NavigationLink {
                            OrgBoutiqueDetailView(store: store) {
                                editingStore = store
                            } onDelete: {
                                Task { await deleteStore(store) }
                            }
                        } label: {
                            boutiqueCard(store: store)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                }
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
        .task { await syncStores() }
        .sheet(isPresented: $showCreateBoutique) {
            OrgStoreEditorSheet(store: nil) { created in
                editingStore = created
            }
        }
        .sheet(item: $editingStore) { store in
            OrgStoreEditorSheet(store: store) { _ in }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("No boutiques configured")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Tap + to add your first boutique and sync it to Supabase.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
    }

    private func boutiqueCard(store: StoreLocation) -> some View {
        let assignedStaff = activeStaff(for: store)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text("\(store.city), \(store.country)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(store.isOperational ? "OPERATIONAL" : "PAUSED")
                    .font(AppTypography.nano)
                    .foregroundColor(store.isOperational ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((store.isOperational ? AppColors.success : AppColors.warning).opacity(0.12))
                    .cornerRadius(4)
            }

            Divider().background(AppColors.border)

            HStack(spacing: AppSpacing.xl) {
                detailCol(label: "Manager", value: store.managerName, color: AppColors.secondary)
                detailCol(label: "Code", value: store.code, color: AppColors.accent)
                detailCol(label: "Staff", value: "\(assignedStaff.count)", color: AppColors.info)
                detailCol(label: "Target", value: formatCurrency(store.monthlySalesTarget), color: AppColors.textPrimaryDark)
            }

            if !assignedStaff.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(AppTypography.pico)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("Assigned: \(staffSummary(assignedStaff))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(1)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func detailCol(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            Text(value).font(AppTypography.bodySmall).foregroundColor(color).lineLimit(1)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }

    private func activeStaff(for store: StoreLocation) -> [User] {
        allUsers.filter {
            $0.storeId == store.id &&
            $0.role != .customer &&
            $0.isActive
        }
    }

    private func staffSummary(_ users: [User]) -> String {
        let names = users.prefix(2).map(\.name)
        if users.count <= 2 {
            return names.joined(separator: ", ")
        }
        return "\(names.joined(separator: ", ")) +\(users.count - 2) more"
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(AppTypography.heading2).foregroundColor(color)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func syncStores() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            // Pull active staff first so boutique manager picker stays current.
            try await StaffSyncService.shared.syncStaff(modelContext: modelContext)
            try await StoreSyncService.shared.syncStores(modelContext: modelContext)
            syncMessage = "Synced with Supabase."
        } catch {
            syncMessage = "Supabase sync failed: \(error.localizedDescription)"
        }
    }

    private func deleteStore(_ store: StoreLocation) async {
        do {
            try await StoreSyncService.shared.deleteStore(id: store.id)
            modelContext.delete(store)
            try? modelContext.save()
            syncMessage = "Boutique deleted and synced."
        } catch {
            syncMessage = "Delete failed: \(error.localizedDescription)"
        }
    }
}

struct OrgBoutiqueDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \User.createdAt, order: .reverse) private var allUsers: [User]
    let store: StoreLocation
    let onManage: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                card("Overview", icon: "building.2.fill") {
                    row("Store", store.name)
                    row("Code", store.code)
                    row("Type", store.type == .boutique ? "Boutique" : "Distribution")
                    row("Status", store.isOperational ? "Operational" : "Paused")
                }

                card("Location", icon: "mappin.and.ellipse") {
                    row("Address", store.addressLine1)
                    row("City", store.city)
                    row("State", store.stateProvince)
                    row("Postal", store.postalCode)
                    row("Country", store.country)
                    row("Region", store.region)
                }

                card("Operations", icon: "person.2.fill") {
                    row("Manager", store.managerName)
                    row("Capacity", "\(store.capacityUnits) units")
                    row("Monthly Target", formatCurrency(store.monthlySalesTarget))
                }

                card("Assigned Staff", icon: "person.3.fill") {
                    if assignedStaff.isEmpty {
                        Text("No staff assigned to this store.")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondaryDark)
                    } else {
                        ForEach(assignedStaff) { user in
                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name)
                                        .font(AppTypography.bodySmall)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Text(user.email)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                                Spacer()
                                Text(user.role.rawValue)
                                    .font(AppTypography.micro)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            if user.id != assignedStaff.last?.id {
                                Divider().background(AppColors.border)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Manage") { onManage() }
                    .foregroundColor(AppColors.accent)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this boutique?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Boutique", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the boutique locally and in Supabase stores.")
        }
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(AppTypography.micro)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }

    private var assignedStaff: [User] {
        allUsers.filter {
            $0.storeId == store.id &&
            $0.role != .customer &&
            $0.isActive
        }
    }
}

struct OrgStoreEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.name) private var allUsers: [User]
    @Query(sort: \StoreLocation.name) private var allStores: [StoreLocation]

    let store: StoreLocation?
    let onSaved: (StoreLocation) -> Void

    @State private var code: String
    @State private var name: String
    @State private var type: LocationType
    @State private var country: String
    @State private var city: String
    @State private var addressLine1: String
    @State private var stateProvince: String
    @State private var postalCode: String
    @State private var region: String
    @State private var managerName: String
    @State private var selectedManagerName: String
    @State private var capacityText: String
    @State private var monthlySalesTargetText: String
    @State private var isOperational: Bool
    @State private var isSaving = false
    @State private var syncMessage: String?

    init(store: StoreLocation?, onSaved: @escaping (StoreLocation) -> Void) {
        self.store = store
        self.onSaved = onSaved
        _code = State(initialValue: store?.code ?? "")
        _name = State(initialValue: store?.name ?? "")
        _type = State(initialValue: store?.type ?? .boutique)
        _country = State(initialValue: store?.country ?? "")
        _city = State(initialValue: store?.city ?? "")
        _addressLine1 = State(initialValue: store?.addressLine1 ?? "")
        _stateProvince = State(initialValue: store?.stateProvince ?? "")
        _postalCode = State(initialValue: store?.postalCode ?? "")
        _region = State(initialValue: store?.region ?? "")
        _managerName = State(initialValue: store?.managerName ?? "")
        _selectedManagerName = State(initialValue: store?.managerName ?? "")
        _capacityText = State(initialValue: "\(store?.capacityUnits ?? 0)")
        _monthlySalesTargetText = State(initialValue: Self.initialTargetText(for: store))
        _isOperational = State(initialValue: store?.isOperational ?? true)
    }

    private var capacityUnits: Int? { Int(capacityText) }
    private var monthlySalesTarget: Double? {
        let normalized = monthlySalesTargetText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }
    private var isFormValid: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedManagerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        capacityUnits != nil &&
        monthlySalesTarget != nil &&
        isCodeUnique
    }

    private var availableManagers: [User] {
        allUsers.filter { $0.role == .boutiqueManager && $0.isActive }
    }

    private var isCodeUnique: Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return allStores
            .filter { current in
                guard let store else { return true }
                return current.id != store.id
            }
            .allSatisfy { $0.code.uppercased() != normalized }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    card("Store Identity", icon: "building.2.fill") {
                        row("Code", text: $code)
                        row("Store Name", text: $name)
                        Picker("Type", selection: $type) {
                            Text("Boutique").tag(LocationType.boutique)
                            Text("Distribution").tag(LocationType.distributionCenter)
                        }
                        .pickerStyle(.segmented)
                    }

                    card("Location", icon: "mappin.and.ellipse") {
                        row("Address", text: $addressLine1)
                        row("City", text: $city)
                        row("State / Province", text: $stateProvince)
                        row("Postal Code", text: $postalCode)
                        row("Country", text: $country)
                        row("Region", text: $region)
                    }

                    card("Operations", icon: "person.2.fill") {
                        managerPickerRow
                        row("Capacity Units", text: $capacityText, keyboard: .numberPad)
                        row("Monthly Sales Target (USD)", text: $monthlySalesTargetText, keyboard: .decimalPad)
                        Toggle("Operational", isOn: $isOperational)
                            .tint(AppColors.accent)
                    }

                    if let syncMessage {
                        Text(syncMessage)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !isCodeUnique {
                        Text("Code already used by another boutique. Choose a unique code.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle(store == nil ? "New Boutique" : "Manage Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedManagerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let firstManager = availableManagers.first {
                    selectedManagerName = firstManager.name
                    managerName = firstManager.name
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(AppColors.accent) } else { Text("Save") }
                    }
                    .disabled(!isFormValid || isSaving)
                    .foregroundColor((isFormValid && !isSaving) ? AppColors.accent : AppColors.neutral400)
                }
            }
        }
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func row(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private var managerPickerRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Manager")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            Menu {
                if availableManagers.isEmpty {
                    Text("No active boutique managers found")
                } else {
                    ForEach(availableManagers) { manager in
                        Button {
                            selectedManagerName = manager.name
                            managerName = manager.name
                        } label: {
                            Text(manager.name)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedManagerName.isEmpty ? "Select manager" : selectedManagerName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(selectedManagerName.isEmpty ? AppColors.neutral500 : AppColors.textPrimaryDark)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral500)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            }
        }
    }

    private func save() async {
        guard isFormValid, let capacityUnits, let monthlySalesTarget else { return }
        isSaving = true
        defer { isSaving = false }

        let target: StoreLocation
        if let store {
            target = store
            target.updatedAt = Date()
        } else {
            target = StoreLocation(
                code: code,
                name: name,
                type: type,
                addressLine1: addressLine1,
                city: city,
                stateProvince: stateProvince,
                postalCode: postalCode,
                country: country,
                region: region,
                managerName: managerName,
                capacityUnits: capacityUnits,
                monthlySalesTarget: monthlySalesTarget,
                isOperational: isOperational
            )
            modelContext.insert(target)
        }

        target.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.type = type
        target.country = country.trimmingCharacters(in: .whitespacesAndNewlines)
        target.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        target.addressLine1 = addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        target.stateProvince = stateProvince.trimmingCharacters(in: .whitespacesAndNewlines)
        target.postalCode = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        target.region = region.trimmingCharacters(in: .whitespacesAndNewlines)
        target.managerName = selectedManagerName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.capacityUnits = capacityUnits
        target.monthlySalesTarget = monthlySalesTarget
        target.isOperational = isOperational

        do {
            try modelContext.save()
            _ = try await StoreSyncService.shared.upsertStore(target)
            syncMessage = "Saved and synced with Supabase."
            onSaved(target)
            dismiss()
        } catch {
            syncMessage = "Saved locally. Supabase sync failed: \(error.localizedDescription)"
        }
    }

    private static func initialTargetText(for store: StoreLocation?) -> String {
        guard let target = store?.monthlySalesTarget else { return "300000" }
        return target == floor(target) ? String(Int(target)) : String(target)
    }
}

// MARK: - Staff Management

struct OrgStaffSubview: View {
    @Binding var showCreateStaff: Bool
    @Query(sort: \User.createdAt, order: .reverse) private var allUsers: [User]
    @Query(sort: \StoreLocation.name) private var allStores: [StoreLocation]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRoleFilter: UserRole? = nil
    @State private var searchText = ""
  //  @State private var selectedProduct: Product?
    @State private var editingUser: User?
    @State private var isSyncing = false
    @State private var syncMessage: String?

    private var filtered: [User] {
        var users = allUsers.filter { $0.role != .customer }
        if let selectedRoleFilter { users = users.filter { $0.role == selectedRoleFilter } }
        if !searchText.isEmpty {
            users = users.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        return users
    }

    private let staffRoles: [UserRole?] = [nil, .boutiqueManager, .salesAssociate, .inventoryController, .serviceTechnician]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.neutral500)
                TextField("Search staff...", text: $searchText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(staffRoles, id: \.self) { role in
                        chipBtn(label: role?.rawValue ?? "All", selected: selectedRoleFilter == role) {
                            selectedRoleFilter = role
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.vertical, AppSpacing.xs)

            HStack {
                Text("\(filtered.count) staff members")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text("\(filtered.filter { $0.isActive }.count) active")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.success)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xs)

            if isSyncing {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppColors.accent)
                    Text("Syncing staff with Supabase...")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xs)
            } else if let syncMessage {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: syncMessage.lowercased().contains("synced") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(AppTypography.infoIcon)
                        .foregroundColor(syncMessage.lowercased().contains("synced") ? AppColors.success : AppColors.warning)
                        .padding(.top, 2)
                    Text(syncMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusMedium)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xs)
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(filtered) { user in
                        staffRow(user)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .task { await syncStaff() }
        .sheet(isPresented: $showCreateStaff) {
            OrgCreateStaffSheet(availableStores: allStores) { _ in }
        }
        .sheet(item: $editingUser) { user in
            OrgManageStaffSheet(user: user, availableStores: allStores)
        }
    }

    private func staffRow(_ user: User) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(roleColor(user.role).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(initials(user.name))
                    .font(AppTypography.editLink)
                    .foregroundColor(roleColor(user.role))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    if !user.isActive {
                        Text("INACTIVE")
                            .font(AppTypography.pico)
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.error.opacity(0.12))
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(AppTypography.pico)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(user.email)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                Text(user.role.rawValue).font(AppTypography.roleTag).foregroundColor(roleColor(user.role))

                HStack(spacing: 6) {
                    Image(systemName: "building.2")
                        .font(AppTypography.pico)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("Assigned: \(storeName(for: user))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(1)
                }
            }
            Spacer()

            Button {
                editingUser = user
            } label: {
                Image(systemName: "chevron.right")
                    .font(AppTypography.chevron)
                    .foregroundColor(AppColors.neutral600)
                    .frame(width: 28, height: AppSpacing.touchTarget)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .corporateAdmin: return AppColors.accent
        case .boutiqueManager: return AppColors.secondary
        case .salesAssociate: return AppColors.info
        case .inventoryController: return AppColors.success
        case .serviceTechnician: return AppColors.warning
        case .customer: return AppColors.neutral400
        }
    }

    private func initials(_ name: String) -> String {
        let p = name.split(separator: " ")
        return p.count >= 2 ? "\(p[0].prefix(1))\(p[1].prefix(1))".uppercased() : String(name.prefix(2)).uppercased()
    }

    private func storeName(for user: User) -> String {
        guard let storeId = user.storeId else { return "Unassigned" }
        return allStores.first(where: { $0.id == storeId })?.name ?? "Unknown Store"
    }

    private func chipBtn(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(selected ? AppTypography.label : AppTypography.bodySmall)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(selected ? AppColors.textPrimaryLight : AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
                .background(selected ? AppColors.accent : AppColors.backgroundTertiary)
                .cornerRadius(AppSpacing.radiusMedium)
        }
        .buttonStyle(.plain)
    }

    private func syncStaff() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await StaffSyncService.shared.syncStaff(modelContext: modelContext)
            syncMessage = "Synced with Supabase."
        } catch {
            syncMessage = "Supabase sync failed: \(error.localizedDescription)"
        }
    }

    private func pushSingleUser(_ user: User) async {
        do {
            _ = try await StaffSyncService.shared.updateStaffIfExists(user)
            syncMessage = "Staff profile updated in Supabase."
        } catch {
            syncMessage = "Saved locally only. No matching auth/staff profile exists in Supabase yet."
        }
    }
}

struct OrgManageStaffSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    let availableStores: [StoreLocation]

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var role: UserRole
    @State private var isActive: Bool
    @State private var selectedStoreId: UUID?

    init(user: User, availableStores: [StoreLocation]) {
        self.user = user
        self.availableStores = availableStores
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        _phone = State(initialValue: user.phone)
        _role = State(initialValue: user.role)
        _isActive = State(initialValue: user.isActive)
        _selectedStoreId = State(initialValue: user.storeId)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    card("Staff Details", icon: "person.fill") {
                        field("Full Name", text: $name)
                        field("Email", text: $email, keyboard: .emailAddress)
                        field("Phone", text: $phone, keyboard: .phonePad)
                    }

                    card("Access", icon: "shield.fill") {
                        Picker("Role", selection: $role) {
                            Text(UserRole.boutiqueManager.rawValue).tag(UserRole.boutiqueManager)
                            Text(UserRole.salesAssociate.rawValue).tag(UserRole.salesAssociate)
                            Text(UserRole.inventoryController.rawValue).tag(UserRole.inventoryController)
                            Text(UserRole.serviceTechnician.rawValue).tag(UserRole.serviceTechnician)
                            Text(UserRole.corporateAdmin.rawValue).tag(UserRole.corporateAdmin)
                        }
                        .pickerStyle(.menu)

                        storeMenuPicker

                        Toggle("Active", isOn: $isActive)
                            .tint(AppColors.accent)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
            }
            .navigationTitle("Manage Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        user.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        user.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        user.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                        user.role = role
                        user.storeId = selectedStoreId
                        user.isActive = isActive
                        try? modelContext.save()
                        Task {
                            _ = try? await StaffSyncService.shared.updateStaffIfExists(user)
                            dismiss()
                        }
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(AppTypography.bodyMedium)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private var storeMenuPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Assigned Boutique")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            Menu {
                Button("Unassigned") { selectedStoreId = nil }
                ForEach(availableStores.filter { $0.type == .boutique }.sorted { $0.name < $1.name }) { store in
                    Button(store.name) { selectedStoreId = store.id }
                }
            } label: {
                HStack {
                    Text(selectedStoreName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral500)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            }
        }
    }

    private var selectedStoreName: String {
        guard let selectedStoreId else { return "Unassigned" }
        return availableStores.first(where: { $0.id == selectedStoreId })?.name ?? "Unknown Store"
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Replace the OrgCreateStaffSheet struct in OrganizationView.swift
// ─────────────────────────────────────────────────────────────────────────────

struct OrgCreateStaffSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let availableStores: [StoreLocation]
    let onCreated: (User) -> Void

    @State private var name = ""
    @State private var corporateEmail = ""
    @State private var personalEmail = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .boutiqueManager
    @State private var selectedStoreId: UUID?
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var successMessage: String?

    private let creatableRoles: [UserRole] = [
        .boutiqueManager,
        .salesAssociate,
        .inventoryController,
        .serviceTechnician
    ]

    init(availableStores: [StoreLocation], onCreated: @escaping (User) -> Void) {
        self.availableStores = availableStores
        self.onCreated = onCreated
        let defaultStoreId = availableStores
            .filter { $0.type == .boutique }
            .sorted { $0.name < $1.name }
            .first?
            .id
        _selectedStoreId = State(initialValue: defaultStoreId)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // Role picker
                    card("Role", icon: "person.badge.key.fill") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(creatableRoles, id: \.self) { role in
                                    roleChip(role)
                                }
                            }
                        }
                    }

                    // Staff profile
                    card("Staff Profile", icon: "person.fill") {
                        field("Full Name", text: $name)
                        field("Corporate Email (@maisonluxe.me)", text: $corporateEmail, keyboard: .emailAddress)
                        field("Personal Email (for login credentials)", text: $personalEmail, keyboard: .emailAddress)
                        field("Phone (optional)", text: $phone, keyboard: .phonePad)
                        secureField("Temporary Password", text: $password)
                    }

                    if !corporateEmail.isEmpty && !corporateEmail.lowercased().hasSuffix("@maisonluxe.me") {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Corporate email should end with @maisonluxe.me")
                                .font(AppTypography.caption)
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    card("Store Assignment", icon: "building.2.fill") {
                        storeMenuPicker
                    }

                    // Info banner
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppColors.accent)
                            .padding(.top, 1)
                        Text("Share this temporary password with the staff member. They should change it after first login.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.accent.opacity(0.08))
                    .cornerRadius(AppSpacing.radiusMedium)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let successMessage {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                            Text(successMessage)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.success)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle("Create Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await createStaff() }
                    } label: {
                        if isCreating {
                            ProgressView().tint(AppColors.accent)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!isFormValid || isCreating)
                    .opacity((isFormValid && !isCreating) ? 1 : 0.45)
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        corporateEmail.contains("@") &&
        !personalEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        personalEmail.contains("@") &&
        password.count >= 6 &&
        selectedStoreId != nil
    }

    private func createStaff() async {
        guard isFormValid else { return }
        isCreating = true
        errorMessage = nil
        successMessage = nil
        defer { isCreating = false }

        let trimmedCorporateEmail = corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPersonalEmail = personalEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let dto = try await StaffSyncService.shared.createStaffWithAuth(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: trimmedCorporateEmail,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                role: selectedRole,
                storeId: selectedStoreId,
                corporateEmail: trimmedCorporateEmail,
                personalEmail: trimmedPersonalEmail
            )

            let newUser = User(
                name: dto.fullName,
                email: dto.email,
                phone: dto.phone ?? "",
                passwordHash: "",
                storeId: dto.storeId,
                role: dto.userRole,
                isActive: dto.isActive
            )
            newUser.id = dto.id
            newUser.createdAt = dto.createdAt
            modelContext.insert(newUser)
            try? modelContext.save()

            successMessage = "Staff account created for \(dto.email)"
            onCreated(newUser)

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func roleChip(_ role: UserRole) -> some View {
        Button { selectedRole = role } label: {
            Text(role.rawValue)
                .font(selectedRole == role ? AppTypography.label : AppTypography.bodySmall)
                .foregroundColor(selectedRole == role ? AppColors.textPrimaryLight : AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
                .background(selectedRole == role ? AppColors.accent : AppColors.backgroundTertiary)
                .cornerRadius(AppSpacing.radiusMedium)
        }
        .buttonStyle(.plain)
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .font(AppTypography.bodyMedium)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
            SecureField(label, text: text)
                .font(AppTypography.bodyMedium)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private var storeMenuPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Boutique")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            Menu {
                ForEach(availableStores.filter { $0.type == .boutique }.sorted { $0.name < $1.name }) { store in
                    Button(store.name) { selectedStoreId = store.id }
                }
            } label: {
                HStack {
                    Text(selectedStoreName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral500)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            }
        }
    }

    private var selectedStoreName: String {
        guard let selectedStoreId else { return "Select boutique" }
        return availableStores.first(where: { $0.id == selectedStoreId })?.name ?? "Select boutique"
    }
}
// MARK: - Roles & Permissions

struct OrgRoleTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var palette: String
    var permissions: [String]
    var isSystem: Bool
}

struct OrgRolesSubview: View {
    @Binding var showCreateRole: Bool
    @AppStorage("org_role_templates_json") private var storedRolesJSON = ""

    @State private var roles: [OrgRoleTemplate] = []
    @State private var editingRole: OrgRoleTemplate?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(roles) { role in
                    roleCard(role)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .onAppear {
            if roles.isEmpty { roles = loadRoles() }
        }
        .onChange(of: roles) {
            saveRoles(roles)
        }
        .sheet(isPresented: $showCreateRole) {
            OrgRoleEditorSheet(role: nil) { newRole in
                roles.append(newRole)
            }
        }
        .sheet(item: $editingRole) { role in
            OrgRoleEditorSheet(role: role) { updatedRole in
                if let index = roles.firstIndex(where: { $0.id == updatedRole.id }) {
                    roles[index] = updatedRole
                }
            }
        }
    }

    private func roleCard(_ role: OrgRoleTemplate) -> some View {
        let color = paletteColor(role.palette)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: role.icon).font(AppTypography.orgIcon).foregroundColor(color)
                Text(role.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Button(action: { editingRole = role }) {
                    Text("Edit").font(AppTypography.editLink).foregroundColor(AppColors.accent)
                }
            }

            Divider().background(AppColors.border)

            ForEach(role.permissions, id: \.self) { permission in
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "checkmark").font(AppTypography.checkmarkSmall).foregroundColor(color)
                    Text(permission).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
                }
            }

            if !role.isSystem {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        roles.removeAll { $0.id == role.id }
                    } label: {
                        Text("Delete")
                            .font(AppTypography.caption)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func loadRoles() -> [OrgRoleTemplate] {
        if let data = storedRolesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([OrgRoleTemplate].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return defaultRoles()
    }

    private func saveRoles(_ roles: [OrgRoleTemplate]) {
        guard let data = try? JSONEncoder().encode(roles),
              let json = String(data: data, encoding: .utf8) else { return }
        storedRolesJSON = json
    }

    private func defaultRoles() -> [OrgRoleTemplate] {
        [
            .init(id: UUID(), name: "Corporate Admin", icon: "shield.checkered", palette: "accent", permissions: ["Full system access", "Create/manage all accounts", "Product catalog CRUD", "Pricing & tax config", "All reports & analytics"], isSystem: true),
            .init(id: UUID(), name: "Boutique Manager", icon: "building.2", palette: "secondary", permissions: ["Manage boutique staff", "View boutique inventory", "Process returns", "View boutique reports", "Customer management"], isSystem: true),
            .init(id: UUID(), name: "Sales Associate", icon: "person.fill", palette: "info", permissions: ["Process sales", "View product catalog", "Customer lookup", "Appointment booking"], isSystem: true),
            .init(id: UUID(), name: "Inventory Controller", icon: "shippingbox", palette: "success", permissions: ["Stock receiving", "Inventory counts", "Transfer requests", "Damage reporting"], isSystem: true),
            .init(id: UUID(), name: "Service Technician", icon: "wrench.and.screwdriver", palette: "warning", permissions: ["Service ticket management", "Repair logging", "Parts requisition"], isSystem: true)
        ]
    }

    private func paletteColor(_ key: String) -> Color {
        switch key {
        case "accent": return AppColors.accent
        case "secondary": return AppColors.secondary
        case "success": return AppColors.success
        case "warning": return AppColors.warning
        case "info": return AppColors.info
        default: return AppColors.secondary
        }
    }
}

struct OrgRoleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let role: OrgRoleTemplate?
    let onSave: (OrgRoleTemplate) -> Void

    @State private var name: String
    @State private var icon: String
    @State private var palette: String
    @State private var permissionsRaw: String

    init(role: OrgRoleTemplate?, onSave: @escaping (OrgRoleTemplate) -> Void) {
        self.role = role
        self.onSave = onSave
        _name = State(initialValue: role?.name ?? "")
        _icon = State(initialValue: role?.icon ?? "person.badge.key.fill")
        _palette = State(initialValue: role?.palette ?? "accent")
        _permissionsRaw = State(initialValue: role?.permissions.joined(separator: ", ") ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    card("Role Identity", icon: "person.badge.key.fill") {
                        input("Role Name", text: $name)
                        input("SF Symbol Icon", text: $icon, placeholder: "e.g. person.fill")
                        Picker("Palette", selection: $palette) {
                            Text("Accent").tag("accent")
                            Text("Secondary").tag("secondary")
                            Text("Success").tag("success")
                            Text("Warning").tag("warning")
                            Text("Info").tag("info")
                        }
                        .pickerStyle(.segmented)
                    }

                    card("Permissions", icon: "checkmark.shield.fill") {
                        TextField("Comma separated permissions", text: $permissionsRaw, axis: .vertical)
                            .lineLimit(3...8)
                            .font(AppTypography.bodyMedium)
                            .padding(AppSpacing.sm)
                            .background(AppColors.backgroundWhite)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .navigationTitle(role == nil ? "New Role" : "Edit Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let permissions = permissionsRaw
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }

                        let payload = OrgRoleTemplate(
                            id: role?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            icon: icon.trimmingCharacters(in: .whitespacesAndNewlines),
                            palette: palette,
                            permissions: permissions,
                            isSystem: role?.isSystem ?? false
                        )
                        onSave(payload)
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppTypography.overline)
                .foregroundColor(AppColors.accent)
            content()
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(AppSpacing.radiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXL)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func input(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            TextField(placeholder.isEmpty ? label : placeholder, text: text)
                .font(AppTypography.bodyMedium)
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }
}

#Preview {
    OrganizationView()
        .modelContainer(for: [User.self, Product.self, Category.self, StoreLocation.self], inMemory: true)
}
