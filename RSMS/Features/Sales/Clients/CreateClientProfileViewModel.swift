//
//  CreateClientProfileViewModel.swift
//  infosys2
//

import Foundation
import SwiftData

@Observable
@MainActor
final class CreateClientProfileViewModel {
    // Personal Details
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var dateOfBirth: String = ""
    var nationality: String = ""
    var preferredLanguage: String = "en"
    
    // Address
    var addressLine1: String = ""
    var addressLine2: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = ""
    
    // VIP Segment
    var segment: String = "standard"
    
    // Privacy
    var gdprConsent: Bool = false
    var marketingOptIn: Bool = false
    
    // Preferences (Stored in notes JSON)
    var availableCategories: [String] = ["Jewellery", "Watches", "Handbags", "Ready-to-Wear", "Shoes", "Accessories"]
    var preferredCategories: Set<String> = []
    var preferredBrands: [String] = []
    var communicationPreference: String = "Email"
    
    // UI Helpers for new categories & brands
    var newCategoryText: String = ""
    var newBrandText: String = ""
    
    // Sizes
    var sizeRing: String = ""
    var sizeWrist: String = ""
    var sizeDress: String = ""
    var sizeShoe: String = ""
    var sizeJacket: String = ""
    
    // Anniversaries
    var anniversaries: [ClientAnniversary] = []
    
    // State
    var isLoading: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""
    var isSuccess: Bool = false
    var currentStep: Int = 1

    // Temporary password shown to the associate after creating a new client account
    var temporaryPassword: String = ""
    var showTempPasswordAlert: Bool = false
    
    func addAnniversary() {
        anniversaries.append(ClientAnniversary(label: "Special Day", date: ""))
    }
    
    func removeAnniversary(at index: Int) {
        anniversaries.remove(at: index)
    }
    
    func toggleCategory(_ category: String) {
        if preferredCategories.contains(category) {
            preferredCategories.remove(category)
        } else {
            preferredCategories.insert(category)
        }
    }
    
    func addNewCategory() {
        let text = newCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && !availableCategories.contains(text) {
            availableCategories.append(text)
            preferredCategories.insert(text)
        }
        newCategoryText = ""
    }
    
    func addBrand() {
        let text = newBrandText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && !preferredBrands.contains(text) {
            preferredBrands.append(text)
        }
        newBrandText = ""
    }
    
    func removeBrand(_ brand: String) {
        preferredBrands.removeAll { $0 == brand }
    }
    
    func goNextStep() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty, !trimmedEmail.isEmpty else {
            errorMessage = "First name, last name, and email are mandatory."
            showError = true
            return
        }
        currentStep = 2
    }
    
    @discardableResult
    func save(creatorId: UUID?) async -> ClientDTO? {
        guard gdprConsent else {
            errorMessage = "Privacy consent is mandatory to create a profile."
            showError = true
            return nil
        }
        
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = normalizedOptional(phone)
        let normalizedState = normalizedStateCode(from: state)
        let normalizedPostalCode = normalizedOptional(postalCode)
        let normalizedAddressLine1 = normalizedOptional(addressLine1)
        let normalizedAddressLine2 = normalizedOptional(addressLine2)
        let normalizedCity = normalizedOptional(city)
        let normalizedCountry = isoCountryCode(from: country)
        let normalizedNationality = isoCountryCode(from: nationality)
        let normalizedPreferredLanguage = isoLanguageCode(from: preferredLanguage)
        
        isLoading = true
        defer { isLoading = false }
        
        // Build Notes JSON Blob
        var blob = ClientNotesBlob()
        blob.preferences.preferredCategories = Array(preferredCategories)
        blob.preferences.preferredBrands = preferredBrands
        blob.preferences.communicationPreference = communicationPreference
        
        blob.sizes.ring = sizeRing
        blob.sizes.wrist = sizeWrist
        blob.sizes.dress = sizeDress
        blob.sizes.shoe = sizeShoe
        blob.sizes.jacket = sizeJacket
        
        blob.anniversaries = anniversaries
        
        let notesJson = blob.toJSONString() ?? ""
        
        let insertDTO = ClientInsertDTO(
            id: nil,                          // id is assigned inside createClientWithAuth via auth.signUp
            firstName: trimmedFirst,
            lastName: trimmedLast,
            email: trimmedEmail,
            phone: normalizedPhone,
            dateOfBirth: dateOfBirth.isEmpty ? nil : dateOfBirth,
            nationality: normalizedNationality,
            preferredLanguage: normalizedPreferredLanguage,
            addressLine1: normalizedAddressLine1,
            addressLine2: normalizedAddressLine2,
            city: normalizedCity,
            state: normalizedState,
            postalCode: normalizedPostalCode,
            country: normalizedCountry,
            segment: segment,
            notes: notesJson,
            gdprConsent: gdprConsent,
            marketingOptIn: marketingOptIn,
            createdBy: creatorId,
            isActive: true
        )

        do {
            // Creates auth account first (so id is never null), then inserts profile,
            // then restores the associate's session automatically.
            let (createdClient, tempPass) = try await ClientService.shared.createClientWithAuth(insertDTO)
            temporaryPassword = tempPass
            isSuccess = true
            showTempPasswordAlert = true
            return createdClient
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("character(2)") {
                errorMessage = "State/country/language code is invalid. Use 2-letter codes (for example: KA, IN, EN)."
            } else if message.localizedCaseInsensitiveContains("password should contain") {
                errorMessage = "Temporary password generation failed policy checks. Please try again."
            } else {
                errorMessage = message
            }
            showError = true
            return nil
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isoLanguageCode(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "en" }
        let token = trimmed.lowercased()
        if token.count == 2 { return token }
        if let prefix = token.split(separator: "-").first, prefix.count == 2 {
            return String(prefix)
        }
        return String(token.prefix(2)).padding(toLength: 2, withPad: "x", startingAt: 0)
    }

    private func isoCountryCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let upper = trimmed.uppercased()
        if upper.count == 2 { return upper }

        switch upper {
        case "INDIA", "BHARAT": return "IN"
        case "UNITED STATES", "USA", "UNITED STATES OF AMERICA": return "US"
        case "UNITED KINGDOM", "UK", "GREAT BRITAIN": return "GB"
        case "FRANCE": return "FR"
        case "ITALY": return "IT"
        case "GERMANY": return "DE"
        case "SPAIN": return "ES"
        case "AUSTRALIA": return "AU"
        case "CANADA": return "CA"
        case "JAPAN": return "JP"
        case "CHINA": return "CN"
        case "UAE", "UNITED ARAB EMIRATES": return "AE"
        default:
            let prefix = String(upper.prefix(2))
            return prefix.count == 2 ? prefix : nil
        }
    }

    private func normalizedStateCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let upper = trimmed.uppercased()
        if upper.count == 2 { return upper }
        let prefix = String(upper.prefix(2))
        return prefix.count == 2 ? prefix : nil
    }
}
