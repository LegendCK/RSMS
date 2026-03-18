//
//  AppState.swift
//  infosys2
//
//  Central app state managing authentication and navigation flow.
//

import SwiftUI

enum AppFlow: Equatable {
    case splash
    case onboarding
    case authentication
    case main              // Customer-facing tab bar
    case adminDashboard    // Corporate Admin enterprise panel
    case managerDashboard  // Boutique Manager & Inventory Controller panel
    case salesDashboard    // Sales Associate & Service Technician panel
}

@Observable
class AppState {
    var currentFlow: AppFlow = .splash

    // MARK: - Persisted flags
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Navigation
    var homeNavigationPath: NavigationPath = NavigationPath()
    var showCart: Bool = false  // Programmatic cart navigation

    /// Set to true by navigateToHome(); CartView and BuyNowSheetView observe this
    /// to dismiss themselves before the path is cleared.
    var shouldNavigateHome: Bool = false

    /// Pops the customer Home NavigationStack all the way back to HomeView.
    /// Also signals any sheet/nested-stack views (CartView, BuyNowSheetView) to dismiss.
    func navigateToHome() {
        print("[AppState] navigateToHome() called")
        print("[AppState] Current homeNavigationPath count: \(homeNavigationPath.count)")
        shouldNavigateHome   = true
        showCart            = false  // Reset cart navigation
        homeNavigationPath   = NavigationPath()
        print("[AppState] homeNavigationPath cleared, new count: \(homeNavigationPath.count)")
        
        // Reset the flag after a brief delay to allow views to observe the change
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            shouldNavigateHome = false
            print("[AppState] shouldNavigateHome reset to false")
        }
    }

    // MARK: - Session state
    var isAuthenticated: Bool = false
    var isGuest: Bool = false                // true when browsing without an account
    var currentUserName: String = ""
    var currentUserEmail: String = ""
    var currentUserRole: UserRole = .customer
    var currentStoreId: UUID? = nil          // nil for corporate_admin and client
    var currentUserProfile: UserDTO? = nil   // Full Supabase profile
    var currentClientProfile: ClientDTO? = nil
    var sessionRestored: Bool = false        // Prevents splash from overriding restored session

    // MARK: - Splash / Onboarding

    func completeSplash() {
        // If session was already restored (user is logged in), don't override the flow
        guard !sessionRestored else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            currentFlow = hasCompletedOnboarding ? .authentication : .onboarding
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.5)) {
            currentFlow = .authentication
        }
    }

    // MARK: - Guest Access

    func continueAsGuest() async {
        isGuest = true
        currentUserName = "Guest"
        currentUserEmail = ""
        currentUserRole = .customer
        currentUserProfile = nil
        currentClientProfile = nil
        
        // Ensure an authenticated session exists before switching to the main flow.
        // This permits the catalog sync in MainTabView to succeed against RLS policies.
        try? await AuthService.shared.signInAnonymously()
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentFlow = .main
            }
        }
    }

    // MARK: - Login (called after Supabase Auth succeeds)

    func login(profile: UserDTO) {
        isGuest            = false
        currentUserProfile = profile
        currentUserName    = profile.fullName
        currentUserEmail   = profile.email
        currentUserRole    = profile.userRole
        currentStoreId     = profile.storeId
        isAuthenticated    = true
        currentClientProfile = nil

        withAnimation(.easeInOut(duration: 0.5)) {
            switch profile.userRole {
            case .corporateAdmin:
                currentFlow = .adminDashboard
            case .boutiqueManager, .inventoryController:
                currentFlow = .managerDashboard
            case .salesAssociate, .serviceTechnician:
                currentFlow = .salesDashboard
            case .customer:
                currentFlow = .main
            }
        }
    }

    /// Legacy convenience — keeps local SwiftData login working during transition.
    func login(name: String, email: String, role: UserRole = .customer) {
        isGuest          = false
        currentUserName  = name
        currentUserEmail = email
        currentUserRole  = role
        isAuthenticated  = true
        currentUserProfile = nil
        currentClientProfile = nil

        withAnimation(.easeInOut(duration: 0.5)) {
            switch role {
            case .corporateAdmin:
                currentFlow = .adminDashboard
            case .boutiqueManager, .inventoryController:
                currentFlow = .managerDashboard
            case .salesAssociate, .serviceTechnician:
                currentFlow = .salesDashboard
            case .customer:
                currentFlow = .main
            }
        }
    }

    /// Updates in-memory identity fields after editing the authenticated client profile.
    func updateCurrentClientProfile(_ profile: ClientDTO) {
        currentClientProfile = profile
        currentUserProfile = UserDTO(clientProfile: profile)
        currentUserName = profile.fullName
        currentUserEmail = profile.email
        currentUserRole = .customer
        currentStoreId = nil
    }

    // MARK: - Logout

    func logout() {
        isAuthenticated    = false
        isGuest            = false
        currentUserName    = ""
        currentUserEmail   = ""
        currentUserRole    = .customer
        currentStoreId     = nil
        currentUserProfile = nil
        currentClientProfile = nil

        withAnimation(.easeInOut(duration: 0.5)) {
            currentFlow = .authentication
        }

        // Sign out from Supabase in background
        Task {
            try? await AuthService.shared.signOut()
        }
    }

    // MARK: - Session Restore (called on app launch after splash)

    func tryRestoreSession() async {
        if let profile = await AuthService.shared.restoreSession() {
            await MainActor.run {
                sessionRestored = true
                login(profile: profile)
            }
        }
    }
}
