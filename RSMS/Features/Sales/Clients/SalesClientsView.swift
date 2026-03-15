//
//  SalesClientsView.swift
//  infosys2
//
//  Sales Associate clienteling — manage client profiles, preferences, history.
//

import SwiftUI
import SwiftData

struct SalesClientsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSection = 0
    @State private var searchText = ""
    @State private var clients: [ClientDTO] = []
    @State private var isLoading = false
    @State private var showingCreateClient = false
    
    var filteredClients: [ClientDTO] {
        var list = clients
        if selectedSection == 2 {
            list = list.filter { ["gold", "vip", "ultra_vip"].contains($0.segment ?? "") }
        } else if selectedSection == 0 {
            let myId = appState.currentUserProfile?.id.uuidString ?? ""
            list = list.filter { $0.createdBy?.uuidString == myId }
        }
        
        if !searchText.isEmpty {
            let term = searchText.lowercased()
            list = list.filter {
                $0.fullName.lowercased().contains(term) ||
                $0.email.lowercased().contains(term) ||
                ($0.phone?.lowercased().contains(term) ?? false)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedSection) {
                        Text("My Clients").tag(0)
                        Text("All Clients").tag(1)
                        Text("VIP").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondaryDark)
                        TextField("Search clients...", text: $searchText)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await performSearch() }
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                Task { await loadClients() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.neutral500)
                            }
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusSmall)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.sm)

                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(AppColors.accent)
                        Spacer()
                    } else if filteredClients.isEmpty {
                        Spacer()
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "person.2.fill")
                                .font(AppTypography.emptyStateIcon)
                                .foregroundColor(AppColors.accent.opacity(0.5))
                            Text("No clients found")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondaryDark)
                            Button {
                                showingCreateClient = true
                            } label: {
                                Text("Create new client")
                                    .font(AppTypography.actionLink)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredClients) { client in
                                ZStack {
                                    NavigationLink(destination: ClientDetailView(client: client)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    
                                    clientRow(client)
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: AppSpacing.xs, leading: AppSpacing.screenHorizontal, bottom: AppSpacing.xs, trailing: AppSpacing.screenHorizontal))
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await loadClients()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CLIENTELING")
                        .font(AppTypography.overline)
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingCreateClient = true } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .navigationDestination(isPresented: $showingCreateClient) {
                CreateClientProfileView()
            }
            .task {
                await loadClients()
            }
            .onChange(of: selectedSection) { _, _ in
                // Local filter updates automatically, but we ensure list is loaded
                if clients.isEmpty && !isLoading {
                    Task { await loadClients() }
                }
            }
        }
    }
    
    @MainActor
    private func loadClients() async {
        isLoading = true
        defer { isLoading = false }
        do {
            clients = try await ClientService.shared.fetchAllClients()
        } catch {
            print("Error loading clients: \(error)")
        }
    }
    
    @MainActor
    private func performSearch() async {
        guard !searchText.isEmpty else {
            await loadClients()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            clients = try await ClientService.shared.searchClients(query: searchText)
        } catch {
            print("Error searching clients: \(error)")
        }
    }
    
    private func clientRow(_ client: ClientDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(AppColors.accent.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(client.initials)
                        .font(AppTypography.avatarSmall)
                        .foregroundColor(AppColors.accent)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                
                if let phone = client.phone, !phone.isEmpty {
                    Text(phone)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                } else {
                    Text(client.email)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
            
            Spacer()
            
            if let segment = client.segment, !segment.isEmpty {
                Text(segment.capitalized.replacingOccurrences(of: "_", with: " "))
                    .font(AppTypography.micro)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(segment == "vip" || segment == "ultra_vip" ? AppColors.accent : AppColors.neutral300)
                    .foregroundColor(segment == "vip" || segment == "ultra_vip" ? .white : AppColors.textPrimaryDark)
                    .cornerRadius(4)
            }
            
            Image(systemName: "chevron.right")
                .font(AppTypography.chevron)
                .foregroundColor(AppColors.neutral500)
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}
