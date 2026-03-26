//
//  AdminProfileView.swift
//  infosys2
//
//  Corporate Admin profile with working navigation to account, security,
//  monitoring, and preferences surfaces.
//

import SwiftUI

private enum AdminProfileDestination: Hashable {
    case adminProfile
    case changePassword
    case biometricLogin
    case clientActivity
    case roleAccess
    case accessLogs
    case auditTrail
    case securityPolicies
    case systemConfiguration
    case notificationSettings
    case helpDocumentation
}

struct AdminProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showLogoutConfirmation = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    profileHeader

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    sectionHeader("ACCOUNT")
                    VStack(spacing: 0) {
                        profileRow(destination: .adminProfile, icon: "person.text.rectangle", title: "Admin Profile", subtitle: "Name, email, phone")
                        profileRow(destination: .changePassword, icon: "key.fill", title: "Change Password", subtitle: "Update credentials")
                        profileRow(destination: .biometricLogin, icon: "faceid", title: "Biometric Login", subtitle: "Face ID / Touch ID")
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    sectionHeader("CLIENT PORTAL MONITORING")
                    VStack(spacing: 0) {
                        profileRow(
                            destination: .clientActivity,
                            icon: "chart.xyaxis.line",
                            title: "Customer Activity Monitor",
                            subtitle: "Orders, reservations, returns & fulfillment"
                        )
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    sectionHeader("SYSTEM SECURITY")
                    VStack(spacing: 0) {
                        profileRow(destination: .roleAccess, icon: "shield.checkered", title: "Role-Based Access Control", subtitle: "Manage permissions")
                        profileRow(destination: .accessLogs, icon: "clock.arrow.circlepath", title: "Access Logs", subtitle: "View login history")
                        profileRow(destination: .auditTrail, icon: "doc.text.magnifyingglass", title: "Audit Trail", subtitle: "System change log")
                        profileRow(destination: .securityPolicies, icon: "lock.shield", title: "Security Policies", subtitle: "Password & session rules")
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    sectionHeader("SYSTEM")
                    VStack(spacing: 0) {
                        profileRow(destination: .systemConfiguration, icon: "gearshape.2", title: "System Configuration", subtitle: "App settings & preferences")
                        profileRow(destination: .notificationSettings, icon: "bell.badge", title: "Notification Settings", subtitle: "Alerts & push notifications")
                        profileRow(destination: .helpDocumentation, icon: "questionmark.circle", title: "Help & Documentation", subtitle: "Admin guides")
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    GoldDivider()
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    Button(action: { showLogoutConfirmation = true }) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(AppTypography.menuIcon)
                            Text("Sign Out")
                                .font(AppTypography.buttonSecondary)
                        }
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.touchTarget)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    Text("Maison Luxe RSMS v1.0.0 • Admin Console")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.neutral600)
                        .padding(.bottom, AppSpacing.xxxl)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AdminProfileDestination.self) { destination in
            destinationView(for: destination)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
        }
        .alert("Sign Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) { appState.logout() }
        } message: {
            Text("You will be signed out of the admin console.")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .stroke(AppColors.secondary.opacity(0.2), lineWidth: 1)
                    .frame(width: 116, height: 116)

                Circle()
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 100, height: 100)

                Circle()
                    .stroke(AppColors.accent, lineWidth: 2)
                    .frame(width: 100, height: 100)

                Text(initials)
                    .font(AppTypography.displayMedium)
                    .foregroundColor(AppColors.accent)
            }

            VStack(spacing: AppSpacing.xxs) {
                Text(appState.currentUserName)
                    .font(AppTypography.heading1)
                    .foregroundColor(AppColors.textPrimaryDark)

                Text(appState.currentUserEmail)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "shield.checkered")
                        .font(AppTypography.storeIcon)
                    Text("CORPORATE ADMIN")
                        .font(AppTypography.overline)
                        .tracking(2)
                }
                .foregroundColor(AppColors.accent)
                .padding(.top, AppSpacing.xxs)
            }
        }
        .padding(.top, AppSpacing.xxl)
    }

    private var initials: String {
        let parts = appState.currentUserName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(appState.currentUserName.prefix(2)).uppercased()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func profileRow(destination: AdminProfileDestination, icon: String, title: String, subtitle: String) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(AppTypography.menuIcon)
                    .foregroundColor(AppColors.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.chevron)
                    .foregroundColor(AppColors.neutral600)
            }
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(for destination: AdminProfileDestination) -> some View {
        switch destination {
        case .adminProfile:
            AdminProfileDetailsView()
                .environment(appState)
        case .changePassword:
            AdminCredentialSettingsView()
        case .biometricLogin:
            AdminBiometricSettingsView()
        case .clientActivity:
            CorporateAdminClientActivityView()
                .environment(appState)
        case .roleAccess:
            AdminRoleAccessView()
        case .accessLogs:
            AdminAccessLogsView()
                .environment(appState)
        case .auditTrail:
            AdminAuditTrailView()
                .environment(appState)
        case .securityPolicies:
            AdminSecurityPoliciesView()
        case .systemConfiguration:
            AdminSystemConfigurationView()
        case .notificationSettings:
            AdminNotificationSettingsView()
        case .helpDocumentation:
            AdminHelpDocumentationView()
        }
    }
}

