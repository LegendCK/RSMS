import Foundation
import Supabase

enum WarrantyLookupMode: String, CaseIterable, Identifiable {
    case productId = "Product ID"
    case purchaseRecord = "Purchase Record"

    var id: String { rawValue }

    var placeholder: String {
        switch self {
        case .productId:
            return "Enter product UUID"
        case .purchaseRecord:
            return "Enter order number or order UUID"
        }
    }
}

enum WarrantyCoverageStatus: String {
    case valid = "Valid"
    case expired = "Expired"
    case notFound = "Not Found"
}

enum AfterSalesRequestType: String, CaseIterable, Identifiable {
    case exchange = "Exchange"
    case warrantyValidation = "Warranty Validation"

    var id: String { rawValue }
}

struct WarrantyLookupResult: Sendable {
    let status: WarrantyCoverageStatus
    let lookupMode: WarrantyLookupMode
    let lookupQuery: String
    let productId: UUID?
    let productName: String?
    let brand: String?
    let orderId: UUID?
    let orderNumber: String?
    let clientId: UUID?
    let storeId: UUID?
    let purchasedAt: Date?
    let coverageStart: Date?
    let coverageEnd: Date?
    let eligibleServices: [String]

    var coveragePeriodText: String {
        guard let start = coverageStart, let end = coverageEnd else {
            return "Coverage period unavailable"
        }
        return "\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}

enum WarrantyServiceError: LocalizedError {
    case invalidProductId

    var errorDescription: String? {
        switch self {
        case .invalidProductId:
            return "Product ID must be a valid UUID."
        }
    }
}

protocol WarrantyServiceProtocol: Sendable {
    func lookupWarranty(mode: WarrantyLookupMode, query: String) async throws -> WarrantyLookupResult
    func lookupWarrantyLocally(
        productId: UUID?,
        productName: String,
        brand: String?,
        purchasedAt: Date
    ) -> WarrantyLookupResult
}

final class WarrantyService: WarrantyServiceProtocol, @unchecked Sendable {

    static let shared = WarrantyService()

    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Public Interface

    func lookupWarranty(mode: WarrantyLookupMode, query: String) async throws -> WarrantyLookupResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .productId:
            return try await lookupByProductId(trimmedQuery)
        case .purchaseRecord:
            return try await lookupByPurchaseRecord(trimmedQuery)
        }
    }

    /// Local-only warranty lookup — uses SwiftData order information without any
    /// Supabase calls. Used as a fallback when an order hasn't synced to Supabase
    /// (e.g. historical POS sync failures).
    func lookupWarrantyLocally(
        productId: UUID?,
        productName: String,
        brand: String?,
        purchasedAt: Date
    ) -> WarrantyLookupResult {
        // Fetch a cached remote policy if already available (best-effort), else use heuristic.
        // Since this is sync and we can't await here, we use the name-based heuristic directly.
        let policy = warrantyPolicy(for: productName)
        return resolveStatus(
            lookupMode: .purchaseRecord,
            query: productName,
            productId: productId,
            productName: productName,
            brand: brand,
            orderId: nil,
            orderNumber: nil,
            clientId: nil,
            storeId: nil,
            purchasedAt: purchasedAt,
            policyOverride: policy
        )
    }
}

// MARK: - File-private free functions for warranty RPC calls
// Placing these outside any class/extension avoids the actor-isolation
// taint that prevents passing Encodable & Sendable params to client.rpc().

private func _warrantyRPCByProduct(
    client: SupabaseClient,
    productId: UUID
) async throws -> WarrantyRPCRow? {
    do {
        let wrapper: WarrantyRPCNullableWrapper = try await client
            .rpc("lookup_warranty_by_product",
                 params: ["p_product_id": productId.uuidString.lowercased()])
            .execute()
            .value
        return wrapper.value
    } catch {
        print("[WarrantyService] RPC 'lookup_warranty_by_product' failed — migration may not be applied: \(error.localizedDescription)")
        return nil
    }
}

