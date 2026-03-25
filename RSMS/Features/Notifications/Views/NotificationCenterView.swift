//
//  NotificationCenterView.swift
//  RSMS
//
//  Customer-facing notification centre — shows all in-app notifications
//  fetched from Supabase, grouped by Today / Earlier.
//  Opened via the bell icon in HomeView.
//

import SwiftUI
import SwiftData

struct NotificationCenterView: View {
    @Environment(AppState.self)    private var appState
    @Environment(\.modelContext)   private var modelContext
    @Environment(\.dismiss)        private var dismiss

    @State private var notifications: [NotificationDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedDeepLink: String? = nil
    @State private var showEventDetail  = false
    @State private var selectedEventId: UUID? = nil

    private var clientId: UUID? { appState.currentUserProfile?.id }

    private var todayItems: [NotificationDTO] {
        notifications.filter { Calendar.current.isDateInToday($0.createdAt) }
    }
    private var earlierItems: [NotificationDTO] {
        notifications.filter { !Calendar.current.isDateInToday($0.createdAt) }
    }
    private var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading && notifications.isEmpty {
                    ProgressView("Loading…")
                        .tint(AppColors.accent)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if unreadCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark all read") {
                            Task { await markAllRead() }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accent)
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showEventDetail) {
                if let eventId = selectedEventId {
                    CustomerEventDetailView(eventId: eventId)
                }
            }
        }
    }

    // MARK: - List

    private var notificationList: some View {
        List {
            if !todayItems.isEmpty {
                Section("Today") {
                    ForEach(todayItems) { item in
                        notificationRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if !item.isRead {
                                    Button {
                                        Task { await markRead(item) }
                                    } label: {
                                        Label("Read", systemImage: "checkmark")
                                    }
                                    .tint(AppColors.accent)
                                }
                            }
                    }
                }
            }
            if !earlierItems.isEmpty {
                Section("Earlier") {
                    ForEach(earlierItems) { item in
                        notificationRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if !item.isRead {
                                    Button {
                                        Task { await markRead(item) }
                                    } label: {
                                        Label("Read", systemImage: "checkmark")
                                    }
                                    .tint(AppColors.accent)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Row

    private func notificationRow(_ item: NotificationDTO) -> some View {
        Button {
            handleTap(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(iconColor(item.notificationCategory).opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName(item.notificationCategory))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor(item.notificationCategory))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.title)
                            .font(.system(size: 14, weight: item.isRead ? .regular : .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(relativeTime(item.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Text(item.message)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Unread dot
                if !item.isRead {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(AppColors.neutral500)
            Text("No notifications yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            Text("Event invitations and order updates will appear here.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Actions

    private func load() async {
        guard let clientId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let dtos = try await NotificationService.shared.fetchNotifications(clientId: clientId)
            notifications = dtos
            NotificationService.shared.syncToLocal(
                dtos: dtos,
                clientEmail: appState.currentUserEmail,
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markRead(_ item: NotificationDTO) async {
        guard !item.isRead else { return }
        try? await NotificationService.shared.markAsRead(notificationId: item.id)
        if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
            let updated = NotificationDTO(
                id: item.id, recipientClientId: item.recipientClientId,
                storeId: item.storeId, title: item.title, message: item.message,
                category: item.category, isRead: true,
                deepLink: item.deepLink, createdAt: item.createdAt
            )
            notifications[idx] = updated
        }
    }

    private func markAllRead() async {
        guard let clientId else { return }
        try? await NotificationService.shared.markAllAsRead(clientId: clientId)
        notifications = notifications.map { item in
            NotificationDTO(
                id: item.id, recipientClientId: item.recipientClientId,
                storeId: item.storeId, title: item.title, message: item.message,
                category: item.category, isRead: true,
                deepLink: item.deepLink, createdAt: item.createdAt
            )
        }
    }

    private func handleTap(_ item: NotificationDTO) {
        Task { await markRead(item) }
        // Route deep link
        if item.deepLink.hasPrefix("event/"),
           let uuidStr = item.deepLink.components(separatedBy: "/").last,
           let eventId = UUID(uuidString: uuidStr) {
            selectedEventId = eventId
            showEventDetail = true
        }
    }

    // MARK: - Helpers

    private func iconName(_ cat: NotificationCategory) -> String {
        switch cat {
        case .event:       return "star.fill"
        case .order:       return "bag.fill"
        case .appointment: return "calendar"
        case .afterSales:  return "wrench.fill"
        case .inventory:   return "shippingbox.fill"
        case .promotion:   return "tag.fill"
        case .system:      return "bell.fill"
        }
    }

    private func iconColor(_ cat: NotificationCategory) -> Color {
        switch cat {
        case .event:       return AppColors.secondary
        case .order:       return AppColors.accent
        case .appointment: return AppColors.info
        case .afterSales:  return AppColors.warning
        case .inventory:   return AppColors.success
        case .promotion:   return Color.purple
        case .system:      return AppColors.neutral500
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60    { return "Just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}
