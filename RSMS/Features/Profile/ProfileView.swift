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
                                .foregroundColor(AppColors.textPrimaryDark)
                            if appState.isGuest {
                                Text("Browsing as guest")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(AppColors.textSecondaryDark)
                            } else {
                                Text(appState.currentUserEmail)
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            Text(appState.isGuest ? "GUEST" : appState.currentUserRole.rawValue.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(appState.isGuest ? AppColors.textSecondaryDark : AppColors.accent)
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
                    NavigationLink(destination: NotificationCenterView(showsCloseButton: false)) {
                        Label("Notifications", systemImage: "bell")
                    }
                    NavigationLink(destination: ProfileInfoView(
                        title: "Privacy & Security",
                        message: "Manage your privacy preferences, account protection, and secure account behavior."
                    )) {
                        Label("Privacy & Security", systemImage: "lock.shield")
                    }
                }

                // Support
                Section("Support") {
                    NavigationLink(destination: HelpSupportView()) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
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
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) { appState.logout() }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .fullScreenCover(isPresented: $showSignIn) {
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

private struct ProfileInfoView: View {
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

// MARK: - Help & Support

private struct HelpSupportView: View {
    var body: some View {
        List {
            // Contact section
            Section("Contact Us") {
                HStack(spacing: 14) {
                    Image(systemName: "envelope")
                        .foregroundColor(AppColors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email Support")
                            .font(.system(size: 15, weight: .medium))
                        Text("support@maisonluxe.me")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 14) {
                    Image(systemName: "phone")
                        .foregroundColor(AppColors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Client Concierge")
                            .font(.system(size: 15, weight: .medium))
                        Text("+91 98765 43210")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 14) {
                    Image(systemName: "clock")
                        .foregroundColor(AppColors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Support Hours")
                            .font(.system(size: 15, weight: .medium))
                        Text("Mon – Sat, 10:00 AM – 7:00 PM IST")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Orders & Returns
            Section("Orders & Returns") {
                faqRow(
                    question: "How do I track my order?",
                    answer: "Go to Profile → My Orders to view real-time status updates for all your orders."
                )
                faqRow(
                    question: "What is your return policy?",
                    answer: "Items in original condition may be returned within 14 days of delivery. Visit any Maison Luxe boutique or raise a Service Ticket in the app."
                )
                faqRow(
                    question: "Can I exchange a product?",
                    answer: "Yes. Raise an exchange request under Profile → My Exchange Requests and a concierge will assist you."
                )
                faqRow(
                    question: "How long does delivery take?",
                    answer: "Standard delivery takes 3–5 business days. Express delivery (1–2 days) is available at checkout for select pin codes."
                )
            }

            // Appointments & Reservations
            Section("Boutique & Reservations") {
                faqRow(
                    question: "How do I book an in-store appointment?",
                    answer: "Use Profile → Book an Appointment or the shortcut on your home dashboard to schedule a private viewing."
                )
                faqRow(
                    question: "Can I reserve a product before buying?",
                    answer: "Yes. Open any product detail page and tap 'Reserve In Boutique' to hold it for up to 48 hours at your nearest location."
                )
                faqRow(
                    question: "What are boutique hours?",
                    answer: "Most Maison Luxe boutiques are open Monday to Saturday, 10:00 AM – 8:00 PM. Hours may vary by location."
                )
            }

            // Account
            Section("Account & Security") {
                faqRow(
                    question: "How do I update my personal details?",
                    answer: "Go to Profile → Edit Profile to update your name, email, phone, and address."
                )
                faqRow(
                    question: "How do I reset my password?",
                    answer: "On the login screen, tap 'Forgot Password'. A reset link will be sent to your registered email address."
                )
                faqRow(
                    question: "Is my payment information secure?",
                    answer: "All payment data is encrypted and processed through PCI-DSS certified gateways. Maison Luxe does not store card numbers on its servers."
                )
            }

            // Footer
            Section {
                Text("For urgent assistance, email support@maisonluxe.me and a client advisor will respond within 2 business hours.")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("HELP & SUPPORT")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    private func faqRow(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            Text(answer)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
