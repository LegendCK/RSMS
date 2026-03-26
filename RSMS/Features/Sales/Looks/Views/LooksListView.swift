//
//  LooksListView.swift
//  RSMS
//

import SwiftUI
import SwiftData

struct LooksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query(sort: \Look.createdAt, order: .reverse) private var allLooks: [Look]
    @Query private var products: [Product] // Need products to compute totals
    
    @State private var showCreateLook = false
    @State private var filter: LookFilter = .all
    
    enum LookFilter {
        case all, myLooks
    }
    
    var filteredLooks: [Look] {
        let currentId = appState.currentUserProfile?.id ?? UUID()
        switch filter {
        case .all:
            return allLooks.filter { $0.isShared || $0.creatorId == currentId }
        case .myLooks:
            return allLooks.filter { $0.creatorId == currentId }
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Filter", selection: $filter) {
                    Text("All Looks").tag(LookFilter.all)
                    Text("My Looks").tag(LookFilter.myLooks)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if filteredLooks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(filteredLooks) { look in
                                NavigationLink {
                                    LookDetailView(look: look)
                                } label: {
                                    LookCard(
                                        look: look,
                                        itemCount: look.productIds.count,
                                        totalPrice: formatPrice(for: look.productIds)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Curated Looks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateLook = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showCreateLook) {
            NavigationStack {
                CreateLookView()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hanger")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundColor(.secondary)
            
            Text("No looks discovered")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Be the first to curate a Look and inspire your team.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showCreateLook = true
            } label: {
                Text("Create New Look")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private func formatPrice(for productIds: [UUID]) -> String {
        let matched = products.filter { productIds.contains($0.id) }
        let total = matched.reduce(0) { $0 + $1.price }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: NSNumber(value: total)) ?? "INR \(total)"
    }
}
