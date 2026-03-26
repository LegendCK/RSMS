//
//  UserManagementView.swift
//  infosys2
//
//  Corporate Admin user management — create, view, deactivate staff accounts.
//  Enforces hierarchical access: Admin creates Managers, Managers create Associates.
//

import SwiftUI
import SwiftData

struct UserManagementView: View {
    @Query(sort: \User.createdAt, order: .reverse) private var allUsers: [User]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateUser = false
    @State private var selectedRoleFilter: UserRole? = nil
    @State private var searchText = ""

    private var filteredUsers: [User] {
        var users = allUsers
        if let filter = selectedRoleFilter {
            users = users.filter { $0.role == filter }
        }
        if !searchText.isEmpty {
            users = users.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        return users
    }

    private let roleFilters: [UserRole?] = [nil, .corporateAdmin, .boutiqueManager, .salesAssociate, .inventoryController, .serviceTechnician, .customer]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Role filter chips
                    roleFilterBar

                    // User list
                    if filteredUsers.isEmpty {
                        emptyState
                    } else {
                        userList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("User Management")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateUser = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreateUser) {
                CreateUserSheet(modelContext: modelContext)
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.neutral500)
            TextField("Search users...", text: $searchText)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Role Filter

    private var roleFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(roleFilters, id: \.self) { role in
                    Button(action: { selectedRoleFilter = role }) {
                        Text(role?.rawValue ?? "All")
                            .font(AppTypography.caption)
                            .foregroundColor(selectedRoleFilter == role ? AppColors.primary : AppColors.textSecondaryDark)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(selectedRoleFilter == role ? AppColors.accent : AppColors.backgroundTertiary)
                            .cornerRadius(AppSpacing.radiusSmall)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - User List

    private var userList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Stats header
                HStack {
                    Text("\(filteredUsers.count) users")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                    Text("\(filteredUsers.filter { $0.isActive }.count) active")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.success)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.sm)

                // User rows
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(filteredUsers) { user in
                        userRow(user)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    private func userRow(_ user: User) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(roleBadgeColor(user.role).opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(userInitials(user.name))
                    .font(AppTypography.label)
                    .foregroundColor(roleBadgeColor(user.role))
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Text(user.name)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)

                    if !user.isActive {
                        Text("INACTIVE")
                            .font(AppTypography.nano)
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.error.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                Text(user.email)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)

                Text(user.role.rawValue)
                    .font(AppTypography.overline)
                    .tracking(1)
                    .foregroundColor(roleBadgeColor(user.role))
            }

            Spacer()

            // Action menu
            Menu {
                Button(action: {}) {
                    Label("Edit Details", systemImage: "pencil")
                }
                Button(action: {}) {
                    Label("Reset Password", systemImage: "key")
                }
                Divider()
                Button(role: .destructive, action: {
                    user.isActive.toggle()
                    try? modelContext.save()
                }) {
                    Label(user.isActive ? "Deactivate" : "Reactivate",
                          systemImage: user.isActive ? "person.slash" : "person.badge.plus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppTypography.iconMedium)
                    .foregroundColor(AppColors.neutral500)
                    .frame(width: AppSpacing.touchTarget, height: AppSpacing.touchTarget)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(AppTypography.emptyStateIcon)
                .foregroundColor(AppColors.neutral600)
            Text("No users found")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Try adjusting your search or filter")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func roleBadgeColor(_ role: UserRole) -> Color {
        switch role {
        case .corporateAdmin: return AppColors.accent
        case .boutiqueManager: return AppColors.secondary
        case .salesAssociate: return AppColors.info
        case .inventoryController: return AppColors.success
        case .serviceTechnician: return AppColors.warning
        case .customer: return AppColors.neutral400
        }
    }

    private func userInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Create User Sheet

struct CreateUserSheet: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StoreLocation.name) private var allStores: [StoreLocation]

    @State private var name = ""
    @State private var corporateEmail = ""
    @State private var personalEmail = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .boutiqueManager
    @State private var selectedStoreId: UUID?
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var createdName = ""

    private let creatableRoles: [UserRole] = [
        .boutiqueManager,
        .salesAssociate,
        .inventoryController,
        .serviceTechnician
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppColors.accent.opacity(0.10))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(AppColors.accent)
                            }
                            Text("Create Staff Account")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Provision a new employee account")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 24)

                        // Role picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROLE")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(creatableRoles, id: \.self) { role in
                                        Button(action: { selectedRole = role }) {
                                            Text(role.rawValue)
                                                .font(.system(size: 13, weight: selectedRole == role ? .semibold : .regular))
                                                .foregroundColor(selectedRole == role ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 9)
                                                .background(selectedRole == role ? AppColors.accent : Color(uiColor: .secondarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(selectedRole == role ? Color.clear : Color(uiColor: .systemGray4), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Fields
                        formSection {
                            fieldRow(label: "Full Name", icon: "person") {
                                TextField("Required", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                            }
                            Divider().padding(.leading, 52)
                            fieldRow(label: "Corporate Email", icon: "building.2") {
                                TextField("name@maisonluxe.me", text: $corporateEmail)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            Divider().padding(.leading, 52)
                            fieldRow(label: "Personal Email", icon: "envelope") {
                                TextField("user@gmail.com", text: $personalEmail)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            Divider().padding(.leading, 52)
                            fieldRow(label: "Phone Number", icon: "phone") {
                                TextField("Optional", text: $phone)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.phonePad)
                            }
                            Divider().padding(.leading, 52)
                            fieldRow(label: "Temporary Password", icon: "lock") {
                                SecureField("Min 6 characters", text: $password)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        // Boutique Assignment
                        formSection {
                            fieldRow(label: "Boutique", icon: "building.2") {
                                Menu {
                                    Button("None") { selectedStoreId = nil }
                                    ForEach(boutiqueStores) { store in
                                        Button(store.name) { selectedStoreId = store.id }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(selectedStoreName)
                                            .font(.system(size: 15))
                                            .foregroundColor(selectedStoreId == nil ? .secondary : .primary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        if !corporateEmail.isEmpty && !corporateEmail.lowercased().hasSuffix("@maisonluxe.me") {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                                Text("Corporate email should end with @maisonluxe.me")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.top, -12)
                            .padding(.bottom, -8)
                        }

                        // Create button
                        Button {
                            Task { await createUser() }
                        } label: {
                            HStack(spacing: 8) {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                }
                                Text(isCreating ? "Creating…" : "Create Account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isCreating ? AppColors.accent.opacity(0.6) : AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isCreating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .principal) {
                    Text("NEW ACCOUNT")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Account Created", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(createdName)'s account has been provisioned. Share the temporary password so they can log in.")
            }
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 20)
    }

    private func fieldRow<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .layoutPriority(1)
            Spacer(minLength: 8)
            content()
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var boutiqueStores: [StoreLocation] {
        allStores.filter { $0.type == .boutique }.sorted { $0.name < $1.name }
    }

    private var selectedStoreName: String {
        if let id = selectedStoreId, let store = allStores.first(where: { $0.id == id }) {
            return store.name
        }
        return "Select Boutique"
    }

    @MainActor
    private func createUser() async {
        let trimmedName           = name.trimmingCharacters(in: .whitespaces)
        let trimmedCorporateEmail = corporateEmail.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedPersonalEmail  = personalEmail.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedPhone          = phone.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !trimmedCorporateEmail.isEmpty,
              !trimmedPersonalEmail.isEmpty,
              !password.isEmpty, password.count >= 6 else {
            errorMessage = "Please fill in all fields. Password must be at least 6 characters."
            showError = true
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            // 1 — Create in Supabase Auth + users table
            let dto = try await StaffSyncService.shared.createStaffWithAuth(
                name: trimmedName,
                email: trimmedCorporateEmail,
                phone: trimmedPhone,
                password: password,
                role: selectedRole,
                storeId: selectedStoreId,
                corporateEmail: trimmedCorporateEmail,
                personalEmail: trimmedPersonalEmail
            )

            // 2 — Mirror into local SwiftData so UserManagementView refreshes instantly
            let local = User(
                name: dto.fullName,
                email: dto.email,
                phone: dto.phone ?? "",
                passwordHash: "",
                storeId: dto.storeId,
                role: dto.userRole,
                isActive: dto.isActive
            )
            local.id = dto.id
            local.createdAt = dto.createdAt
            modelContext.insert(local)
            try? modelContext.save()

            await AdminAuditService.shared.logActivity(
                action: "Created Staff User",
                details: [
                    "email": dto.email,
                    "role": dto.userRole.rawValue,
                    "id": dto.id.uuidString
                ]
            )

            createdName = dto.fullName
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    UserManagementView()
        .modelContainer(for: [User.self], inMemory: true)
}
