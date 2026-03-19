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

                NavigationStack { ScannerView() }
                    .tabItem {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scanner")
                    }
                    .tag(scannerTabTag)

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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("switchToScannerTab"))) { _ in
                selectedTab = scannerTabTag
            }
        }
    }

    private var operationsTabTag: Int {
        showsDashboard ? 1 : 0
    }

    private var scannerTabTag: Int {
        operationsTabTag + 1
    }

    private var staffTabTag: Int {
        scannerTabTag + 1
    }

    private var profileTabTag: Int {
        staffTabTag + 1
    }
}

#Preview {
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
