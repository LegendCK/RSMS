//
//  LooksListView.swift
//  RSMS
//

import SwiftUI
import SwiftData

struct LooksListView: View {
    @Environment(AppState.self) private var appState
    @Query private var products: [Product] // Need products to compute totals

    @State private var looks: [SalesLookDTO] = []
    @State private var showCreateLook = false
    @State private var filter: LookFilter = .all
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum LookFilter {
        case all, myLooks
    }

    var filteredLooks: [SalesLookDTO] {
        let currentId = appState.currentUserProfile?.id ?? UUID()
        switch filter {
        case .all:
            return looks.filter { $0.isShared || $0.creatorId == currentId }
        case .myLooks:
            return looks.filter { $0.creatorId == currentId }
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

                if isLoading {
                    ProgressView("Loading looks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if filteredLooks.isEmpty {
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
        .task { await loadLooks() }
        .refreshable { await loadLooks() }
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
                CreateLookView {
                    Task { await loadLooks() }
                }
            }
        }
        .alert("Could Not Load Looks", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
            Button("Retry") { Task { await loadLooks() } }
        } message: {
            Text(errorMessage ?? "Unknown error")
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

    @MainActor
    private func loadLooks() async {
        guard let storeId = appState.currentStoreId else {
            looks = []
            errorMessage = "No store is linked to this account."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            looks = try await SalesLooksService.shared.fetchLooks(storeId: storeId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
