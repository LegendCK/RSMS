import Foundation
import SwiftData

@MainActor
final class AddressSyncService {
    static let shared = AddressSyncService()

    private init() {}

    func hydrateLocalAddressesIfNeeded(customerEmail: String, clientId: UUID, modelContext: ModelContext) async {
        let normalizedEmail = customerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else { return }

        let local = (try? modelContext.fetch(FetchDescriptor<SavedAddress>())) ?? []
        let hasLocal = local.contains {
            $0.customerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedEmail
        }
        guard !hasLocal else { return }

        do {
            let client = try await ClientService.shared.fetchClient(id: clientId)
            guard let line1 = client.addressLine1?.trimmingCharacters(in: .whitespacesAndNewlines), !line1.isEmpty else {
                return
            }

            let address = SavedAddress(
                customerEmail: normalizedEmail,
                label: "Home",
                line1: line1,
                line2: client.addressLine2 ?? "",
                city: client.city ?? "",
                state: client.state ?? "",
                zip: client.postalCode ?? "",
                country: (client.country?.isEmpty == false ? client.country! : "IN"),
                isDefault: true
            )
            modelContext.insert(address)
            try? modelContext.save()
        } catch {
            print("[AddressSyncService] hydrateLocalAddressesIfNeeded failed: \(error.localizedDescription)")
        }
    }

    func syncDefaultAddressToClient(address: SavedAddress, clientId: UUID) async {
        do {
            let client = try await ClientService.shared.fetchClient(id: clientId)
            let payload = ClientAssociateUpdateDTO(
                firstName: client.firstName,
                lastName: client.lastName,
                phone: client.phone,
                dateOfBirth: client.dateOfBirth,
                nationality: client.nationality,
                preferredLanguage: client.preferredLanguage,
                addressLine1: address.line1,
                addressLine2: address.line2.isEmpty ? nil : address.line2,
                city: address.city,
                state: address.state,
                postalCode: address.zip,
                country: address.country,
                segment: client.segment ?? "standard",
                notes: client.notes, gdprConsent: client.gdprConsent,
                marketingOptIn: client.marketingOptIn
            )
            _ = try await ClientService.shared.updateClient(id: clientId, payload: payload)
        } catch {
            print("[AddressSyncService] syncDefaultAddressToClient failed: \(error.localizedDescription)")
        }
    }
}
