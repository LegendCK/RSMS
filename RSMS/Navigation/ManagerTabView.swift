//
//  ManagerTabView.swift
//  RSMS
//
//  Boutique Manager & Inventory Controller tab bar.
//
//  Tab layout:
//    Manager  → Dashboard | Insights | Operations | Staff | Profile
//    IC       → Dashboard | Operations | Scanner | Repairs | Profile
//
//  Inventory Controllers get their own Dashboard (inventory-focused) and
//  do NOT see the Staff tab — that is Boutique Manager-only.
//  Tab tags are computed to stay contiguous regardless of role.
//

import SwiftUI
import SwiftData

struct ManagerTabView: View {

    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    // MARK: - Role Flags

    private var showsDashboard: Bool {
        appState.currentUserRole == .boutiqueManager
    }

    private var isIC: Bool {
        appState.currentUserRole == .inventoryController
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            TabView(selection: $selectedTab) {

                // ── Dashboard (both roles, different views) ────────────────
                if showsDashboard {
                    NavigationStack { ManagerDashboardView() }
                        .tabItem {
                            Image(systemName: selectedTab == 0
                                  ? "square.grid.2x2.fill" : "square.grid.2x2")
                            Text("Dashboard")
                        }
                        .tag(0)
                } else if isIC {
                    NavigationStack { ICDashboardView() }
                        .tabItem {
                            Image(systemName: selectedTab == 0
                                  ? "square.grid.2x2.fill" : "square.grid.2x2")
                            Text("Dashboard")
                        }
                        .tag(0)
                }

                // ── Insights (Boutique Manager only) ──────────────────────
                if showsDashboard {
                    NavigationStack { ManagerInsightsView() }
                        .tabItem {
                            Image(systemName: selectedTab == insightsTag
                                  ? "chart.bar.fill" : "chart.bar")
                            Text("Insights")
                        }
                        .tag(insightsTag)
                }

                // ── Operations ────────────────────────────────────────────
                NavigationStack { ManagerOperationsView() }
                    .tabItem {
                        Image(systemName: selectedTab == operationsTag
                              ? "list.clipboard.fill" : "list.clipboard")
                        Text("Operations")
                    }
                    .tag(operationsTag)

                // ── Scanner (Inventory Controller only) ───────────────────
                if isIC {
                    NavigationStack { ScannerView() }
                        .tabItem {
                            Image(systemName: "barcode.viewfinder")
                            Text("Scanner")
                        }
                        .tag(scannerTag)
                }

                // ── Repairs (Inventory Controller only) ───────────────────
                if isIC {
                    NavigationStack {
                        RepairTicketsListView(storeId: appState.currentStoreId ?? UUID())
                    }
                    .tabItem {
                        Image(systemName: selectedTab == repairsTag
                              ? "wrench.and.screwdriver.fill"
                              : "wrench.and.screwdriver")
                        Text("Repairs")
                    }
                    .tag(repairsTag)
                }

                // ── Staff (Boutique Manager only) ─────────────────────────
                if showsDashboard {
                    NavigationStack { ManagerStaffView() }
                        .tabItem {
                            Image(systemName: selectedTab == staffTag
                                  ? "person.2.fill" : "person.2")
                            Text("Staff")
                        }
                        .tag(staffTag)
                }

                // ── Profile ───────────────────────────────────────────────
                NavigationStack { ManagerProfileView() }
                    .tabItem {
                        Image(systemName: selectedTab == profileTag
                              ? "person.fill" : "person")
                        Text("Profile")
                    }
                    .tag(profileTag)
            }
            .tint(AppColors.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbar(removing: .sidebarToggle)
            .modifier(AppleMusicTabBarModifier())
            .onChange(of: showsDashboard) { _, _ in
                selectedTab = 0   // both roles start at Dashboard
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("switchToScannerTab"))
            ) { _ in
                if isIC { selectedTab = scannerTag }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("switchToRepairsTab"))
            ) { _ in
                if isIC { selectedTab = repairsTab }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("switchToOperationsTab"))
            ) { _ in
                selectedTab = operationsTag
            }
        }
    }

    // MARK: - Tab Tags
    //
    // Manager: 0=Dashboard, 1=Insights, 2=Operations, 3=Staff, 4=Profile
    // IC:      0=Dashboard, 1=Operations, 2=Scanner, 3=Repairs, 4=Profile

    private var insightsTag:   Int { 1 }                        // Manager only
    private var operationsTag: Int { showsDashboard ? 2 : 1 }   // Manager=2, IC=1
    private var scannerTag:    Int { isIC ? 2 : operationsTag }  // IC only
    private var repairsTag:    Int { isIC ? 3 : scannerTag }     // IC only
    private var staffTag:      Int { showsDashboard ? operationsTag + 1 : profileTag }  // Manager only
    private var profileTag:    Int { isIC ? 4 : staffTag + 1 }

    // Alias for notification handler (avoids "repairsTag" being used as a tag expression)
    private var repairsTab: Int { repairsTag }
}

#Preview {
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
