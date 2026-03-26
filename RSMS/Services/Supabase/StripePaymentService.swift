//
//  StripePaymentService.swift
//  RSMS
//
//  Handles Stripe payment flow through Supabase Edge Function.
//  Card details are sent only to the edge function, which creates + confirms
//  the PaymentIntent using the Stripe secret key.
//

import Foundation
import Supabase

// MARK: - Payment Result

enum StripePaymentResult {
    case success(paymentIntentId: String)
    case cancelled
    case failed(Error)
}

enum StripePaymentError: LocalizedError {
    case missingClientSecret
    case confirmationFailed(String)
    case invalidCardDetails
    case edgeFunctionError(String)

    var errorDescription: String? {
        switch self {
        case .missingClientSecret:
            return "Could not create payment session."
        case .confirmationFailed(let m):
            return "Payment failed: \(m)"
        case .invalidCardDetails:
            return "Please enter valid card details."
        case .edgeFunctionError(let m):
            return "Payment service error: \(m)"
        }
    }
}

// MARK: - Card Details

struct StripeCardDetails: Encodable {
    let number: String        // e.g. "4242424242424242"
    let expMonth: Int         // 1–12
    let expYear: Int          // 4-digit, e.g. 2029
    let cvc: String           // 3 or 4 digits

    var isValid: Bool {
        let cleanNumber = number.replacingOccurrences(of: " ", with: "")
        return cleanNumber.count >= 13
            && cleanNumber.count <= 19
            && expMonth >= 1
            && expMonth <= 12
            && expYear >= Calendar.current.component(.year, from: Date())
            && cvc.count >= 3
            && cvc.count <= 4
    }
}

// MARK: - Service

@MainActor
final class StripePaymentService {
    static let shared = StripePaymentService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Public API

    /// Full payment flow through edge function.
    /// `amountInPaise` is the amount in the smallest currency unit (₹100 = 10000 paise).
    func processPayment(
        amountInPaise: Int,
        currency: String = "inr",
        orderId: UUID? = nil,
        card: StripeCardDetails
    ) async -> StripePaymentResult {

        print("[StripePaymentService] 🔵 processPayment called — amount: \(amountInPaise), currency: \(currency)")
        print("[StripePaymentService] Card valid: \(card.isValid), number length: \(card.number.replacingOccurrences(of: " ", with: "").count), expMonth: \(card.expMonth), expYear: \(card.expYear), cvc length: \(card.cvc.count)")

        guard card.isValid else {
            print("[StripePaymentService] ❌ Card validation FAILED — returning invalidCardDetails")
            return .failed(StripePaymentError.invalidCardDetails)
        }

        let intentResult = await createAndConfirmPaymentIntent(
            amount: amountInPaise,
            currency: currency,
            orderId: orderId,
            card: card
        )

        switch intentResult {
        case .failure(let error):
            return .failed(error)
        case .success(let info):
            switch info.status {
            case "succeeded":
                return .success(paymentIntentId: info.paymentIntentId)
            case "requires_action", "requires_source_action":
                return .failed(StripePaymentError.confirmationFailed(
                    "This card requires additional authentication (3D Secure). Use a card that does not require redirect authentication in this flow, or switch to Stripe PaymentSheet."
                ))
            default:
                return .failed(StripePaymentError.confirmationFailed("Payment status: \(info.status)"))
            }
        }
    }

    // MARK: - Edge Function Call

    private struct PaymentIntentResponse: Decodable {
        let clientSecret: String?
        let paymentIntentId: String?
        let status: String?
        let error: String?
    }

    private struct PaymentIntentInfo {
        let clientSecret: String
        let paymentIntentId: String
        let status: String
    }

    private struct EdgePayload: Encodable {
        let amount: Int
        let currency: String
        let orderId: String?
        let description: String?
        let card: StripeCardDetails
    }

    private let primaryEdgeFunctionName = "rapid-endpoint"

    private func createAndConfirmPaymentIntent(
        amount: Int,
        currency: String,
        orderId: UUID?,
        card: StripeCardDetails
    ) async -> Result<PaymentIntentInfo, Error> {
        let payload = EdgePayload(
            amount: amount,
            currency: currency,
            orderId: orderId?.uuidString.lowercased(),
            description: orderId.map { "RSMS Order \($0.uuidString.prefix(8))" },
            card: StripeCardDetails(
                number: card.number.replacingOccurrences(of: " ", with: ""),
                expMonth: card.expMonth,
                expYear: card.expYear,
                cvc: card.cvc
            )
        )

        do {
            let hasSession = (try? await client.auth.session) != nil
            print("[StripePaymentService] Auth session available: \(hasSession)")
            print("[StripePaymentService] 🔵 Invoking edge function '\(primaryEdgeFunctionName)'...")

            let response: PaymentIntentResponse = try await client.functions.invoke(
                primaryEdgeFunctionName,
                options: FunctionInvokeOptions(body: payload)
            )

            print("[StripePaymentService] Edge function response — paymentIntentId: \(response.paymentIntentId ?? "nil"), status: \(response.status ?? "nil"), error: \(response.error ?? "nil")")

            if let error = response.error {
                return .failure(StripePaymentError.edgeFunctionError(error))
            }

            guard let paymentIntentId = response.paymentIntentId,
                  let status = response.status else {
                return .failure(StripePaymentError.missingClientSecret)
            }

            return .success(PaymentIntentInfo(
                clientSecret: response.clientSecret ?? "",
                paymentIntentId: paymentIntentId,
                status: status
            ))
        } catch {
            print("[StripePaymentService] ❌ Edge function THREW: \(error)")
            return .failure(StripePaymentError.edgeFunctionError(parseEdgeInvokeError(error)))
        }
    }

    private func parseEdgeInvokeError(_ error: Error) -> String {
        let description = String(describing: error)

        // Supabase swift often embeds HTTP code and response bytes in the error string.
        if description.contains("httpError(code:") {
            return description
        }
        return error.localizedDescription
    }
}
