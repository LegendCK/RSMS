//
//  CustomerEventDetailView.swift
//  RSMS
//
//  Premium event detail + RSVP view for invited clients.
//  Opened via the "event/{uuid}" deep link from NotificationCenterView.
//

import SwiftUI
import Supabase

struct CustomerEventDetailView: View {
    let eventId: UUID

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss)     private var dismiss

    @State private var event:       EventDTO?           = nil
    @State private var invitation:  EventInvitationDTO? = nil
    @State private var rsvpCounts:  RSVPCounts          = RSVPCounts()
    @State private var isLoading                        = true
    @State private var isSubmitting                     = false
    @State private var errorMessage: String?            = nil

    private var clientId: UUID? { appState.currentUserProfile?.id }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColors.accent)
                        Text("Loading event…")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                } else if let ev = event {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            headerCard(ev)
                            detailsCard(ev)
                            rsvpCard(ev)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 44, weight: .ultraLight))
                            .foregroundColor(AppColors.neutral500)
                        Text("Event Unavailable")
                            .font(AppTypography.heading3)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text("This event may have been cancelled or removed.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Your Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accent)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Header Card

    private func headerCard(_ ev: EventDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thin top accent bar
            Rectangle()
                .fill(AppColors.accent)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text(ev.eventType.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(AppColors.accent)
                    Spacer()
                    statusPill(ev.status)
                }

                Text(ev.eventName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.textPrimaryDark)
                    .fixedSize(horizontal: false, vertical: true)

                if let seg = ev.invitedSegment {
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.secondary)
                        Text("Exclusive to \(seg.uppercased()) members")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func statusPill(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case "Confirmed":   return ("Confirmed",   AppColors.success)
            case "In Progress": return ("Live Now",    AppColors.success)
            case "Cancelled":   return ("Cancelled",   AppColors.error)
            case "Completed":   return ("Past",        AppColors.neutral500)
            default:            return ("Planned",     AppColors.warning)
            }
        }()
        return Text(label.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Details Card

    private func detailsCard(_ ev: EventDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            Text("EVENT DETAILS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 12) {
                detailRow(icon: "calendar",
                          text: ev.scheduledDate.formatted(date: .long, time: .shortened))
                detailRow(icon: "clock",
                          text: "\(ev.durationMinutes) minutes")
                detailRow(icon: "person.2",
                          text: "Up to \(ev.capacity) guests")
                if !ev.relatedCategory.isEmpty {
                    detailRow(icon: "tag", text: ev.relatedCategory)
                }
            }

            if !ev.description.isEmpty {
                Divider()
                    .padding(.vertical, 14)
                Text(ev.description)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if rsvpCounts.total > 0 {
                Divider()
                    .padding(.vertical, 14)
                HStack(spacing: 0) {
                    rsvpStat(value: rsvpCounts.yes,     label: "Attending", color: AppColors.success)
                    rsvpStat(value: rsvpCounts.no,      label: "Declined",  color: AppColors.error)
                    rsvpStat(value: rsvpCounts.pending, label: "Pending",   color: AppColors.warning)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.accent)
                .frame(width: 20, alignment: .center)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimaryDark)
        }
    }

    private func rsvpStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(color)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - RSVP Card

    @ViewBuilder
    private func rsvpCard(_ ev: EventDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR RSVP")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(AppColors.accent)

            if let inv = invitation {
                switch inv.status {
                case "rsvp_yes": rsvpConfirmed(attending: true)
                case "rsvp_no":  rsvpConfirmed(attending: false)
                default:         rsvpPrompt(ev)
                }
            } else if ev.isActive {
                rsvpPrompt(ev)
            } else {
                Text("RSVP period has closed for this event.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func rsvpConfirmed(attending: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((attending ? AppColors.success : AppColors.neutral500).opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: attending ? "checkmark.seal.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(attending ? AppColors.success : AppColors.neutral500)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(attending ? "You're attending" : "You declined")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimaryDark)
                Text(attending
                    ? "We look forward to welcoming you."
                    : "Your response has been recorded.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
        }
    }

    private func rsvpPrompt(_ ev: EventDTO) -> some View {
        VStack(spacing: 14) {
            Text("Will you be joining us?")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.textPrimaryDark)
                .frame(maxWidth: .infinity, alignment: .center)

            if let msg = errorMessage {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.error)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                // Accept
                Button { Task { await submitRSVP(accepted: true) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("I'll Attend")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Decline
                Button { Task { await submitRSVP(accepted: false) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Decline")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(AppColors.textPrimaryDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.5 : 1)
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let events: [EventDTO] = try await SupabaseManager.shared.client
                .from("boutique_events")
                .select()
                .eq("id", value: eventId.uuidString.lowercased())
                .limit(1)
                .execute()
                .value
            event = events.first
            rsvpCounts = (try? await EventInvitationService.shared.fetchRSVPCounts(eventId: eventId)) ?? RSVPCounts()
            if let cId = clientId {
                invitation = try? await EventInvitationService.shared.fetchMyInvitation(eventId: eventId, clientId: cId)
            }
        } catch { /* leave event nil */ }
    }

    private func submitRSVP(accepted: Bool) async {
        guard let cId = clientId else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await EventInvitationService.shared.submitRSVP(eventId: eventId, clientId: cId, accepted: accepted)
            invitation = EventInvitationDTO(
                id:        invitation?.id ?? UUID(),
                eventId:   eventId,
                clientId:  cId,
                status:    accepted ? "rsvp_yes" : "rsvp_no",
                invitedAt: invitation?.invitedAt ?? Date(),
                rsvpAt:    Date()
            )
            rsvpCounts = (try? await EventInvitationService.shared.fetchRSVPCounts(eventId: eventId)) ?? rsvpCounts
        } catch {
            errorMessage = "Could not submit your RSVP. Please try again."
        }
    }
}