private struct AdminSettingsScaffold<Content: View>: View {
    let title: String
    let icon: String
    let subtitle: String
    private let content: Content

    init(title: String, icon: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                    Text(title)
                        .font(AppTypography.heading2)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Text(subtitle)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.cardPadding)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusLarge)

                content
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdminSettingCard<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.overline)
                .tracking(2)
                .foregroundColor(AppColors.accent)
            content
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusLarge)
    }
}

private struct AdminProfileDetailsView: View {
    @Environment(AppState.self) private var appState
    @State private var phone = "+91 98765 43210"

    var body: some View {
        AdminSettingsScaffold(
            title: "Admin Profile",
            icon: "person.text.rectangle",
            subtitle: "Corporate administrator identity and contact information."
        ) {
            AdminSettingCard(title: "CONTACT") {
                settingsLine(label: "Name", value: appState.currentUserName)
                settingsLine(label: "Email", value: appState.currentUserEmail)
                settingsEditableField(label: "Phone", text: $phone)
            }

            AdminSettingCard(title: "ACCESS") {
                settingsLine(label: "Role", value: "Corporate Admin")
                settingsLine(label: "Store Scope", value: "All boutiques")
                settingsLine(label: "Status", value: "Active")
            }
        }
    }
}

private struct AdminCredentialSettingsView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showSavedBanner = false

    var body: some View {
        AdminSettingsScaffold(
            title: "Change Password",
            icon: "key.fill",
            subtitle: "Update corporate admin credentials with a stronger password."
        ) {
            AdminSettingCard(title: "PASSWORD") {
                SecureField("Current password", text: $currentPassword)
                    .textFieldStyle(.roundedBorder)
                SecureField("New password", text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                SecureField("Confirm password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                Button("Update Password") {
                    showSavedBanner = true
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                if showSavedBanner {
                    Text("Password change request captured for secure processing.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.success)
                }
            }
        }
    }
}

private struct AdminBiometricSettingsView: View {
    @State private var faceIDEnabled = true
    @State private var fallbackPasscodeEnabled = true

    var body: some View {
        AdminSettingsScaffold(
            title: "Biometric Login",
            icon: "faceid",
            subtitle: "Manage Face ID / Touch ID usage for the admin console."
        ) {
            AdminSettingCard(title: "AUTHENTICATION") {
                Toggle("Enable Face ID / Touch ID", isOn: $faceIDEnabled)
                Toggle("Allow passcode fallback", isOn: $fallbackPasscodeEnabled)
            }
        }
    }
}

private struct AdminRoleAccessView: View {
    @State private var adminFullAccess = true
    @State private var managerExportAccess = true
    @State private var salesSensitiveDataAccess = false

    var body: some View {
        AdminSettingsScaffold(
            title: "Role-Based Access Control",
            icon: "shield.checkered",
            subtitle: "Control which roles can view operational and customer-sensitive data."
        ) {
            AdminSettingCard(title: "PERMISSIONS") {
                Toggle("Corporate admin full analytics access", isOn: $adminFullAccess)
                Toggle("Managers can export store reports", isOn: $managerExportAccess)
                Toggle("Sales can view sensitive customer history", isOn: $salesSensitiveDataAccess)
            }
        }
    }
}

private struct AdminAccessLogsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        AdminSettingsScaffold(
            title: "Access Logs",
            icon: "clock.arrow.circlepath",
            subtitle: "Recent login and admin-console access history."
        ) {
            AdminSettingCard(title: "RECENT LOGINS") {
                settingsLine(label: "Today", value: "\(appState.currentUserEmail) signed in from iPhone")
                settingsLine(label: "Previous", value: "Admin session refreshed from corporate network")
                settingsLine(label: "Security", value: "No suspicious login activity detected")
            }
        }
    }
}



