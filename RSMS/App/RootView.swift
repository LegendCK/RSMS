//
//  RootView.swift
//  infosys2
//
//  Root view that switches between app flows based on AppState.
//

import SwiftUI

struct RootView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ZStack {
            switch appState.currentFlow {
            case .splash:
                SplashScreenView()
                    .transition(.opacity)

            case .onboarding:
                OnboardingView()
                    .transition(.opacity)

            case .authentication:
                LoginView()
                    .transition(.opacity)

            case .main:
                MainTabView()
                    .transition(.opacity)

            case .adminDashboard:
                AdminTabView()
                    .transition(.opacity)

            case .managerDashboard:
                ManagerTabView()
                    .transition(.opacity)

            case .salesDashboard:
                SalesTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appState.currentFlow)
        .task {
            // Attempt to restore a live Supabase session on every launch.
            // This runs concurrently with the splash animation.
            // If a session is found, it sets sessionRestored = true which
            // prevents completeSplash() from overriding the routed flow.
            if appState.currentFlow == .splash {
                await appState.tryRestoreSession()
            }
        }
    }
}
