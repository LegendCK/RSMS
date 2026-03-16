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

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

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
            .tint(AppColors.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbarColorScheme(.dark, for: .tabBar)
            .modifier(AppleMusicTabBarModifier())
        }
    }
}

#Preview {
    AdminTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
