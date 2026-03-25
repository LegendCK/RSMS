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
    @State private var showAfterSales = false
    @State private var showShippingDocs = false
    @State private var showInventory = false

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
                        kpiCard(value: "$0", label: "Today's Sales", icon: "dollarsign.circle")
                        kpiCard(value: "0", label: "Clients", icon: "person.2")
                        kpiCard(value: "0", label: "Bookings", icon: "calendar")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // Quick actions
                    sectionHeader("QUICK ACTIONS")

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        quickAction(title: "New Client", icon: "person.badge.plus", color: AppColors.accent)
                        quickAction(title: "Book Appointment", icon: "calendar.badge.plus", color: AppColors.info)
                        quickAction(title: "Start Sale", icon: "bag.badge.plus", color: AppColors.accent)
                        Button {
                            showAfterSales = true
                        } label: {
                            quickAction(title: "Service Ticket", icon: "wrench.and.screwdriver", color: AppColors.secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showShippingDocs = true
                        } label: {
                            quickAction(title: "Shipping Docs", icon: "doc.text.fill", color: AppColors.info)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showInventory = true
                        } label: {
                            quickAction(title: "Inventory", icon: "shippingbox.fill", color: AppColors.success)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // Today's schedule
                    sectionHeader("TODAY'S SCHEDULE")

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

                    Spacer().frame(height: 60)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MAISON LUXE")
                    .font(.system(size: 12, weight: .black))
                    .tracking(4)
                    .foregroundColor(.primary)
            }
        }
        .sheet(isPresented: $showAfterSales) {
            SalesAfterSalesView()
        }
        .navigationDestination(isPresented: $showShippingDocs) {
            ShippingDocumentsListView()
        }
        .navigationDestination(isPresented: $showInventory) {
            InventoryOverviewView()
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
