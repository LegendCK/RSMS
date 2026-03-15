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

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

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
            .tint(AppColors.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbarColorScheme(.dark, for: .tabBar)
            .modifier(AppleMusicTabBarModifier())
        }
    }
}

#Preview {
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
