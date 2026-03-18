//
//  MainTabView.swift
//  RSMS
//
//  iOS 26 Tab-based API with Liquid Glass tab bar matching Apple Music design.
//  Dark background container with glass pill styling. Search button positioned outside.

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var isPreparingCatalog = true
    @State private var syncErrorMessage: String?

    var body: some View {
        ZStack {
            // Dark blurred background
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            if isPreparingCatalog {
                loadingState
            } else {
                TabView {
                    // Home Tab — path bound to AppState so any screen can pop to root
                    Tab("Home", systemImage: "house.fill") {
                        @Bindable var state = appState
                        NavigationStack(path: $state.homeNavigationPath) {
                            HomeView()
                        }
                    }

                    // Categories Tab
                    Tab("Categories", systemImage: "square.grid.2x2") {
                        NavigationStack {
                            CategoriesView()
                        }
                    }

                    // Appointments Tab
                    Tab("Appointments", systemImage: "calendar.badge.clock") {
                        NavigationStack {
                            CustomerAppointmentsView()
                        }
                    }

                    // Profile Tab
                    Tab("Profile", systemImage: "person.fill") {
                        NavigationStack {
                            ProfileView()
                        }
                    }

                    // Search Tab (system renders this as a separate search control)
                    Tab(role: .search) {
                        NavigationStack {
                            SearchView()
                        }
                    }
                }
                .tint(AppColors.accent)  // Active tab tint (maroon)
                .tabBarMinimizeBehavior(.onScrollDown)  // Collapse on scroll
                .toolbarColorScheme(.dark, for: .tabBar)  // Dark styling
                .toolbar(removing: .sidebarToggle)  // Remove auto-injected "M..." account button
                .modifier(AppleMusicTabBarModifier())  // Apply Apple Music glass design
            }
        }
        .task { await prepareCustomerCatalog() }
    }

    @ViewBuilder
    private var loadingState: some View {
        VStack(spacing: AppSpacing.md) {
            if let syncErrorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AppTypography.iconDecorative)
                    .foregroundColor(AppColors.warning)
                Text("Unable to load catalog")
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(syncErrorMessage)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                SecondaryButton(title: "Retry") {
                    Task { await prepareCustomerCatalog(force: true) }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            } else {
                ProgressView()
                    .tint(AppColors.accent)
                    .scaleEffect(1.1)
                Text("Loading Collection")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Syncing live products from Maison Luxe catalog")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
    }

    private func prepareCustomerCatalog(force: Bool = false) async {
        guard force || isPreparingCatalog else { return }

        do {
            syncErrorMessage = nil
            try await CustomerCatalogSyncService.shared.refreshLocalCatalog(modelContext: modelContext)
            isPreparingCatalog = false
        } catch {
            // Safety: If sync fails but we have cached/seeded categories, allow the app to open.
            // This prevents Guest users from being stuck on the loading screen due to RLS blocks.
            let localCount = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
            if localCount > 0 {
                print("[MainTabView] Sync failed but local data exists. Proceeding. Error: \(error.localizedDescription)")
                self.isPreparingCatalog = false
            } else {
                syncErrorMessage = error.localizedDescription
                isPreparingCatalog = true
            }
        }
    }
}

/// Custom modifier to apply Apple Music-style glass effect to the tab bar
struct AppleMusicTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Configure tab bar appearance with dark glass effect
                let tabBar = UITabBar.appearance()
                
                // Create dark glass appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground()
                
                // Dark semi-transparent glass background
                let backgroundColor = UIColor.black.withAlphaComponent(0.6)
                appearance.backgroundColor = backgroundColor
                
                // Blur effect using shadow for depth
                appearance.shadowColor = UIColor.black.withAlphaComponent(0.2)
                appearance.shadowImage = nil
                
                // Configure item appearance (inactive state - use grey for visibility)
                let itemAppearance = UITabBarItemAppearance()
                itemAppearance.normal.iconColor = UIColor.systemGray
                itemAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor.systemGray,
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium)
                ]
                
                // Selected state - maroon tint
                itemAppearance.selected.iconColor = UIColor(AppColors.accent)  // Maroon
                itemAppearance.selected.titleTextAttributes = [
                    .foregroundColor: UIColor(AppColors.accent),  // Maroon
                    .font: UIFont.systemFont(ofSize: 10, weight: .bold)
                ]
                
                appearance.stackedLayoutAppearance = itemAppearance
                appearance.inlineLayoutAppearance = itemAppearance
                appearance.compactInlineLayoutAppearance = itemAppearance
                
                tabBar.standardAppearance = appearance
                tabBar.scrollEdgeAppearance = appearance
                tabBar.tintColor = UIColor(AppColors.accent)  // Maroon tint
            }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}
