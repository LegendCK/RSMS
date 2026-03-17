//
//  SalesDashboardView.swift
//  RSMS
//
//  Sales Associate dashboard — minimal luxury editorial aesthetic.
//

import SwiftUI
import SwiftData

struct SalesDashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Editorial greeting header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(AppColors.accent)
                        Text(firstName)
                            .font(.system(size: 34, weight: .black))
                            .foregroundColor(.black)
                        Text(Date(), style: .date)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.black.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // KPI row
                    HStack(spacing: 10) {
                        kpiCard(value: "$0", label: "Today's Sales", icon: "dollarsign.circle")
                        kpiCard(value: "0", label: "Clients", icon: "person.2")
                        kpiCard(value: "0", label: "Bookings", icon: "calendar")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // Quick actions
                    sectionHeader("QUICK ACTIONS")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        quickAction(title: "New Client", icon: "person.badge.plus", color: AppColors.accent)
                        quickAction(title: "Book Appointment", icon: "calendar.badge.plus", color: .black)
                        quickAction(title: "Start Sale", icon: "bag.badge.plus", color: AppColors.accent)
                        quickAction(title: "Service Ticket", icon: "wrench.and.screwdriver", color: .black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // Today's appointments
                    sectionHeader("TODAY'S SCHEDULE")

                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 28, weight: .ultraLight))
                                .foregroundColor(.black.opacity(0.2))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No appointments today")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                Text("Your schedule is clear")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 60)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MAISON LUXE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(4)
                    .foregroundColor(.black)
            }
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
            .foregroundColor(.black.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
    }

    private func kpiCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .ultraLight))
                .foregroundColor(AppColors.accent)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            Text(label)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func quickAction(title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .ultraLight))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
