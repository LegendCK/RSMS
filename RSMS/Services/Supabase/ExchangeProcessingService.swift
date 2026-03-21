import Foundation
import Supabase

enum ExchangeProcessingError: LocalizedError {
    case clientMissing
    case productMissing
    case invalidQuantity

    var errorDescription: String? {
        switch self {
        case .clientMissing:
            return "Cannot process exchange because client information is missing on the purchase record."
        case .productMissing:
            return "Replacement product could not be found."
        case .invalidQuantity:
            return "Replacement quantity must be at least 1."
        }
    }
}

struct ExchangeOrderResult {
    let orderNumber: String
    let replacementProductId: UUID
    let replacementProductName: String
    let quantity: Int
}

protocol ExchangeProcessingServiceProtocol: Sendable {
    func createReplacementOrder(
        lookupResult: WarrantyLookupResult,
        replacementProductId: UUID,
        quantity: Int
    ) async throws -> ExchangeOrderResult
}

@MainActor
final class ExchangeProcessingService: ExchangeProcessingServiceProtocol {
    static let shared = ExchangeProcessingService()

    private let client = SupabaseManager.shared.client

    private init() {}

    func createReplacementOrder(
        lookupResult: WarrantyLookupResult,
        replacementProductId: UUID,
        quantity: Int
    ) async throws -> ExchangeOrderResult {
        guard let clientId = lookupResult.clientId else {
            throw ExchangeProcessingError.clientMissing
        }
        guard quantity > 0 else {
            throw ExchangeProcessingError.invalidQuantity
        }

        struct ReplacementProductRow: Decodable {
            let id: UUID
            let name: String
            let price: Double
        }

        let productRows: [ReplacementProductRow] = try await client
            .from("products")
            .select("id,name,price")
            .eq("id", value: replacementProductId.uuidString.lowercased())
            .limit(1)
            .execute()
            .value

        guard let product = productRows.first else {
            throw ExchangeProcessingError.productMissing
        }

        let subtotal = product.price * Double(quantity)
        let orderNumber = generateExchangeOrderNumber()

        try await OrderService.shared.syncOrder(
            clientId: clientId,
            cartItems: [(
                productId: product.id,
                productName: product.name,
                quantity: quantity,
                unitPrice: product.price
            )],
            orderNumber: orderNumber,
            subtotal: subtotal,
            discountTotal: subtotal,
            taxTotal: 0,
            grandTotal: 0,
            channel: "in_store"
        )

        return ExchangeOrderResult(
            orderNumber: orderNumber,
            replacementProductId: product.id,
            replacementProductName: product.name,
            quantity: quantity
        )
    }

    private func generateExchangeOrderNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        return "EXCH-\(formatter.string(from: Date()))"
    }
}
