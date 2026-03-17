//
//  SalesTabView.swift
//  RSMS
//
//  Sales Associate — 4 tab bar modules.
//  Dashboard | Clients | Appointments | Profile
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

                NavigationStack { SalesAppointmentsView() }
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "calendar.fill" : "calendar")
                        Text("Schedule")
                    }
                    .tag(2)

                NavigationStack { SalesProfileView() }
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                        Text("Profile")
                    }
                    .tag(3)
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
