//
//  BOPISOrderSeedData.swift
//  RSMS
//
//  Realistic luxury-retail dummy orders used when Supabase returns no BOPIS /
//  ship-from-store rows (e.g. a fresh dev environment or demo mode).
//  All order numbers, clients, and products follow the Maison Luxe brand voice.
//

import Foundation

enum BOPISOrderSeedData {

    // MARK: - Public Entry Point

    /// Returns a rich set of dummy orders spread across various SLA states.
    /// Deadlines are computed relative to `Date()` so SLA colours stay realistic
    /// every time the app is launched during development.
    static func generate() -> [BOPISOrder] {
        let now = Date()

        let raw: [(
            number: String,
            channel: BOPISChannel,
            status: String,
            client: String,
            total: Double,
            currency: String,
            placedAgo: TimeInterval      // seconds in the past
        )] = [
            // ── OVERDUE (breached SLA) ─────────────────────────────────────
            (
                "ML-2026-B0041",
                .bopis,
                "ready_for_pickup",
                "princess.al-rashid@example.com",
                18_500,
                "INR",
                6 * 3600          // placed 6h ago → 4h SLA breached by 2h
            ),
            (
                "ML-2026-S0019",
                .shipFromStore,
                "processing",
                "james.worthington@maison.com",
                42_750,
                "INR",
                26 * 3600         // placed 26h ago → 24h SLA breached by 2h
            ),
            (
                "ML-2026-B0038",
                .bopis,
                "confirmed",
                "eleanor.voss@example.com",
                9_200,
                "INR",
                5.5 * 3600        // placed 5.5h ago → 4h SLA breached by 1.5h
            ),

            // ── AT RISK (< 1 h remaining) ──────────────────────────────────
            (
                "ML-2026-B0042",
                .bopis,
                "confirmed",
                "priya.kapoor@maison.com",
                6_400,
                "INR",
                3.2 * 3600        // placed 3.2h ago → 48 min left on 4h SLA
            ),
            (
                "ML-2026-S0021",
                .shipFromStore,
                "processing",
                "liu.wei@example.com",
                31_000,
                "INR",
                23.3 * 3600       // placed 23.3h ago → 42 min left on 24h SLA
            ),

            // ── ON TIME — BOPIS ────────────────────────────────────────────
            (
                "ML-2026-B0043",
                .bopis,
                "confirmed",
                "sofia.andersson@example.com",
                12_800,
                "INR",
                1 * 3600          // placed 1h ago → 3h left
            ),
            (
                "ML-2026-B0044",
                .bopis,
                "ready_for_pickup",
                "david.park@maison.com",
                7_650,
                "INR",
                0.5 * 3600        // placed 30 min ago → 3.5h left
            ),
            (
                "ML-2026-B0045",
                .bopis,
                "confirmed",
                "amara.osei@example.com",
                22_400,
                "INR",
                2 * 3600          // placed 2h ago → 2h left
            ),

            // ── ON TIME — SHIP FROM STORE ──────────────────────────────────
            (
                "ML-2026-S0022",
                .shipFromStore,
                "processing",
                "nikolai.volkov@example.com",
                58_000,
                "INR",
                4 * 3600          // placed 4h ago → 20h left
            ),
            (
                "ML-2026-S0023",
                .shipFromStore,
                "confirmed",
                "isabella.morano@maison.com",
                14_200,
                "INR",
                8 * 3600          // placed 8h ago → 16h left
            ),
            (
                "ML-2026-S0024",
                .shipFromStore,
                "processing",
                "rajan.mehta@example.com",
                9_850,
                "INR",
                12 * 3600         // placed 12h ago → 12h left
            ),
            (
                "ML-2026-S0025",
                .shipFromStore,
                "confirmed",
                "celine.dubois@example.com",
                27_300,
                "INR",
                2 * 3600          // placed 2h ago → 22h left
            ),
        ]

        return raw.map { r in
            let placedAt  = now - r.placedAgo
            let deadline  = placedAt + r.channel.slaHours * 3600
            return BOPISOrder(
                id:             UUID(),
                orderNumber:    r.number,
                clientId:       nil,
                channel:        r.channel,
                status:         r.status,
                clientEmail:    r.client,
                grandTotal:     r.total,
                currency:       r.currency,
                placedAt:       placedAt,
                pickupDeadline: deadline
            )
        }
    }
}
