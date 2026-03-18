//
//  ManagerTabView.swift
//  RSMS
//
//  Boutique Manager / Inventory Controller tab modules.
//  Dashboard (manager-only) | Operations | Inventory | Staff | Profile
//

import SwiftUI
import SwiftData

struct ManagerTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    private var showsDashboard: Bool {
        appState.currentUserRole == .boutiqueManager
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                if showsDashboard {
                    NavigationStack { ManagerDashboardView() }
                        .tabItem {
                            Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                            Text("Dashboard")
                        }
                        .tag(0)
                }

                NavigationStack { ManagerOperationsView() }
                    .tabItem {
                        Image(systemName: selectedTab == operationsTabTag ? "list.clipboard.fill" : "list.clipboard")
                        Text("Operations")
                    }
                    .tag(operationsTabTag)

                NavigationStack { ManagerInventoryView() }
                    .tabItem {
                        Image(systemName: selectedTab == inventoryTabTag ? "shippingbox.fill" : "shippingbox")
                        Text("Inventory")
                    }
                    .tag(inventoryTabTag)

                NavigationStack { ManagerStaffView() }
                    .tabItem {
                        Image(systemName: selectedTab == staffTabTag ? "person.2.fill" : "person.2")
                        Text("Staff")
                    }
                    .tag(staffTabTag)

                NavigationStack { ManagerProfileView() }
                    .tabItem {
                        Image(systemName: selectedTab == profileTabTag ? "person.fill" : "person")
                        Text("Profile")
                    }
                    .tag(profileTabTag)
            }
            .tint(AppColors.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbar(removing: .sidebarToggle)
            .modifier(AppleMusicTabBarModifier())
            .onChange(of: showsDashboard) { _, newValue in
                if !newValue && selectedTab == 0 {
                    selectedTab = operationsTabTag
                }
            }
        }
    }

    private var operationsTabTag: Int {
        showsDashboard ? 1 : 0
    }

    private var staffTabTag: Int {
        showsDashboard ? 3 : 2
    }

    private var inventoryTabTag: Int {
        showsDashboard ? 2 : 1
    }

    private var profileTabTag: Int {
        showsDashboard ? 4 : 3
    }
}

#Preview {
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
