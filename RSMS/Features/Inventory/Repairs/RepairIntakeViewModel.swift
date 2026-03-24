//
//  RepairIntakeViewModel.swift
//  RSMS
//
//  ViewModel for the Repair Intake form sheet.
//  Only imports SwiftUI — all Supabase calls are delegated to
//  ServiceTicketService so this file stays free of PostgREST types.
//
//  NEW FILE — place in RSMS/Features/Inventory/Repairs/
//

import SwiftUI

@Observable
@MainActor
final class RepairIntakeViewModel {

    // MARK: - Form State

    var selectedType: RepairType        = .repair
    var conditionNotes: String          = ""
    var additionalNotes: String         = ""
    var estimatedCostText: String       = ""
    var slaDueDate: Date                = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var includeSLA: Bool                = true

    // MARK: - UI State

    var isSubmitting: Bool              = false
    var submittedTicket: ServiceTicketDTO? = nil
    var errorMessage: String?           = nil

    // MARK: - Injected Context

    let scanResult: ScanResult          // Product from the scanner — already validated
    let storeId: UUID                   // IC's store — required FK
    let assignedToUserId: UUID?         // IC's own user ID — stored on the ticket

    // MARK: - Dependencies

    private let service: ServiceTicketServiceProtocol

    // MARK: - Init

    init(
        scanResult: ScanResult,
        storeId: UUID,
        assignedToUserId: UUID?,
        service: ServiceTicketServiceProtocol = ServiceTicketService.shared
    ) {
        self.scanResult          = scanResult
        self.storeId             = storeId
        self.assignedToUserId    = assignedToUserId
        self.service             = service
    }

    // MARK: - Validation

    var isFormValid: Bool {
        !conditionNotes.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var parsedCost: Double? {
        guard !estimatedCostText.isEmpty else { return nil }
        return Double(estimatedCostText.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Submit

    func submit() async {
        guard isFormValid, !isSubmitting else { return }
        isSubmitting  = true
        errorMessage  = nil

        do {
            // Step 1 — resolve barcode → product_id via service (no Supabase import here)
            let productId = try await service.resolveProductId(forBarcode: scanResult.barcode)

            // Step 2 — format SLA date as YYYY-MM-DD
            let slaString: String? = includeSLA
                ? slaDueDate.formatted(.iso8601.year().month().day())
                : nil

            // Step 3 — build insert payload
            let payload = ServiceTicketInsertDTO(
                clientId:      nil,
                storeId:       storeId,
                assignedTo:    assignedToUserId,
                productId:     productId,
                orderId:       nil,
                type:          selectedType.rawValue,
                status:        RepairStatus.intake.rawValue,
                conditionNotes: conditionNotes.trimmingCharacters(in: .whitespaces),
                estimatedCost: parsedCost,
                currency:      "USD",
                slaDueDate:    slaString,
                notes:         additionalNotes.trimmingCharacters(in: .whitespaces).isEmpty
                                   ? nil
                                   : additionalNotes.trimmingCharacters(in: .whitespaces)
            )

            // Step 4 — write to Supabase
            submittedTicket = try await service.createTicket(payload)
            NotificationCenter.default.post(name: .repairTicketCreated, object: nil)

        } catch {
            errorMessage = "Could not create ticket: \(error.localizedDescription)"
        }

        isSubmitting = false
    }
}
