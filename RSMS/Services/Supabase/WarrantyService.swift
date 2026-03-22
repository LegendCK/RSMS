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
}

final class WarrantyService: WarrantyServiceProtocol, @unchecked Sendable {

    static let shared = WarrantyService()

    private let client = SupabaseManager.shared.client

    private init() {}

    func lookupWarranty(mode: WarrantyLookupMode, query: String) async throws -> WarrantyLookupResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .productId:
            return try await lookupByProductId(trimmedQuery)
        case .purchaseRecord:
            return try await lookupByPurchaseRecord(trimmedQuery)
        }
    }
}

private extension WarrantyService {

    struct ProductRow: Decodable {
        let id: UUID
        let name: String
        let brand: String?
    }

    struct OrderRow: Decodable {
        let id: UUID
        let orderNumber: String?
        let clientId: UUID?
        let storeId: UUID?
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case orderNumber = "order_number"
            case clientId = "client_id"
            case storeId = "store_id"
            case createdAt = "created_at"
        }
    }

    struct OrderItemWithJoinsRow: Decodable {
        let productId: UUID
        let orderId: UUID
        let createdAt: Date?
        let products: ProductRow?
        let orders: OrderRow?

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case orderId = "order_id"
            case createdAt = "created_at"
            case products
            case orders
        }
    }

    struct OrderItemProductRow: Decodable {
        let productId: UUID
        let products: ProductRow?

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case products
        }
    }

    struct WarrantyPolicy {
        let coverageMonths: Int
        let eligibleServices: [String]
    }

    struct WarrantyPolicyRow: Decodable {
        let productId: UUID
        let coverageMonths: Int
        let eligibleServices: [String]

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case coverageMonths = "coverage_months"
            case eligibleServices = "eligible_services"
        }
    }

    func lookupByProductId(_ query: String) async throws -> WarrantyLookupResult {
        guard let productId = UUID(uuidString: query) else {
            throw WarrantyServiceError.invalidProductId
        }

        let product: ProductRow? = try? await client
            .from("products")
            .select("id,name,brand")
            .eq("id", value: productId.uuidString.lowercased())
            .single()
            .execute()
            .value

        let rows: [OrderItemWithJoinsRow] = try await client
            .from("order_items")
            .select("product_id,order_id,created_at,products(id,name,brand),orders(id,order_number,client_id,store_id,created_at)")
            .eq("product_id", value: productId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            return WarrantyLookupResult(
                status: .notFound,
                lookupMode: .productId,
                lookupQuery: query,
                productId: product?.id ?? productId,
                productName: product?.name,
                brand: product?.brand,
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

        let remotePolicy = try await fetchRemotePolicy(productId: row.productId)

        return resolveStatus(
            lookupMode: .productId,
            query: query,
            productId: row.productId,
            productName: row.products?.name ?? product?.name,
            brand: row.products?.brand ?? product?.brand,
            orderId: row.orderId,
            orderNumber: row.orders?.orderNumber,
            clientId: row.orders?.clientId,
            storeId: row.orders?.storeId,
            purchasedAt: row.orders?.createdAt ?? row.createdAt,
            policyOverride: remotePolicy
        )
    }

    func lookupByPurchaseRecord(_ query: String) async throws -> WarrantyLookupResult {
        let orderRows: [OrderRow]
        if let orderId = UUID(uuidString: query) {
            orderRows = try await client
                .from("orders")
                .select("id,order_number,client_id,store_id,created_at")
                .eq("id", value: orderId.uuidString.lowercased())
                .limit(1)
                .execute()
                .value
        } else {
            orderRows = try await client
                .from("orders")
                .select("id,order_number,client_id,store_id,created_at")
                .eq("order_number", value: query)
                .limit(1)
                .execute()
                .value
        }

        guard let order = orderRows.first else {
            return WarrantyLookupResult(
                status: .notFound,
                lookupMode: .purchaseRecord,
                lookupQuery: query,
                productId: nil,
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

        let itemRows: [OrderItemProductRow] = try await client
            .from("order_items")
            .select("product_id,products(id,name,brand)")
            .eq("order_id", value: order.id.uuidString.lowercased())
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let item = itemRows.first else {
            return WarrantyLookupResult(
                status: .notFound,
                lookupMode: .purchaseRecord,
                lookupQuery: query,
                productId: nil,
                productName: nil,
                brand: nil,
                orderId: order.id,
                orderNumber: order.orderNumber,
                clientId: order.clientId,
                storeId: order.storeId,
                purchasedAt: order.createdAt,
                coverageStart: nil,
                coverageEnd: nil,
                eligibleServices: []
            )
        }

        let remotePolicy = try await fetchRemotePolicy(productId: item.productId)

        return resolveStatus(
            lookupMode: .purchaseRecord,
            query: query,
            productId: item.productId,
            productName: item.products?.name,
            brand: item.products?.brand,
            orderId: order.id,
            orderNumber: order.orderNumber,
            clientId: order.clientId,
            storeId: order.storeId,
            purchasedAt: order.createdAt,
            policyOverride: remotePolicy
        )
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

    func fetchRemotePolicy(productId: UUID) async throws -> WarrantyPolicy? {
        do {
            let rows: [WarrantyPolicyRow] = try await client
                .from("product_warranty_policies")
                .select("product_id,coverage_months,eligible_services")
                .eq("product_id", value: productId.uuidString.lowercased())
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else { return nil }
            return WarrantyPolicy(coverageMonths: row.coverageMonths, eligibleServices: row.eligibleServices)
        } catch {
            // Backward compatibility: if migration isn't applied yet, keep legacy policy behavior.
            return nil
        }
    }

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