private func _warrantyRPCByOrder(
    client: SupabaseClient,
    orderNumber: String
) async throws -> WarrantyRPCRow? {
    do {
        let wrapper: WarrantyRPCNullableWrapper = try await client
            .rpc("lookup_warranty_by_order",
                 params: ["p_order_number": orderNumber])
            .execute()
            .value
        return wrapper.value
    } catch {
        print("[WarrantyService] RPC 'lookup_warranty_by_order' failed — migration may not be applied: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Private RPC-based Lookup

private struct WarrantyRPCRow: Decodable, Sendable {
    let productId: UUID?
    let productName: String?
    let brand: String?
    let orderId: UUID?
    let orderNumber: String?
    let clientId: UUID?
    let storeId: UUID?
    let purchasedAt: Date?
    let coverageMonths: Int?
    let eligibleServices: [String]

    enum CodingKeys: String, CodingKey {
        case productId       = "product_id"
        case productName     = "product_name"
        case brand
        case orderId         = "order_id"
        case orderNumber     = "order_number"
        case clientId        = "client_id"
        case storeId         = "store_id"
        case purchasedAt     = "purchased_at"
        case coverageMonths  = "coverage_months"
        case eligibleServices = "eligible_services"
    }
}

/// Typed params for `lookup_warranty_by_product` RPC — must be `Encodable & Sendable`.
private struct ProductWarrantyParams: Encodable, Sendable {
    let p_product_id: String
}

/// Typed params for `lookup_warranty_by_order` RPC — must be `Encodable & Sendable`.
private struct OrderWarrantyParams: Encodable, Sendable {
    let p_order_number: String
}

/// Decodes the nullable JSON object returned by the warranty RPCs.
private struct WarrantyRPCNullableWrapper: Decodable {
    let value: WarrantyRPCRow?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else {
            value = try container.decode(WarrantyRPCRow.self)
        }
    }
}

private extension WarrantyService {

    func lookupByProductId(_ query: String) async throws -> WarrantyLookupResult {
        guard let productId = UUID(uuidString: query) else {
            throw WarrantyServiceError.invalidProductId
        }

        // Call the SECURITY DEFINER RPC — bypasses store-scoped RLS on order_items.
        let row: WarrantyRPCRow? = try await callProductWarrantyRPC(productId: productId)

        guard let row else {
            return notFoundResult(mode: .productId, query: query, productId: productId)
        }

        let policy = buildPolicy(from: row)
        return resolveStatus(
            lookupMode: .productId,
            query: query,
            productId: row.productId ?? productId,
            productName: row.productName,
            brand: row.brand,
            orderId: row.orderId,
            orderNumber: row.orderNumber,
            clientId: row.clientId,
            storeId: row.storeId,
            purchasedAt: row.purchasedAt,
            policyOverride: policy
        )
    }

    // ── Purchase-record (order number) lookup via SECURITY DEFINER RPC ─────────

    func lookupByPurchaseRecord(_ query: String) async throws -> WarrantyLookupResult {
        // Resolve by order number. UUID-format queries also work since
        // the RPC matches on order_number (string), not order ID.
        let row: WarrantyRPCRow? = try await callOrderWarrantyRPC(orderNumber: query)

        guard let row else {
            return notFoundResult(mode: .purchaseRecord, query: query, productId: nil)
        }

        let policy = buildPolicy(from: row)
        return resolveStatus(
            lookupMode: .purchaseRecord,
            query: query,
            productId: row.productId,
            productName: row.productName,
            brand: row.brand,
            orderId: row.orderId,
            orderNumber: row.orderNumber,
            clientId: row.clientId,
            storeId: row.storeId,
            purchasedAt: row.purchasedAt,
            policyOverride: policy
        )
    }

    // ── RPC callers forward to file-private free functions ────────────────────

    func callProductWarrantyRPC(productId: UUID) async throws -> WarrantyRPCRow? {
        try await _warrantyRPCByProduct(client: client, productId: productId)
    }

    func callOrderWarrantyRPC(orderNumber: String) async throws -> WarrantyRPCRow? {
        try await _warrantyRPCByOrder(client: client, orderNumber: orderNumber)
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    func buildPolicy(from row: WarrantyRPCRow) -> WarrantyPolicy? {
        guard let months = row.coverageMonths else { return nil }
        return WarrantyPolicy(coverageMonths: months, eligibleServices: row.eligibleServices)
    }

    func notFoundResult(
        mode: WarrantyLookupMode,
        query: String,
        productId: UUID?
    ) -> WarrantyLookupResult {
        WarrantyLookupResult(
            status: .notFound,
            lookupMode: mode,
            lookupQuery: query,
            productId: productId,
            productName: nil,
            brand: nil,
            orderId: nil,
            orderNumber: nil,
            clientId: nil,
            storeId: nil,
            purchasedAt: nil,
            coverageStart: nil,
            coverageEnd: nil,
            eligibleServices: []
        )
    }

    // ── Status resolution (unchanged from original) ────────────────────────────

    struct WarrantyPolicy {
        let coverageMonths: Int
        let eligibleServices: [String]
    }

    func resolveStatus(
        lookupMode: WarrantyLookupMode,
        query: String,
        productId: UUID?,
        productName: String?,
        brand: String?,
        orderId: UUID?,
        orderNumber: String?,
        clientId: UUID?,
        storeId: UUID?,
        purchasedAt: Date?,
        policyOverride: WarrantyPolicy?
    ) -> WarrantyLookupResult {
        guard let purchasedAt else {
            return WarrantyLookupResult(
                status: .notFound,
                lookupMode: lookupMode,
                lookupQuery: query,
                productId: productId,
                productName: productName,
                brand: brand,
                orderId: orderId,
                orderNumber: orderNumber,
                clientId: clientId,
                storeId: storeId,
                purchasedAt: nil,
                coverageStart: nil,
                coverageEnd: nil,
                eligibleServices: []
            )
        }

        let policy = policyOverride ?? warrantyPolicy(for: productName)
        let coverageEnd = Calendar.current.date(byAdding: .month, value: policy.coverageMonths, to: purchasedAt)

        let status: WarrantyCoverageStatus
        if let coverageEnd, Date() <= coverageEnd {
            status = .valid
        } else {
            status = .expired
        }

        return WarrantyLookupResult(
            status: status,
            lookupMode: lookupMode,
            lookupQuery: query,
            productId: productId,
            productName: productName,
            brand: brand,
            orderId: orderId,
            orderNumber: orderNumber,
            clientId: clientId,
            storeId: storeId,
            purchasedAt: purchasedAt,
            coverageStart: purchasedAt,
            coverageEnd: coverageEnd,
            eligibleServices: policy.eligibleServices
        )
    }

    // ── Name-based heuristic fallback (unchanged from original) ───────────────

    func warrantyPolicy(for productName: String?) -> WarrantyPolicy {
        let value = (productName ?? "").lowercased()

        if value.contains("watch") || value.contains("chrono") {
            return WarrantyPolicy(
                coverageMonths: 36,
                eligibleServices: [
                    "Movement calibration",
                    "Factory defect repair",
                    "Water-resistance inspection"
                ]
            )
        }

        if value.contains("jewel") || value.contains("ring") || value.contains("necklace") {
            return WarrantyPolicy(
                coverageMonths: 12,
                eligibleServices: [
                    "Clasp and setting adjustment",
                    "Manufacturing defect repair",
                    "Stone tightening"
                ]
            )
        }

        return WarrantyPolicy(
            coverageMonths: 24,
            eligibleServices: [
                "Manufacturing defect repair",
                "Hardware replacement",
                "Functional quality inspection"
            ]
        )
    }
}
