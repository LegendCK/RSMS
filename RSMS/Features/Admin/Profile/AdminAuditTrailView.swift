//
//  AdminAuditTrailView.swift
//  RSMS
//
//  Corporate Admin view to monitor the read-only `admin_audit_logs` table.
//

import SwiftUI
import SwiftData
import Supabase

struct AdminAuditTrailView: View {
    @Environment(AppState.self) private var appState
    @Query private var allUsers: [User]
    @State private var logs: [AdminAuditLogDTO] = []
    @State private var usersDict: [UUID: User] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if isLoading && logs.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppColors.accent)
            } else if let error = errorMessage {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(AppTypography.emptyStateIcon)
                        .foregroundColor(AppColors.error)
                    Text("Error loading logs")
                        .font(AppTypography.heading2)
                    Text(error)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { await fetchLogs() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                }
            } else if logs.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(AppTypography.emptyStateIcon)
                        .foregroundColor(AppColors.accent.opacity(0.5))
                    Text("No Audit Logs Found")
                        .font(AppTypography.heading2)
                    Text("Admin activity will be immutably recorded here.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    ForEach(logs) { log in
                        auditRow(for: log)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: AppSpacing.xs, leading: AppSpacing.screenHorizontal, bottom: AppSpacing.xs, trailing: AppSpacing.screenHorizontal))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await fetchLogs()
                }
            }
        }
        .navigationTitle("Audit Trail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchLogs()
        }
    }

    private func auditRow(for log: AdminAuditLogDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.action)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    
                    if let user = usersDict[log.adminId] {
                        Text("\(user.name) (\(user.role.rawValue))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.accent)
                    } else {
                        Text(log.adminId.uuidString)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.accent)
                    }
                }
                Spacer()
                Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.micro)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            if let details = log.details, !details.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(details.keys.sorted()), id: \.self) { key in
                        if let value = details[key] {
                            Text("\(key): \(value)")
                                .font(AppTypography.micro)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(AppColors.neutral300, lineWidth: 1)
        )
    }

    @MainActor
    private func fetchLogs() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        self.usersDict = Dictionary(uniqueKeysWithValues: allUsers.map { ($0.id, $0) })

        do {
            self.logs = try await AdminAuditService.shared.fetchLogs()
        } catch {
            self.errorMessage = error.localizedDescription
            print("[AdminAuditTrailView] Error fetching logs: \(error)")
        }
    }
}
