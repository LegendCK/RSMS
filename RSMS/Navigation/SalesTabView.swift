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

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

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
            .tint(AppColors.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbarColorScheme(.dark, for: .tabBar)
            .modifier(AppleMusicTabBarModifier())
        }
    }
}

#Preview {
    SalesTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
