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
            VStack(alignment: .trailing, spacing: 2) {
                Text("On Floor").font(AppTypography.micro).foregroundColor(AppColors.success)
                Text("9:00–6:00").font(AppTypography.caption).foregroundColor(AppColors.neutral500)
            }
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                sLabel("TODAY — MAR 10")

                shiftRow(name: "Alexander Chase", role: "Sales Associate", shift: "9:00 AM – 6:00 PM", status: "On Floor", color: AppColors.success)
                shiftRow(name: "Isabella Moreau", role: "Sales Associate", shift: "10:00 AM – 7:00 PM", status: "On Floor", color: AppColors.success)
                shiftRow(name: "Daniel Park", role: "Inventory Controller", shift: "8:00 AM – 4:00 PM", status: "Stockroom", color: AppColors.info)
                shiftRow(name: "Marcus Webb", role: "Service Technician", shift: "11:00 AM – 3:00 PM", status: "Service Bay", color: AppColors.warning)

                sLabel("TOMORROW — MAR 11")

                shiftRow(name: "Alexander Chase", role: "Sales Associate", shift: "9:00 AM – 6:00 PM", status: "Scheduled", color: AppColors.neutral500)
                shiftRow(name: "Isabella Moreau", role: "Sales Associate", shift: "OFF", status: "Day Off", color: AppColors.neutral500)
                shiftRow(name: "Daniel Park", role: "Inventory Controller", shift: "8:00 AM – 4:00 PM", status: "Scheduled", color: AppColors.neutral500)
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func shiftRow(name: String, role: String, shift: String, status: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Text(role).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(shift).font(AppTypography.caption).foregroundColor(AppColors.textPrimaryDark)
                Text(status.uppercased()).font(AppTypography.nano).foregroundColor(color)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(color.opacity(0.12)).cornerRadius(4)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Performance

struct StaffPerformanceSubview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                sLabel("THIS MONTH")

                perfCard(name: "Alexander Chase", role: "Sales Associate", sales: "$86,400", txns: 14, avgTicket: "$6,171", convRate: "42%", rank: 1)
                perfCard(name: "Isabella Moreau", role: "Sales Associate", sales: "$72,100", txns: 11, avgTicket: "$6,554", convRate: "38%", rank: 2)

                sLabel("SUPPORT STAFF")

                perfSupportCard(name: "Daniel Park", role: "Inventory Controller", metric: "98.5% accuracy", detail: "127 items processed this month")
                perfSupportCard(name: "Marcus Webb", role: "Service Technician", metric: "4 repairs completed", detail: "Avg. turnaround: 2.3 days")
            }
            .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.xxxl)
        }
    }

    private func perfCard(name: String, role: String, sales: String, txns: Int, avgTicket: String, convRate: String, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("#\(rank)").font(AppTypography.heading2).foregroundColor(AppColors.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text(role).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
                Spacer()
                Text(sales).font(AppTypography.heading3).foregroundColor(AppColors.accent)
            }
            Divider().background(AppColors.border)
            HStack(spacing: AppSpacing.xl) {
                VStack(spacing: 2) {
                    Text("\(txns)").font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text("Txns").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
                VStack(spacing: 2) {
                    Text(avgTicket).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                    Text("Avg Ticket").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
                VStack(spacing: 2) {
                    Text(convRate).font(AppTypography.label).foregroundColor(AppColors.success)
                    Text("Conv Rate").font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusLarge)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge).stroke(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func perfSupportCard(name: String, role: String, metric: String, detail: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                Text(role).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(metric).font(AppTypography.label).foregroundColor(AppColors.success)
                Text(detail).font(AppTypography.caption).foregroundColor(AppColors.neutral500)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary).cornerRadius(AppSpacing.radiusMedium)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func sLabel(_ t: String) -> some View {
        Text(t).font(AppTypography.overline).tracking(2).foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview {
    ManagerStaffView()
        .modelContainer(for: [User.self], inMemory: true)
}
