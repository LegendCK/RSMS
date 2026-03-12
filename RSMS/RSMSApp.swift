//
//  RSMSApp.swift
//  RSMS
//
//  Created by admin56 on 12/03/26.
//

import SwiftUI
import SwiftData

@main
struct RSMSApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            User.self,
            Product.self,
            Category.self,
            Order.self,
            CartItem.self,
            ClientProfile.self,
            Appointment.self,
            AfterSalesTicket.self,
            Transfer.self,
            Event.self,
            AppNotification.self,
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
