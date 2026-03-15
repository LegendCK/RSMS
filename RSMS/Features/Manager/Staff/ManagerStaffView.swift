//
//  ManagerStaffView.swift
//  infosys2
//
//  Boutique Manager staff management — roster, shifts, performance.
//  Store-scoped: only shows staff assigned to this boutique.
//

import SwiftUI
import SwiftData

struct ManagerStaffView: View {
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
                    case 0: StaffRosterSubview()
                    case 1: StaffShiftsSubview()
                    case 2: StaffPerformanceSubview()
                    default: StaffRosterSubview()
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
    @Query(sort: \User.createdAt) private var allUsers: [User]

    private var storeStaff: [User] {
        allUsers.filter { $0.role == .salesAssociate || $0.role == .inventoryController || $0.role == .serviceTechnician }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    rosterStat(value: "\(storeStaff.count)", label: "Total", color: AppColors.accent)
                    rosterStat(value: "\(storeStaff.filter { $0.isActive }.count)", label: "Active", color: AppColors.success)
                    rosterStat(value: "\(storeStaff.filter { $0.role == .salesAssociate }.count)", label: "Sales", color: AppColors.info)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, AppSpacing.sm)

                ForEach(storeStaff) { user in
                    staffCard(user)
                }
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
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
                        Text("OFF").font(AppTypography.pico).foregroundColor(AppColors.neutral500)
                            .padding(.horizontal, 4).padding(.vertical, 1).background(AppColors.neutral500.opacity(0.12)).cornerRadius(3)
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
        case .salesAssociate: return AppColors.info
        case .inventoryController: return AppColors.success
        case .serviceTechnician: return AppColors.warning
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
}

// MARK: - Shifts

struct StaffShiftsSubview: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(AppColors.neutral400)
            Text("No Shift Data")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            Text("Shift scheduling is not yet available.")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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

#Preview {
    ManagerStaffView()
        .modelContainer(for: [User.self], inMemory: true)
}
