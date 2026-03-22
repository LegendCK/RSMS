//
//  ServiceTicketService.swift
//  RSMS
//
//  All Supabase I/O for the service_tickets table and barcode→product_id
//  resolution. Every other layer (ViewModels, Views) must go through this
//  service — they must NOT import Supabase or PostgREST directly.
//

import Foundation
import Supabase

private struct SubmitCustomerExchangeRPCResponse: Decodable, Sendable {
    let success: Bool?
    let ticketId: String?
    let ticketNumber: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case ticketId = "ticket_id"
        case ticketNumber = "ticket_number"
        case error
    }
}

// MARK: - Protocol

protocol ServiceTicketServiceProtocol: Sendable {
    func resolveOrderContext(orderNumber: String) async throws -> ServiceTicketOrderContext?
    func createTicket(_ payload: ServiceTicketInsertDTO) async throws -> ServiceTicketDTO
    func submitCustomerExchangeRequest(
        orderNumber: String,
        productId: UUID?,
        itemName: String,
        quantity: Int,
        reason: String,
        customerEmail: String?,
        knownStoreId: UUID?
    ) async throws -> String?
    func fetchTickets(storeId: UUID) async throws -> [ServiceTicketDTO]
    func fetchTickets(clientId: UUID) async throws -> [ServiceTicketDTO]
    func fetchTicket(id: UUID) async throws -> ServiceTicketDTO
    func updateStatus(ticketId: UUID, status: String) async throws
    func updateTicket(ticketId: UUID, patch: ServiceTicketUpdatePatch) async throws -> ServiceTicketDTO
    func resolveProductId(forBarcode barcode: String) async throws -> UUID
}

// MARK: - Implementation

final class ServiceTicketService: ServiceTicketServiceProtocol, @unchecked Sendable {

    static let shared = ServiceTicketService()

    private let client = SupabaseManager.shared.client

    private init() {}

    enum ExchangeRequestError: LocalizedError {
        case noActiveSession
        case missingOrderContext(String)
        case edgeFunctionMissing

        var errorDescription: String? {
            switch self {
            case .noActiveSession:
                return "No active session. Please sign in again and retry."
            case .missingOrderContext(let msg):
                return msg
            case .edgeFunctionMissing:
                return "Exchange request service is unavailable. Please contact support."
            }
        }
    }

    // MARK: - Order Context

