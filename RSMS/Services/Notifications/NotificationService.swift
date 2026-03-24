//
//  NotificationService.swift
//  RSMS
//
//  Manages in-app notifications stored in Supabase.
//  Handles fetch, mark-as-read, Supabase Realtime subscription,
//  and firing local UNUserNotificationCenter banners on new arrivals.
//

import Foundation
import Supabase
import UserNotifications
import SwiftData

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let client  = SupabaseManager.shared.client
    private let center  = UNUserNotificationCenter.current()
    private var channel: RealtimeChannelV2?

    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Fetch

    func fetchNotifications(clientId: UUID) async throws -> [NotificationDTO] {
        try await client
            .from("notifications")
            .select()
            .eq("recipient_client_id", value: clientId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    // MARK: - Mark as Read

    func markAsRead(notificationId: UUID) async throws {
        struct Patch: Codable { let is_read: Bool }
        try await client
            .from("notifications")
            .update(Patch(is_read: true))
            .eq("id", value: notificationId.uuidString.lowercased())
            .execute()
    }

    func markAllAsRead(clientId: UUID) async throws {
        struct Patch: Codable { let is_read: Bool }
        try await client
            .from("notifications")
            .update(Patch(is_read: true))
            .eq("recipient_client_id", value: clientId.uuidString.lowercased())
            .eq("is_read", value: false)
            .execute()
    }

    // MARK: - Realtime Subscription

    /// Subscribe to new notification rows for this client.
    /// - onNew: called on main actor with each arriving NotificationDTO.
    func subscribeToRealtime(clientId: UUID, onNew: @escaping @MainActor (NotificationDTO) -> Void) {
        Task {
            await unsubscribe()
            let ch = client.realtimeV2.channel("notifications:\(clientId.uuidString.lowercased())")
            let insertions = ch.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications",
                filter: "recipient_client_id=eq.\(clientId.uuidString.lowercased())"
            )
            do {
                try await ch.subscribeWithError()
            } catch {
                print("[NotificationService] Realtime subscribe failed: \(error)")
                return
            }
            channel = ch

            for await action in insertions {
                guard let dto = decodeInsertPayload(action.record) else { continue }
                await MainActor.run { onNew(dto) }
                await fireLocalBanner(dto)
            }
        }
    }

    func unsubscribe() async {
        if let ch = channel {
            await ch.unsubscribe()
            channel = nil
        }
    }

    // MARK: - Local UNUserNotificationCenter banner

    private func fireLocalBanner(_ dto: NotificationDTO) async {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = dto.title
        content.body  = dto.message
        content.sound = .default
        content.userInfo = ["deep_link": dto.deepLink, "notification_id": dto.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "rsms-notif-\(dto.id.uuidString)",
            content: content,
            trigger: nil   // deliver immediately
        )
        try? await center.add(request)
    }

    // MARK: - Helpers

    private func decodeInsertPayload(_ record: [String: AnyJSON]) -> NotificationDTO? {
        guard
            let idStr    = record["id"]?.stringValue.flatMap({ UUID(uuidString: $0) }),
            let rcpStr   = record["recipient_client_id"]?.stringValue.flatMap({ UUID(uuidString: $0) }),
            let title    = record["title"]?.stringValue,
            let message  = record["message"]?.stringValue,
            let category = record["category"]?.stringValue,
            let isRead   = record["is_read"]?.boolValue,
            let deepLink = record["deep_link"]?.stringValue,
            let createdStr = record["created_at"]?.stringValue
        else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAt = formatter.date(from: createdStr) ?? Date()

        let storeId = record["store_id"]?.stringValue.flatMap { UUID(uuidString: $0) }

        return NotificationDTO(
            id: idStr,
            recipientClientId: rcpStr,
            storeId: storeId,
            title: title,
            message: message,
            category: category,
            isRead: isRead,
            deepLink: deepLink,
            createdAt: createdAt
        )
    }

    // MARK: - Sync to SwiftData cache

    /// Upserts fetched DTOs into the local AppNotification SwiftData store.
    func syncToLocal(dtos: [NotificationDTO], clientEmail: String, modelContext: ModelContext) {
        for dto in dtos {
            let id = dto.id
            let predicate = #Predicate<AppNotification> { $0.id == id }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.isRead = dto.isRead
            } else {
                let local = AppNotification(
                    recipientEmail: clientEmail,
                    title:          dto.title,
                    message:        dto.message,
                    category:       dto.notificationCategory,
                    isRead:         dto.isRead,
                    deepLink:       dto.deepLink
                )
                local.id = dto.id
                modelContext.insert(local)
            }
        }
        try? modelContext.save()
    }
}

// MARK: - AnyJSON helpers

private extension AnyJSON {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
