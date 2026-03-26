//
//  SalesDashboardView.swift
//  RSMS
//
//  Sales Associate dashboard — maroon gradient header, KPIs, quick actions, schedule.
//

import SwiftUI
import SwiftData

struct SalesDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SalesDashboardViewModel()
    @State private var activeSheet: ActiveSalesSheet? = nil
    @State private var showLooksList = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Maroon top glow
            LinearGradient(
                colors: [AppColors.accent.opacity(0.13), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.28)
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Greeting header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(AppColors.accent)
                        Text(firstName)
                            .font(.system(size: 34, weight: .black))
                            .foregroundColor(.primary)
                        Text(Date(), style: .date)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    // KPI row
                    HStack(spacing: 12) {
                        kpiCard(value: vm.formattedTodaySales, label: "Today's Sales", icon: "dollarsign.circle")
                        kpiCard(value: "\(vm.clientCount)", label: "Clients", icon: "person.2")
                        kpiCard(value: "\(vm.todayBookingCount)", label: "Bookings", icon: "calendar")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // Quick actions
                    sectionHeader("QUICK ACTIONS")

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        Button {
                            activeSheet = .newClient
                        } label: {
                            quickAction(title: "New Client", icon: "person.badge.plus", color: AppColors.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            activeSheet = .bookAppointment
                        } label: {
                            quickAction(title: "Book Appointment", icon: "calendar.badge.plus", color: AppColors.secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            activeSheet = .allTickets
                        } label: {
                            quickAction(title: "Service Tickets", icon: "wrench.and.screwdriver", color: AppColors.info)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showLooksList = true
                        } label: {
                            quickAction(title: "Curated Looks", icon: "sparkles.rectangle.stack.fill", color: AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // Today's schedule
                    sectionHeader("TODAY'S SCHEDULE")

                    if vm.todayAppointments.isEmpty {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 28, weight: .ultraLight))
                                .foregroundColor(.secondary.opacity(0.4))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No appointments today")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Your schedule is clear")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(vm.todayAppointments.enumerated()), id: \.element.id) { idx, appt in
                                appointmentRow(appt, isLast: idx == vm.todayAppointments.count - 1)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 60)
                }
            }
        }
        .task { await vm.load(storeId: appState.currentStoreId) }
        .refreshable { await vm.load(storeId: appState.currentStoreId) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MAISON LUXE")
                    .font(.system(size: 12, weight: .black))
                    .tracking(4)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NotificationCenterView(showsCloseButton: false).toolbar(.hidden, for: .tabBar)) {
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newClient:
                NavigationStack {
                    CreateClientProfileView()
                }
            case .bookAppointment:
                CreateAppointmentView()
            case .allTickets:
                NavigationStack {
                    ServiceTicketListView()
                }
            }
        }
        .navigationDestination(isPresented: $showLooksList) {
            LooksListView()
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good Morning" : h < 17 ? "Good Afternoon" : "Good Evening"
    }

    private var firstName: String {
        appState.currentUserName.split(separator: " ").first.map(String.init) ?? "Advisor"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .tracking(3)
            .foregroundColor(.primary.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
    }

    private func kpiCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .ultraLight))
                .foregroundColor(AppColors.accent)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private func appointmentRow(_ appt: AppointmentDTO, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(appt.scheduledAt, style: .time)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .monospacedDigit()
                    Text("\(appt.durationMinutes)m")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.secondary)
                }
                .frame(width: 62, alignment: .trailing)

                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.accent.opacity(0.35))
                    .frame(width: 3, height: 36)

                // Details
                VStack(alignment: .leading, spacing: 3) {
                    Text(appt.type.capitalized.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let client = vm.clientsById[appt.clientId] {
                        Text(client.fullName)
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .layoutPriority(1)
                Spacer()

                // Status badge
                Text(appt.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(appt.status == "confirmed" ? AppColors.success : AppColors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((appt.status == "confirmed" ? AppColors.success : AppColors.accent).opacity(0.10))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider().padding(.leading, 80)
            }
        }
    }

    private func quickAction(title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .ultraLight))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 90)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

private enum ActiveSalesSheet: String, Identifiable {
    case newClient
    case bookAppointment
    case allTickets

    var id: String { rawValue }
}