    func resolveOrderContext(orderNumber: String) async throws -> ServiceTicketOrderContext? {
        let normalized = orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        struct OrderContextRow: Decodable {
            let id: UUID
            let storeId: UUID
            let clientId: UUID?

            enum CodingKeys: String, CodingKey {
                case id
                case storeId  = "store_id"
                case clientId = "client_id"
            }
        }

        let rows: [OrderContextRow] = try await client
            .from("orders")
            .select("id, store_id, client_id")
            .eq("order_number", value: normalized)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return nil }
        return ServiceTicketOrderContext(orderId: row.id, storeId: row.storeId, clientId: row.clientId)
    }

    // MARK: - Create Ticket

    func createTicket(_ payload: ServiceTicketInsertDTO) async throws -> ServiceTicketDTO {
        let ticket: ServiceTicketDTO = try await client
            .from("service_tickets")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return ticket
    }

    // MARK: - Customer Exchange Request

    /// Inserts a service_tickets row directly. RLS INSERT policy allows
    /// any authenticated user. store_id is guaranteed non-null.
    func submitCustomerExchangeRequest(
        orderNumber: String,
        productId: UUID?,
        itemName: String,
        quantity: Int,
        reason: String,
        customerEmail: String?,
        knownStoreId: UUID? = nil
    ) async throws -> String? {
        // Guaranteed non-null store resolution (throws if nothing found)
        let storeId = try await resolveStoreId(
            preferred: knownStoreId,
            orderNumber: orderNumber
        )

        let session = try await client.auth.session
        let authenticatedClientId = session.user.id

        // Try to get order context for client_id and order_id linkage
        let context = try? await resolveOrderContext(orderNumber: orderNumber)
        let resolvedClientId = context?.clientId ?? authenticatedClientId

        // Build notes
        var noteLines = [
            "Customer Exchange Request",
            "Order: \(orderNumber)",
            "Item: \(itemName) • Qty \(quantity)"
        ]
        if let email = customerEmail, !email.isEmpty {
            noteLines.append("Customer: \(email)")
        }
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedReason.isEmpty {
            noteLines.append("Reason: \(trimmedReason)")
        }

        let payload = ServiceTicketInsertDTO(
            clientId: resolvedClientId,
            storeId: storeId,
            assignedTo: nil,
            productId: productId,
            orderId: context?.orderId,
            type: RepairType.warrantyClaim.rawValue,
            status: RepairStatus.intake.rawValue,
            conditionNotes: "Customer exchange request – \(itemName) (Qty \(quantity))",
            estimatedCost: nil,
            currency: "INR",
            slaDueDate: nil,
            notes: noteLines.joined(separator: "\n")
        )

        // Plain insert — do NOT use createTicket() because it does
        // .insert().select().single() which triggers a SELECT RLS check
        // that customers fail (they aren't staff and client_id may not match).
        try await client
            .from("service_tickets")
            .insert(payload)
            .execute()

        // Return a reference (we can't SELECT the row back due to RLS)
        return "EXR-\(orderNumber)"
    }

    /// Three-tier store resolution. Returns a guaranteed non-optional UUID.
    /// 1. Locally-cached boutiqueId  2. Orders table lookup  3. First active store
    private func resolveStoreId(
        preferred: UUID?,
        orderNumber: String
    ) async throws -> UUID {
        // Tier 1
        if let preferred { return preferred }

        // Tier 2
        if let orderStore = try? await resolveOrderContext(orderNumber: orderNumber)?.storeId {
            return orderStore
        }

        // Tier 3 — first active store (last resort)
        struct StoreRow: Decodable { let id: UUID }
        let stores: [StoreRow] = try await client
            .from("stores")
            .select("id")
            .eq("is_active", value: true)
            .order("created_at", ascending: true)
            .limit(1)
            .execute()
            .value

        guard let first = stores.first else {
            throw ExchangeRequestError.missingOrderContext(
                "No active store found. Please contact support."
            )
        }
        return first.id
    }

    // MARK: - Fetch List

    func fetchTickets(storeId: UUID) async throws -> [ServiceTicketDTO] {
        let tickets: [ServiceTicketDTO] = try await client
            .from("service_tickets")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return tickets
    }

    func fetchTickets(clientId: UUID) async throws -> [ServiceTicketDTO] {
        let tickets: [ServiceTicketDTO] = try await client
            .from("service_tickets")
            .select()
            .eq("client_id", value: clientId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return tickets
    }

    // MARK: - Fetch Single

    func fetchTicket(id: UUID) async throws -> ServiceTicketDTO {
        let ticket: ServiceTicketDTO = try await client
            .from("service_tickets")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return ticket
    }

    // MARK: - Status Update

    func updateStatus(ticketId: UUID, status: String) async throws {
        try await client
            .from("service_tickets")
            .update(ServiceTicketStatusPatch(status: status))
            .eq("id", value: ticketId.uuidString)
            .execute()
    }

    func updateTicket(ticketId: UUID, patch: ServiceTicketUpdatePatch) async throws -> ServiceTicketDTO {
        let ticket: ServiceTicketDTO = try await client
            .from("service_tickets")
            .update(patch)
            .eq("id", value: ticketId.uuidString)
            .select()
            .single()
            .execute()
            .value
        return ticket
    }

    // MARK: - Barcode → Product ID Resolution

    func resolveProductId(forBarcode barcode: String) async throws -> UUID {
        struct Row: Decodable {
            let productId: UUID
            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
            }
        }
        let row: Row = try await client
            .from("product_items")
            .select("product_id")
            .eq("barcode", value: barcode)
            .single()
            .execute()
            .value
        return row.productId
    }
}

struct ServiceTicketOrderContext {
    let orderId: UUID
    let storeId: UUID
    let clientId: UUID?
}
