//
//  AdminTabView.swift
//  RSMS
//
//  Corporate Admin — 4 tab bar modules.
//  Dashboard | Catalog | Operations | Profile
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
                NavigationStack { AdminDashboardView() }
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                        Text("Dashboard")
                    }
                    .tag(0)

                NavigationStack { CatalogView() }
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "tag.fill" : "tag")
                        Text("Catalog")
                    }
                    .tag(1)

                NavigationStack { OperationsView() }
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "shippingbox.fill" : "shippingbox")
                        Text("Operations")
                    }
                    .tag(2)

                NavigationStack { AdminProfileView() }
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
    AdminTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
