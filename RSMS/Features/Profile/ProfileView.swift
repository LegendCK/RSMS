//
//  ProfileView.swift
//  RSMS
//
//  iOS-native grouped profile — minimal luxury aesthetic.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) var appState
    @State private var showLogoutConfirmation = false

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
                            Text(appState.currentUserName.isEmpty ? "Guest" : appState.currentUserName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                            Text(appState.currentUserEmail)
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(.secondary)
                            Text(appState.currentUserRole.rawValue.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
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
                        NavigationLink(destination: PaymentMethodsView()) {
                            Label("Payment Methods", systemImage: "creditcard")
                        }
                        NavigationLink(destination: AddressManagerView()) {
                            Label("Addresses", systemImage: "mappin.and.ellipse")
                        }
                    }
                }

                // Boutique section
                Section("Boutique") {
                    Label("Book an Appointment", systemImage: "calendar")
                    Label("Wishlist", systemImage: "heart")
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

                // Sign out
                Section {
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
