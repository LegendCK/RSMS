//
//  ManagerTabView.swift
//  infosys2
//
//  Boutique Manager tab bar — 5 store-operations modules.
//  Dashboard | Operations | Staff | Inventory | Insights
//

import SwiftUI
import SwiftData

struct ManagerTabView: View {
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
            ManagerDashboardView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                    Text("Dashboard")
                }
                .tag(0)

            ManagerOperationsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "list.clipboard.fill" : "list.clipboard")
                    Text("Operations")
                }
                .tag(1)

            ManagerStaffView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.2.fill" : "person.2")
                    Text("Staff")
                }
                .tag(2)

            ManagerInventoryView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "shippingbox.fill" : "shippingbox")
                    Text("Inventory")
                }
                .tag(3)

            ManagerInsightsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "chart.bar.fill" : "chart.bar")
                    Text("Insights")
                }
                .tag(4)
        }
    }
}

#Preview {
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
