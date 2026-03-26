//
//  PaymentRecordService.swift
//  RSMS
//
//  Records completed payments to the Supabase `payments` table.
//  Used after a successful Stripe payment to persist the record.
//

import Foundation
import Supabase

@MainActor
final class PaymentRecordService {
    static let shared = PaymentRecordService()
    private let client = SupabaseManager.shared.client

    private init() {}

    /// Insert a payment record into Supabase `payments` table.
    func recordPayment(
        orderId: UUID,
        method: String,
        amount: Double,
        currency: String = "INR",
        status: String = "completed",
        paymentReference: String? = nil,
        stripePaymentIntentId: String? = nil,
        processedBy: UUID? = nil
    ) async throws {
        let payload = PaymentRecordInsertPayload(
            orderId: orderId,
            method: method,
            amount: amount,
            currency: currency,
            status: status,
            paymentReference: paymentReference,
            stripePaymentIntentId: stripePaymentIntentId,
            processedBy: processedBy
        )

        var customHeaders = ["apikey": SupabaseConfig.anonKey]
        if let session = try? await client.auth.session {
            customHeaders["Authorization"] = "Bearer \(session.accessToken)"
        }

        // Use the admin/service-key insert via edge function or direct table insert.
        // Since the create-order edge function already handles payment inserts for POS,
        // for Stripe payments we insert directly (RLS should allow authenticated inserts).
        try await client
            .from("payments")
            .insert(payload)
            .execute()

        print("[PaymentRecordService] ✅ Payment recorded for order \(orderId) — method: \(method)")
    }
}

// MARK: - Insert Payload (includes stripe_payment_intent_id)

private struct PaymentRecordInsertPayload: Encodable {
    let orderId: UUID
    let method: String
    let amount: Double
    let currency: String
    let status: String
    let paymentReference: String?
    let stripePaymentIntentId: String?
    let processedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case orderId              = "order_id"
        case method, amount, currency, status
        case paymentReference     = "payment_reference"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case processedBy          = "processed_by"
    }
}
