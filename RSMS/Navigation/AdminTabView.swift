//
//  AdminTabView.swift
//  RSMS
//
//  Corporate Admin — 5 tab bar modules.
//  Dashboard | Catalog | Operations | Organization | Profile
//

import SwiftUI
import SwiftData

struct AdminTabView: View {
    @State private var selectedTab = 0

    var body: some View {
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

            NavigationStack { OrganizationView() }
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "building.2.fill" : "building.2")
                    Text("Organization")
                }
                .tag(3)

            NavigationStack { AdminProfileView() }
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .tint(AppColors.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbar(removing: .sidebarToggle)
        .modifier(AppleMusicTabBarModifier())
    }
}

#Preview {
    AdminTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