private struct AdminSecurityPoliciesView: View {
    @State private var requireMFA = true
    @State private var rotatePasswords = true
    @State private var restrictIdleSessions = true

    var body: some View {
        AdminSettingsScaffold(
            title: "Security Policies",
            icon: "lock.shield",
            subtitle: "Manage password, session, and authentication policies."
        ) {
            AdminSettingCard(title: "POLICIES") {
                Toggle("Require multi-factor authentication", isOn: $requireMFA)
                Toggle("Rotate passwords every 90 days", isOn: $rotatePasswords)
                Toggle("Auto-expire idle admin sessions", isOn: $restrictIdleSessions)
            }
        }
    }
}

private struct AdminSystemConfigurationView: View {
    @State private var liveSyncEnabled = true
    @State private var nightlyExports = true

    var body: some View {
        AdminSettingsScaffold(
            title: "System Configuration",
            icon: "gearshape.2",
            subtitle: "Operational controls for sync behavior and reporting preferences."
        ) {
            AdminSettingCard(title: "OPERATIONS") {
                Toggle("Enable live portal sync", isOn: $liveSyncEnabled)
                Toggle("Generate nightly executive exports", isOn: $nightlyExports)
            }
        }
    }
}

private struct AdminNotificationSettingsView: View {
    @State private var pushAlerts = true
    @State private var lowStockAlerts = true
    @State private var returnEscalations = true

    var body: some View {
        AdminSettingsScaffold(
            title: "Notification Settings",
            icon: "bell.badge",
            subtitle: "Control which alerts the corporate admin receives."
        ) {
            AdminSettingCard(title: "ALERTS") {
                Toggle("Push alerts for client portal activity", isOn: $pushAlerts)
                Toggle("Low-stock and fulfillment alerts", isOn: $lowStockAlerts)
                Toggle("Escalated return / exchange alerts", isOn: $returnEscalations)
            }
        }
    }
}

private struct AdminHelpDocumentationView: View {
    var body: some View {
        AdminSettingsScaffold(
            title: "Help & Documentation",
            icon: "questionmark.circle",
            subtitle: "Guides for monitoring portal activity, fulfillment, and reporting."
        ) {
            AdminSettingCard(title: "GUIDES") {
                Text("Use Customer Activity Monitor to review online orders, reservations, and returns. Export channel comparison reports to compare online / omnichannel performance against in-store sales.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
    }
}

private func settingsLine(label: String, value: String) -> some View {
    HStack {
        Text(label)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)
        Spacer()
        Text(value)
            .font(AppTypography.bodySmall)
            .foregroundColor(AppColors.textPrimaryDark)
            .multilineTextAlignment(.trailing)
    }
}

private func settingsEditableField(label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(label)
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondaryDark)
        TextField(label, text: text)
            .textFieldStyle(.roundedBorder)
    }
}

#Preview {
    NavigationStack {
        AdminProfileView()
            .environment(AppState())
    }
}
