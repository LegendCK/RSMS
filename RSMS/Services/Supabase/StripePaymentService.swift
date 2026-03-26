//
//  StripePaymentService.swift
//  RSMS
//
//  Production-safe Stripe flow:
//    1. Create PaymentIntent on Supabase edge function (server secret key)
//    2. Present Stripe PaymentSheet on iOS (SDK-hosted card entry + auth)
//

import Foundation
import Supabase
import StripePaymentSheet

// MARK: - Payment Result

enum StripePaymentResult {
    case success(paymentIntentId: String)
    case cancelled
    case failed(Error)
}

enum StripePaymentError: LocalizedError {
    case missingClientSecret
    case edgeFunctionError(String)

    var errorDescription: String? {
        switch self {
        case .missingClientSecret:
            return "Could not create payment session."
        case .edgeFunctionError(let m):
            return "Payment service error: \(m)"
        }
    }
}

struct StripePaymentSheetSession {
    let paymentIntentId: String
    let paymentSheet: PaymentSheet
}

@MainActor
final class StripePaymentService {
    static let shared = StripePaymentService()
    private let client = SupabaseManager.shared.client
    private let edgeFunctionName = "rapid-endpoint"

    private init() {}

    // MARK: - Public API

    func preparePaymentSheet(
        amountInPaise: Int,
        currency: String = "inr",
        orderId: UUID? = nil
    ) async -> Result<StripePaymentSheetSession, Error> {
        let intentResult = await createPaymentIntent(
            amount: amountInPaise,
            currency: currency,
            orderId: orderId
        )

        switch intentResult {
        case .failure(let error):
            return .failure(error)

        case .success(let info):
            StripeAPI.defaultPublishableKey = StripeConfig.publishableKey

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "RSMS"
            configuration.allowsDelayedPaymentMethods = false
            if let bundleId = Bundle.main.bundleIdentifier {
                configuration.returnURL = "\(bundleId)://stripe-redirect"
            }

            let paymentSheet = PaymentSheet(
                paymentIntentClientSecret: info.clientSecret,
                configuration: configuration
            )

            return .success(
                StripePaymentSheetSession(
                    paymentIntentId: info.paymentIntentId,
                    paymentSheet: paymentSheet
                )
            )
        }
    }

    // MARK: - Edge Function

    private struct EdgePayload: Encodable {
        let amount: Int
        let currency: String
        let orderId: String?
        let description: String?
    }

    private struct PaymentIntentResponse: Decodable {
        let clientSecret: String?
        let paymentIntentId: String?
        let status: String?
        let error: String?
    }

    private struct PaymentIntentInfo {
        let clientSecret: String
        let paymentIntentId: String
    }

    private func createPaymentIntent(
        amount: Int,
        currency: String,
        orderId: UUID?
    ) async -> Result<PaymentIntentInfo, Error> {
        let payload = EdgePayload(
            amount: amount,
            currency: currency,
            orderId: orderId?.uuidString.lowercased(),
            description: orderId.map { "RSMS Order \($0.uuidString.prefix(8))" }
        )

        do {
            let response: PaymentIntentResponse = try await client.functions.invoke(
                edgeFunctionName,
                options: FunctionInvokeOptions(body: payload)
            )

            if let error = response.error {
                return .failure(StripePaymentError.edgeFunctionError(error))
            }

            guard let clientSecret = response.clientSecret,
                  let paymentIntentId = response.paymentIntentId else {
                return .failure(StripePaymentError.missingClientSecret)
            }

            return .success(
                PaymentIntentInfo(
                    clientSecret: clientSecret,
                    paymentIntentId: paymentIntentId
                )
            )
        } catch {
            return .failure(StripePaymentError.edgeFunctionError(parseEdgeInvokeError(error)))
        }
    }

    private func parseEdgeInvokeError(_ error: Error) -> String {
        let description = String(describing: error)
        if description.contains("httpError(code:") {
            return description
        }
        return error.localizedDescription
    }
}
