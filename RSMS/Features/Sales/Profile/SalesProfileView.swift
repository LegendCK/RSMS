//
//  SalesProfileView.swift
//  RSMS
//
//  Sales Associate profile — iOS-native grouped style matching ProfileView.
//

import SwiftUI

struct SalesProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showLogoutConfirmation = false

    var body: some View {
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
                            Text(displayName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                            Text(appState.currentUserEmail)
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(.secondary)
                            Text("SALES ASSOCIATE & AFTER-SALES SPECIALIST")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Account section
                Section("Account") {
                    NavigationLink(destination: SalesSimpleInfoView(title: "My Performance", message: "Track daily targets, conversion, and revenue performance.").toolbar(.hidden, for: .tabBar)) {
                        Label("My Performance", systemImage: "chart.bar.fill")
                    }
                    NavigationLink(destination: SalesSimpleInfoView(title: "Notifications", message: "Manage appointment alerts, follow-up reminders, and operational updates.").toolbar(.hidden, for: .tabBar)) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    NavigationLink(destination: SalesSimpleInfoView(title: "Settings", message: "Configure app preferences and account behavior.").toolbar(.hidden, for: .tabBar)) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }

                // Boutique section
                Section("Boutique") {
                    NavigationLink(destination: SalesAppointmentsView().toolbar(.hidden, for: .tabBar)) {
                        Label("Appointments", systemImage: "calendar")
                    }
                    NavigationLink(destination: SalesClientsView().toolbar(.hidden, for: .tabBar)) {
                        Label("Clienteling", systemImage: "person.2")
                    }
                    NavigationLink(destination: SACatalogView().toolbar(.hidden, for: .tabBar)) {
                        Label("Catalog", systemImage: "tag")
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

    private var displayName: String {
        appState.currentUserName.isEmpty ? "Sales Associate" : appState.currentUserName
    }

    private var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "SA"
    }
}

private struct SalesSimpleInfoView: View {
    let title: String
    let message: String

    var body: some View {
        List {
            Section {
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title.uppercased())
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
            }
        }
    }
}

#Preview {
    SalesProfileView()
        .environment(AppState())
}
