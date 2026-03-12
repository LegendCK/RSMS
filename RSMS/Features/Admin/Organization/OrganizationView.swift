//
//  OrganizationView.swift
//  infosys2
//
//  Enterprise organization — boutique locations, staff management, role-based access.
//

import SwiftUI
import SwiftData

struct OrganizationView: View {
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
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
                    case 0: OrgBoutiquesSubview()
                    case 1: OrgStaffSubview()
                    case 2: OrgRolesSubview()
                    default: OrgBoutiquesSubview()
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
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.toolbarIcon)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Boutiques

struct OrgBoutiquesSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                // Stats
                HStack(spacing: AppSpacing.sm) {
                    statPill(value: "4", label: "Active", color: AppColors.success)
                    statPill(value: "35", label: "Staff", color: AppColors.purple)
                    statPill(value: "$2.4M", label: "Revenue", color: AppColors.accent)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                boutiqueCard(name: "Fifth Avenue", city: "New York, NY", manager: "James Beaumont", staff: 12, revenue: "$890K", status: "Operational")
                boutiqueCard(name: "Rodeo Drive", city: "Beverly Hills, CA", manager: "Sophia Laurent", staff: 9, revenue: "$720K", status: "Operational")
                boutiqueCard(name: "Champs-Élysées", city: "Paris, France", manager: "—", staff: 8, revenue: "$540K", status: "Operational")
                boutiqueCard(name: "Ginza", city: "Tokyo, Japan", manager: "—", staff: 6, revenue: "$250K", status: "Operational")
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func boutiqueCard(name: String, city: String, manager: String, staff: Int, revenue: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Maison Luxe — \(name)").font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text(city).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(status.uppercased()).font(AppTypography.nano).foregroundColor(AppColors.success)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(AppColors.success.opacity(0.12)).cornerRadius(4)
            }
            Divider().background(AppColors.border)
            HStack(spacing: AppSpacing.xl) {
                detailCol(label: "Manager", value: manager, color: AppColors.purple)
                detailCol(label: "Revenue", value: revenue, color: AppColors.accent)
                detailCol(label: "Staff", value: "\(staff)", color: AppColors.textPrimaryDark)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func detailCol(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            Text(value).font(AppTypography.bodySmall).foregroundColor(color)
        }
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
}

// MARK: - Staff Management

struct OrgStaffSubview: View {
    @Query(sort: \User.createdAt, order: .reverse) private var allUsers: [User]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateUser = false
    @State private var selectedRoleFilter: UserRole? = nil
    @State private var searchText = ""

    private var filtered: [User] {
        var u = allUsers.filter { $0.role != .customer }
        if let r = selectedRoleFilter { u = u.filter { $0.role == r } }
        if !searchText.isEmpty { u = u.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.email.localizedCaseInsensitiveContains(searchText) } }
        return u
    }

    private let staffRoles: [UserRole?] = [nil, .boutiqueManager, .salesAssociate, .inventoryController, .serviceTechnician]

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.neutral500)
                TextField("Search staff...", text: $searchText).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .padding(.horizontal, AppSpacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(staffRoles, id: \.self) { role in
                        chipBtn(label: role?.rawValue ?? "All", selected: selectedRoleFilter == role) { selectedRoleFilter = role }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.vertical, AppSpacing.xs)

            HStack {
                Text("\(filtered.count) staff members").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Text("\(filtered.filter { $0.isActive }.count) active").font(AppTypography.caption).foregroundColor(AppColors.success)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xs)

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
        .sheet(isPresented: $showCreateUser) {
            CreateUserSheet(modelContext: modelContext)
        }
    }

    private func staffRow(_ user: User) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(roleColor(user.role).opacity(0.15)).frame(width: 40, height: 40)
                Text(initials(user.name)).font(AppTypography.editLink).foregroundColor(roleColor(user.role))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    if !user.isActive {
                        Text("INACTIVE").font(AppTypography.pico).foregroundColor(AppColors.error)
                            .padding(.horizontal, 4).padding(.vertical, 1).background(AppColors.error.opacity(0.12)).cornerRadius(3)
                    }
                }
                Text(user.email).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                Text(user.role.rawValue).font(AppTypography.roleTag).foregroundColor(roleColor(user.role))
            }
            Spacer()
            Menu {
                Button(action: {}) { Label("Edit", systemImage: "pencil") }
                Button(action: {}) { Label("Reset Password", systemImage: "key") }
                Divider()
                Button(role: .destructive, action: { user.isActive.toggle(); try? modelContext.save() }) {
                    Label(user.isActive ? "Deactivate" : "Reactivate", systemImage: user.isActive ? "person.slash" : "person.badge.plus")
                }
            } label: {
                Image(systemName: "ellipsis").font(AppTypography.iconSmall).foregroundColor(AppColors.neutral500)
                    .frame(width: 28, height: AppSpacing.touchTarget)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }

    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .corporateAdmin: return AppColors.accent
        case .boutiqueManager: return AppColors.purple
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

    private func chipBtn(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(AppTypography.caption)
                .foregroundColor(selected ? AppColors.primary : AppColors.textSecondaryDark)
                .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
                .background(selected ? AppColors.accent : AppColors.backgroundTertiary)
                .cornerRadius(AppSpacing.radiusSmall)
        }
    }
}

// MARK: - Roles & Permissions

struct OrgRolesSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                roleCard(role: "Corporate Admin", color: AppColors.accent, icon: "shield.checkered",
                         permissions: ["Full system access", "Create/manage all accounts", "Product catalog CRUD", "Pricing & tax config", "All reports & analytics"])
                roleCard(role: "Boutique Manager", color: AppColors.purple, icon: "building.2",
                         permissions: ["Manage boutique staff", "View boutique inventory", "Process returns", "View boutique reports", "Customer management"])
                roleCard(role: "Sales Associate", color: AppColors.info, icon: "person.fill",
                         permissions: ["Process sales", "View product catalog", "Customer lookup", "Appointment booking"])
                roleCard(role: "Inventory Controller", color: AppColors.success, icon: "shippingbox",
                         permissions: ["Stock receiving", "Inventory counts", "Transfer requests", "Damage reporting"])
                roleCard(role: "Service Technician", color: AppColors.warning, icon: "wrench.and.screwdriver",
                         permissions: ["Service ticket management", "Repair logging", "Parts requisition"])
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func roleCard(role: String, color: Color, icon: String, permissions: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon).font(AppTypography.orgIcon).foregroundColor(color)
                Text(role).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Spacer()
                Button(action: {}) {
                    Text("Edit").font(AppTypography.editLink).foregroundColor(AppColors.accent)
                }
            }
            Divider().background(AppColors.border)
            ForEach(permissions, id: \.self) { perm in
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "checkmark").font(AppTypography.checkmarkSmall).foregroundColor(color)
                    Text(perm).font(AppTypography.bodySmall).foregroundColor(AppColors.textSecondaryDark)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
    }
}

#Preview {
    OrganizationView()
        .modelContainer(for: [User.self, Product.self, Category.self], inMemory: true)
}
