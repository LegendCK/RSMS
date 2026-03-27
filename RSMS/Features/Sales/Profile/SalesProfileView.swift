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
                                .foregroundColor(.primary)
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
                    NavigationLink(destination: SalesPerformanceView().toolbar(.hidden, for: .tabBar)) {
                        Label("My Performance", systemImage: "chart.bar.fill")
                    }
                    NavigationLink(destination: SalesNotificationSettingsView().toolbar(.hidden, for: .tabBar)) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    NavigationLink(destination: SalesAssociateSettingsView().toolbar(.hidden, for: .tabBar)) {
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
                    NavigationLink(destination: SalesInfoView(title: "Privacy & Security", message: "Manage account protection settings, access controls, and secure usage practices.").toolbar(.hidden, for: .tabBar)) {
                        Label("Privacy & Security", systemImage: "lock.shield")
                    }
                }

                // Support
                Section("Support") {
                    NavigationLink(destination: SalesInfoView(title: "Help & Support", message: "Reach operations support, report app issues, and view support guidance for daily retail workflows.").toolbar(.hidden, for: .tabBar)) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
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
                        .foregroundColor(.primary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 8)
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

private struct SalesPerformanceView: View {
    var body: some View {
        List {
            Section("Today") {
                metricRow(icon: "indianrupeesign.circle.fill", title: "Sales Achieved", value: "₹2,45,000")
                metricRow(icon: "bag.fill", title: "Orders Closed", value: "6")
                metricRow(icon: "person.2.fill", title: "Clients Assisted", value: "14")
            }

            Section("Week To Date") {
                metricRow(icon: "chart.line.uptrend.xyaxis", title: "Conversion Rate", value: "31%")
                metricRow(icon: "calendar", title: "Appointments Completed", value: "18")
                metricRow(icon: "arrow.clockwise.circle.fill", title: "Repeat Clients", value: "7")
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MY PERFORMANCE")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    @ViewBuilder
    private func metricRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            Text(title)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

private struct SalesNotificationSettingsView: View {
    @State private var appointmentAlerts = true
    @State private var clientFollowUps = true
    @State private var operationalUpdates = true
    @State private var stockAlerts = false

    var body: some View {
        List {
            Section("Alert Channels") {
                Toggle("Appointment Alerts", isOn: $appointmentAlerts)
                Toggle("Client Follow-Up Reminders", isOn: $clientFollowUps)
                Toggle("Operational Updates", isOn: $operationalUpdates)
                Toggle("Stock Alerts", isOn: $stockAlerts)
            }

            Section("Delivery") {
                Label("In-app notifications are enabled", systemImage: "app.badge")
                    .foregroundColor(.secondary)
                Label("Push notifications are enabled", systemImage: "iphone.badge.checkmark")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("NOTIFICATIONS")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
            }
        }
    }
}

private struct SalesAssociateSettingsView: View {
    @State private var compactCatalogMode = false
    @State private var showTaxHints = true
    @State private var biometricLock = true

    var body: some View {
        List {
            Section("Point of Sale") {
                Toggle("Compact Catalog Grid", isOn: $compactCatalogMode)
                Toggle("Show Tax-Free Guidance", isOn: $showTaxHints)
            }

            Section("Security") {
                Toggle("Biometric App Lock", isOn: $biometricLock)
                Label("Session expires after inactivity", systemImage: "lock.shield")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SETTINGS")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
            }
        }
    }
}

private struct SalesInfoView: View {
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
