//
//  AdminTabView.swift
//  infosys2
//
//  Corporate Admin enterprise tab bar — 5 scalable modules.
//  Dashboard | Operations | Catalog | Organization | Insights
//

import SwiftUI
import SwiftData

struct AdminTabView: View {
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
            AdminDashboardView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                    Text("Dashboard")
                }
                .tag(0)

            OperationsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "shippingbox.fill" : "shippingbox")
                    Text("Operations")
                }
                .tag(1)

            CatalogView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "tag.fill" : "tag")
                    Text("Catalog")
                }
                .tag(2)

            OrganizationView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "building.2.fill" : "building.2")
                    Text("Organization")
                }
                .tag(3)

            InsightsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "chart.bar.fill" : "chart.bar")
                    Text("Insights")
                }
                .tag(4)
        }
    }
}

#Preview {
    AdminTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
