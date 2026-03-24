//
//  EventInvitationService.swift
//  RSMS
//
//  Handles VIP event invitation dispatch:
//  — Filters eligible clients by segment + consent
//  — Batch-inserts event_invitations rows
//  — Batch-inserts notifications rows (one per client)
//  — Fetches invitations and RSVP counts for a manager
//

import Foundation
import Supabase

@MainActor
final class EventInvitationService {
    static let shared = EventInvitationService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Fetch Eligible Clients

    /// Fetches clients matching the given segment who have given GDPR + marketing consent.
    func fetchEligibleClients(segment: String) async throws -> [ClientDTO] {
        try await client
            .from("clients")
            .select()
            .eq("is_active",       value: true)
            .eq("segment",         value: segment)
            .eq("gdpr_consent",    value: true)
            .eq("marketing_opt_in", value: true)
            .order("last_name", ascending: true)
            .execute()
            .value
    }

    /// Total count in the segment (including non-consenting) for the exclusion banner.
    func fetchSegmentTotalCount(segment: String) async throws -> Int {
        struct CountRow: Decodable { let count: Int }
        let rows: [CountRow] = try await client
            .from("clients")
            .select("count", head: false)
            .eq("is_active", value: true)
            .eq("segment",   value: segment)
            .execute()
            .value
        return rows.first?.count ?? 0
    }

    // MARK: - Send Invitations

    /// Batch-inserts event_invitations + notifications for each eligible client.
    /// Returns the number of invitations sent.
    func sendInvitations(
        event:   EventDTO,
        clients: [ClientDTO],
        storeId: UUID
    ) async throws -> Int {
        guard !clients.isEmpty else { return 0 }

        // 1. Insert event_invitations (ON CONFLICT DO NOTHING via UNIQUE constraint)
        let invitations = clients.map { c in
            EventInvitationInsertDTO(
                eventId:  event.id,
                clientId: c.id,
                status:   "sent"
            )
        }
        try await client
            .from("event_invitations")
            .insert(invitations)
            .execute()

        // 2. Insert notifications (one per client)
        let dateStr = event.scheduledDate.formatted(date: .abbreviated, time: .shortened)
        let notifications = clients.map { c in
            NotificationInsertDTO(
                recipientClientId: c.id,
                storeId:           storeId,
                title:             "You're invited — \(event.eventName)",
                message:           "Join us for a \(event.eventType) on \(dateStr). Tap to RSVP.",
                category:          "Event",
                deepLink:          "event/\(event.id.uuidString.lowercased())"
            )
        }
        try await client
            .from("notifications")
            .insert(notifications)
            .execute()

        return clients.count
    }

    // MARK: - Fetch Invitations

    func fetchInvitations(eventId: UUID) async throws -> [EventInvitationDTO] {
        try await client
            .from("event_invitations")
            .select()
            .eq("event_id", value: eventId.uuidString.lowercased())
            .order("invited_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - RSVP Counts

    struct RPCCounts: Decodable {
        let rsvp_yes: Int
        let rsvp_no:  Int
        let pending:  Int
    }

    func fetchRSVPCounts(eventId: UUID) async throws -> RSVPCounts {
        let rows: [RPCCounts] = try await client
            .rpc("get_event_rsvp_counts", params: ["p_event_id": eventId.uuidString.lowercased()])
            .execute()
            .value
        guard let row = rows.first else { return RSVPCounts() }
        return RSVPCounts(yes: row.rsvp_yes, no: row.rsvp_no, pending: row.pending)
    }

    // MARK: - RSVP (Customer)

    func submitRSVP(eventId: UUID, clientId: UUID, accepted: Bool) async throws {
        let payload = RSVPUpdateDTO(
            status: accepted ? "rsvp_yes" : "rsvp_no",
            rsvpAt: Date()
        )
        try await client
            .from("event_invitations")
            .update(payload)
            .eq("event_id",  value: eventId.uuidString.lowercased())
            .eq("client_id", value: clientId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Fetch Client's Own Invitation

    func fetchMyInvitation(eventId: UUID, clientId: UUID) async throws -> EventInvitationDTO? {
        let rows: [EventInvitationDTO] = try await client
            .from("event_invitations")
            .select()
            .eq("event_id",  value: eventId.uuidString.lowercased())
            .eq("client_id", value: clientId.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
