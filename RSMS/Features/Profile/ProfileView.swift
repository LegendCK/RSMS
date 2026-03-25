//
//  ProfileView.swift
//  RSMS
//
//  iOS-native grouped profile — minimal luxury aesthetic.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showLogoutConfirmation = false
    @State private var showSignIn = false

    var body: some View {
        NavigationStack {
            List {
                // Avatar header section
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                            Circle()
                                .strokeBorder(AppColors.accent, lineWidth: 1.5)
                                .frame(width: 60, height: 60)
                            Text(initials)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(appState.isGuest ? "Guest" : appState.currentUserName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                            if appState.isGuest {
                                Text("Browsing as guest")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(appState.currentUserEmail)
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(.secondary)
                            }
                            Text(appState.isGuest ? "GUEST" : appState.currentUserRole.rawValue.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(appState.isGuest ? .secondary : AppColors.accent)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Account section
                if appState.isAuthenticated && !appState.isGuest {
                    Section("Account") {
                        NavigationLink(destination: ClientProfileEditView()) {
                            Label("Edit Profile", systemImage: "person.crop.square")
                        }
                        NavigationLink(destination: OrdersListView()) {
                            Label("My Orders", systemImage: "bag")
                        }
                        NavigationLink(destination: MyExchangeRequestsView()) {
                            Label("My Exchange Requests", systemImage: "arrow.triangle.2.circlepath")
                        }
                        NavigationLink(destination: CustomerServiceTicketsView()) {
                            Label("My Service Tickets", systemImage: "wrench.and.screwdriver")
                        }
                        NavigationLink(destination: PaymentMethodsView()) {
                            Label("Payment Methods", systemImage: "creditcard")
                        }
                        NavigationLink(destination: AddressManagerView()) {
                            Label("Addresses", systemImage: "mappin.and.ellipse")
                        }
                        NavigationLink(destination: WishlistView()) {
                            Label("Wishlist", systemImage: "heart")
                        }
                    }
                }

                // Boutique section — hidden for guests
                if !appState.isGuest {
                    Section("Boutique") {
                        NavigationLink(destination: MyReservationsView()) {
                            Label("My Reservations", systemImage: "clock.arrow.circlepath")
                        }
                        NavigationLink(destination: CustomerBookAppointmentView()) {
                            Label("Book an Appointment", systemImage: "calendar")
                        }
                    }
                }

                // Preferences
                Section("Preferences") {
                    Label("Notifications", systemImage: "bell")
                    Label("Privacy & Security", systemImage: "lock.shield")
                }

                // Support
                Section("Support") {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }

                // Sign in / Sign out
                Section {
                    if appState.isGuest {
                        Button(action: { showSignIn = true }) {
                            HStack {
                                Spacer()
                                Text("Sign In / Create Account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                                Spacer()
                            }
                        }
                    } else {
                        Button(action: { showLogoutConfirmation = true }) {
                            HStack {
                                Spacer()
                                Text("Sign Out")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.error)
                                Spacer()
                            }
                        }
                    }
                }

                Section {
                    Text("MAISON LUXE · Version 1.0.0")
                        .font(.system(size: 10, weight: .light))
                        .tracking(1)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PROFILE")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundColor(.black)
                }
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) { appState.logout() }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showSignIn) {
                GuestAuthGateView(pendingAction: "access your account")
            }
            .task {
                await syncWishlistFromBackend()
            }
        }
    }

    private func syncWishlistFromBackend() async {
        guard appState.isAuthenticated, !appState.isGuest else { return }
        do {
            try await WishlistService.shared.hydrateLocalWishlist(modelContext: modelContext)
        } catch {
            print("[ProfileView] Wishlist sync failed: \(error)")
        }
    }

    private var initials: String {
        let components = appState.currentUserName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "G"
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
