//
//  ManagerTabView.swift
//  RSMS
//
//  Boutique Manager & Inventory Controller tab bar.
//
//  Tab layout:
//    Manager  → Dashboard | Operations | Scanner | Staff | Profile
//    IC       → Operations | Scanner | Repairs | Staff | Profile
//
//  The Repairs tab is injected only for inventoryController so boutique
//  managers never see it. Tab tags are computed to stay contiguous
//  regardless of which conditional tabs are shown.
//
//  REPLACE the existing ManagerTabView.swift with this file.
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

                // ── Dashboard (Boutique Manager only) ─────────────────────
                if showsDashboard {
                    NavigationStack { ManagerDashboardView() }
                        .tabItem {
                            Image(systemName: selectedTab == 0
                                  ? "square.grid.2x2.fill" : "square.grid.2x2")
                            Text("Dashboard")
                        }
                        .tag(0)
                }

                // ── Operations ────────────────────────────────────────────
                NavigationStack { ManagerOperationsView() }
                    .tabItem {
                        Image(systemName: selectedTab == operationsTag
                              ? "list.clipboard.fill" : "list.clipboard")
                        Text("Operations")
                    }
                    .tag(operationsTag)

                // ── Scanner ───────────────────────────────────────────────
                NavigationStack { ScannerView() }
                    .tabItem {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scanner")
                    }
                    .tag(scannerTag)

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

                // ── Staff ─────────────────────────────────────────────────
                NavigationStack { ManagerStaffView() }
                    .tabItem {
                        Image(systemName: selectedTab == staffTag
                              ? "person.2.fill" : "person.2")
                        Text("Staff")
                    }
                    .tag(staffTag)

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
            .onChange(of: showsDashboard) { _, newValue in
                if !newValue && selectedTab == 0 { selectedTab = operationsTag }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("switchToScannerTab"))
            ) { _ in
                selectedTab = scannerTag
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("switchToRepairsTab"))
            ) { _ in
                if isIC { selectedTab = repairsTag }
            }
        }
    }

    // MARK: - Tab Tags
    //
    // Tags are consecutive integers. The Repairs slot only exists for IC
    // users, so staffTag and profileTag shift accordingly.

    private var operationsTag: Int { showsDashboard ? 1 : 0 }
    private var scannerTag:    Int { operationsTag + 1 }
    private var repairsTag:    Int { scannerTag + 1 }           // IC only
    private var staffTag:      Int { isIC ? repairsTag + 1 : scannerTag + 1 }
    private var profileTag:    Int { staffTag + 1 }
}

#Preview {
    ManagerTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
