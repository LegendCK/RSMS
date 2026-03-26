//
//  ContentView.swift
//  RSMS - Retail Store Management System
//
//  Created by user@78 on 10/03/26.
//
//  Purpose: Main content view for item management with SwiftData integration
//  Features: List, add, delete, and navigate items with proper animation
//

import SwiftUI
import SwiftData

/// ContentView - Primary navigation and item management interface
/// Displays a list of items with add/delete capabilities and detailed navigation
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            itemListView
        } detail: {
            detailView
        }
    }

    // MARK: - Subviews
    
    /// Main list view displaying all items
    private var itemListView: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    itemDetailView(for: item)
                } label: {
                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                }
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem {
                Button(action: addItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Items")
    }
    
    /// Detail view for selected item
    private var detailView: some View {
        Text("Select an item")
            .foregroundStyle(.secondary)
    }
    
    /// Item detail view with timestamp
    private func itemDetailView(for item: Item) -> some View {
        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
            .navigationTitle("Item Details")
    }

    // MARK: - Actions
    
    /// Add a new item to the model context
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    /// Delete items at specified offsets
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
