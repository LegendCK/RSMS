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

    // MARK: - Session state
    var isAuthenticated: Bool = false
    var currentUserName: String = ""
    var currentUserEmail: String = ""
    var currentUserRole: UserRole = .customer
    var currentStoreId: UUID? = nil          // nil for corporate_admin and client
    var currentUserProfile: UserDTO? = nil   // Full Supabase profile
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

    // MARK: - Login (called after Supabase Auth succeeds)

    func login(profile: UserDTO) {
        currentUserProfile = profile
        currentUserName    = profile.fullName
        currentUserEmail   = profile.email
        currentUserRole    = profile.userRole
        currentStoreId     = profile.storeId
        isAuthenticated    = true

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
        currentUserName  = name
        currentUserEmail = email
        currentUserRole  = role
        isAuthenticated  = true

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

    // MARK: - Logout

    func logout() {
        isAuthenticated    = false
        currentUserName    = ""
        currentUserEmail   = ""
        currentUserRole    = .customer
        currentStoreId     = nil
        currentUserProfile = nil

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
