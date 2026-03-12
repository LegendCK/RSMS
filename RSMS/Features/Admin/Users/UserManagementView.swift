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
        case .boutiqueManager: return AppColors.purple
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

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .boutiqueManager
    @State private var showError = false
    @State private var errorMessage = ""

    private let creatableRoles: [UserRole] = [
        .boutiqueManager,
        .salesAssociate,
        .inventoryController,
        .serviceTechnician
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        // Header
                        VStack(spacing: AppSpacing.xs) {
                            Text("Create Staff Account")
                                .font(AppTypography.displaySmall)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Text("Provision a new employee account")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(.top, AppSpacing.xl)

                        // Role picker
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("ROLE")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, AppSpacing.screenHorizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.xs) {
                                    ForEach(creatableRoles, id: \.self) { role in
                                        Button(action: { selectedRole = role }) {
                                            Text(role.rawValue)
                                                .font(AppTypography.caption)
                                                .foregroundColor(selectedRole == role ? AppColors.primary : AppColors.textSecondaryDark)
                                                .padding(.horizontal, AppSpacing.md)
                                                .padding(.vertical, AppSpacing.xs)
                                                .background(selectedRole == role ? AppColors.accent : AppColors.backgroundTertiary)
                                                .cornerRadius(AppSpacing.radiusSmall)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }

                        // Fields
                        VStack(spacing: AppSpacing.lg) {
                            LuxuryTextField(placeholder: "Full Name", text: $name, icon: "person")
                            LuxuryTextField(placeholder: "Email Address", text: $email, icon: "envelope")
                            LuxuryTextField(placeholder: "Phone Number", text: $phone, icon: "phone")
                            LuxuryTextField(placeholder: "Temporary Password", text: $password, isSecure: true, icon: "lock")
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Create button
                        PrimaryButton(title: "Create Account") {
                            createUser()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.md)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(AppTypography.closeButton)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func createUser() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty, password.count >= 6 else {
            errorMessage = "Please fill in all fields. Password must be at least 6 characters."
            showError = true
            return
        }

        let newUser = User(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            phone: phone.trimmingCharacters(in: .whitespaces),
            passwordHash: password,
            role: selectedRole
        )

        modelContext.insert(newUser)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    UserManagementView()
        .modelContainer(for: [User.self], inMemory: true)
}
