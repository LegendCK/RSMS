//
//  SalesTabView.swift
//  infosys2
//
//  Sales Associate & After-Sales Specialist tab bar — 5 modules.
//  Dashboard | Clients | Appointments | Selling | After-Sales
//

import SwiftUI
import SwiftData

struct SalesTabView: View {
    @State private var selectedTab = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "0A0A0A"))

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color(hex: "555555"))
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "555555")),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "C9A84C"))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "C9A84C")),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SalesDashboardView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                    Text("Dashboard")
                }
                .tag(0)

            SalesClientsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.2.fill" : "person.2")
                    Text("Clients")
                }
                .tag(1)

            SalesAppointmentsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "calendar.badge.clock" : "calendar")
                    Text("Appointments")
                }
                .tag(2)

            AssistedSellingView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "bag.fill" : "bag")
                    Text("Selling")
                }
                .tag(3)

            SalesAfterSalesView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                    Text("After-Sales")
                }
                .tag(4)
        }
    }
}

#Preview {
    SalesTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
