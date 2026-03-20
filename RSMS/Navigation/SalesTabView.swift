//
//  SalesTabView.swift
//  RSMS
//
//  Sales Associate — 5 tab bar modules.
//  Dashboard | Clients | Catalog | Appointments | Profile
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
                NavigationStack { SalesDashboardView() }
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                        Text("Dashboard")
                    }
                    .tag(0)

                NavigationStack { SalesClientsView() }
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "person.2.fill" : "person.2")
                        Text("Clients")
                    }
                    .tag(1)

                SACatalogView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "tag.fill" : "tag")
                        Text("Catalog")
                    }
                    .tag(2)

                NavigationStack { SalesAppointmentsView() }
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "calendar.circle.fill" : "calendar.circle")
                        Text("Schedule")
                    }
                    .tag(3)

                NavigationStack { SalesProfileView() }
                    .tabItem {
                        Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                        Text("Profile")
                    }
                    .tag(4)
            }
            .tint(AppColors.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbar(removing: .sidebarToggle)
            .modifier(AppleMusicTabBarModifier())
        }
    }
}

#Preview {
    SalesTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
