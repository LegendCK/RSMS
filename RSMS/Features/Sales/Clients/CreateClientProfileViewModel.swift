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
            phone: phone.isEmpty ? nil : phone,
            dateOfBirth: dateOfBirth.isEmpty ? nil : dateOfBirth,
            nationality: nationality.isEmpty ? nil : nationality,
            preferredLanguage: preferredLanguage,
            addressLine1: addressLine1.isEmpty ? nil : addressLine1,
            addressLine2: addressLine2.isEmpty ? nil : addressLine2,
            city: city.isEmpty ? nil : city,
            state: state.isEmpty ? nil : state,
            postalCode: postalCode.isEmpty ? nil : postalCode,
            country: country.isEmpty ? nil : country,
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
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }
}
