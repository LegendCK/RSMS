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
    @Query private var allCartItems: [CartItem]

    private var cartBadgeCount: Int {
        allCartItems.filter { $0.customerEmail == appState.currentUserEmail }.count
    }

    var body: some View {
        ZStack {
            // Dark blurred background
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            TabView {
                // Home Tab
                Tab("Home", systemImage: "house.fill") {
                    NavigationStack {
                        HomeView()
                    }
                }

                // Categories Tab
                Tab("Categories", systemImage: "square.grid.2x2") {
                    NavigationStack {
                        CategoriesView()
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
            .modifier(AppleMusicTabBarModifier())  // Apply Apple Music glass design
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
                
                // Dark semi-transparent background
                let backgroundColor = UIColor.black.withAlphaComponent(0.3)
                appearance.backgroundColor = backgroundColor
                
                // Blur effect using shadow for depth
                appearance.shadowColor = UIColor.black.withAlphaComponent(0.2)
                appearance.shadowImage = nil
                
                // Configure item appearance (light text)
                let itemAppearance = UITabBarItemAppearance()
                itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.6)
                itemAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium)
                ]
                
                // Selected state - maroon tint
                itemAppearance.selected.iconColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)  // Maroon
                itemAppearance.selected.titleTextAttributes = [
                    .foregroundColor: UIColor(red: 0.5, green: 0, blue: 0, alpha: 1),  // Maroon
                    .font: UIFont.systemFont(ofSize: 10, weight: .bold)
                ]
                
                appearance.stackedLayoutAppearance = itemAppearance
                appearance.inlineLayoutAppearance = itemAppearance
                appearance.compactInlineLayoutAppearance = itemAppearance
                
                tabBar.standardAppearance = appearance
                tabBar.scrollEdgeAppearance = appearance
                tabBar.tintColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)  // Maroon tint
            }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Category.self, User.self], inMemory: true)
}

