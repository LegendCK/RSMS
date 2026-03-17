//
//  ManagerTabView.swift
//  RSMS
//
//  Boutique Manager — 4 tab bar modules.
//  Dashboard | Operations | Staff | Profile
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
                NavigationStack { ManagerDashboardView() }
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                        Text("Dashboard")
                    }
                    .tag(0)

                NavigationStack { ManagerOperationsView() }
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "list.clipboard.fill" : "list.clipboard")
                        Text("Operations")
                    }
                    .tag(1)

                NavigationStack { ManagerStaffView() }
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "person.2.fill" : "person.2")
                        Text("Staff")
                    }
                    .tag(2)

                NavigationStack { ManagerProfileView() }
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                        Text("Profile")
                    }
                    .tag(3)
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
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
