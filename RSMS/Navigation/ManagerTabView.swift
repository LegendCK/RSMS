//
//  ManagerTabView.swift
//  RSMS
//
//  Boutique Manager: Dashboard | Operations | Staff | Profile
//  Inventory Controller: Scanner | Operations | Staff | Profile
//

import SwiftUI
import SwiftData

struct ManagerTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    private var showsDashboard: Bool {
        appState.currentUserRole == .boutiqueManager
    }

    private var showsScanner: Bool {
        appState.currentUserRole == .inventoryController
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                // Boutique Manager: Dashboard tab
                if showsDashboard {
                    NavigationStack { ManagerDashboardView() }
                        .tabItem {
                            Image(systemName: selectedTab == 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
                            Text("Dashboard")
                        }
                        .tag(0)
                }

                // Inventory Controller: Scanner tab
                if showsScanner {
                    NavigationStack { ScannerView() }
                        .tabItem {
                            Image(systemName: "barcode.viewfinder")
                            Text("Scanner")
                        }
                        .tag(scannerTabTag)
                }

                NavigationStack { ManagerOperationsView() }
                    .tabItem {
                        Image(systemName: selectedTab == operationsTabTag ? "list.clipboard.fill" : "list.clipboard")
                        Text("Operations")
                    }
                    .tag(operationsTabTag)

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
                    selectedTab = showsScanner ? scannerTabTag : operationsTabTag
                }
            }
        }
    }

    /// Tag 0 is reserved for Dashboard (boutiqueManager) or Scanner (inventoryController).
    private var scannerTabTag: Int { 0 }

    private var operationsTabTag: Int {
        (showsDashboard || showsScanner) ? 1 : 0
    }

    private var staffTabTag: Int {
        (showsDashboard || showsScanner) ? 2 : 1
    }

    private var profileTabTag: Int {
        (showsDashboard || showsScanner) ? 3 : 2
    }
}

#Preview {
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
