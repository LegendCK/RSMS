//
//  RSMSApp.swift
//  RSMS
//
//  Created by user@78 on 12/03/26.
//

import SwiftUI
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even if app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct RSMSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            User.self,
            Product.self,
            Category.self,
            Order.self,
            CartItem.self,
            SavedAddress.self,
            SavedPaymentCard.self,
            ClientProfile.self,
            Appointment.self,
            AfterSalesTicket.self,
            Transfer.self,
            Event.self,
            AppNotification.self,
            InventoryByLocation.self,
            InventoryDiscrepancy.self,
            StoreLocation.self,
            StaffShift.self,
            ReservationItem.self,
            PricingPolicySettings.self,
            IndianTaxRule.self,
            RegionalPriceRule.self,
            PromotionRule.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If the existing store is incompatible (schema changed), delete and recreate
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            // Also remove journal/wal files
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onAppear {
                    seedDataIfNeeded()
                    // Close any sessions that were left ACTIVE from a previous crash
                    Task { await ScanManager.shared.cleanUpStaleSessions() }
                    // Pre-fetch tax rates from Supabase so carts use live rates
                    Task { await TaxService.shared.fetchRates() }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedDataIfNeeded() {
        let context = sharedModelContainer.mainContext
        SeedData.seedIfNeeded(modelContext: context)
    }
}
