//
//  TaxExemption.swift
//  RSMS
//
//  Tax-free eligibility categories aligned with Indian GST Act 2017 exemptions.
//  Used by Sales Associates during checkout to mark a transaction as tax-free
//  after verifying the customer's eligibility documentation.
//

import Foundation

// MARK: - Tax Exemption Reason

/// Predefined eligibility categories for GST-exempt transactions in India.
/// Each case maps to a recognised exemption under the GST Act / IGST Act.
enum TaxExemptionReason: String, CaseIterable, Identifiable {
    case diplomaticMission   = "Diplomatic / Embassy Purchase"
    case sezUnit             = "SEZ Unit / Developer"
    case exportOrder         = "Export / Zero-Rated Supply"
    case internationalOrg    = "UN / International Organisation"
    case governmentEntity    = "Central / State Government Entity"
    case disabledPerson      = "Disabled Person (Exempted Goods)"
    case charitableTrust     = "Registered Charitable Trust"
    case other               = "Other (Manual Verification)"

    var id: String { rawValue }

    /// Short code stored alongside the order for audit / compliance reporting.
    var code: String {
        switch self {
        case .diplomaticMission: return "DIPLO"
        case .sezUnit:           return "SEZ"
        case .exportOrder:       return "EXPORT"
        case .internationalOrg:  return "INTORG"
        case .governmentEntity:  return "GOVT"
        case .disabledPerson:    return "DISABLED"
        case .charitableTrust:   return "CHARITY"
        case .other:             return "OTHER"
        }
    }

    /// Human-readable description shown to the associate during verification.
    var verificationHint: String {
        switch self {
        case .diplomaticMission:
            return "Verify diplomatic ID card or embassy purchase order. Must present valid Mission Identity Card issued by MEA."
        case .sezUnit:
            return "Verify SEZ authorisation letter and Form-A1. Unit must be listed in the approved SEZ operations list."
        case .exportOrder:
            return "Verify Letter of Undertaking (LUT) or export bond. Confirm IEC (Import-Export Code) is valid."
        case .internationalOrg:
            return "Verify UN Laissez-Passer or organisation identity card. Must be covered under UN (Privileges & Immunities) Act."
        case .governmentEntity:
            return "Verify government purchase order with TIN / GSTIN. Must be an inter-departmental supply or exempt category."
        case .disabledPerson:
            return "Verify Disability Certificate issued under RPwD Act 2016. Only specific assistive goods are exempt."
        case .charitableTrust:
            return "Verify 12A / 80G registration certificate. Only applies to goods for charitable purpose, not resale."
        case .other:
            return "Manually verify the exemption document. Record the document type and reference number below."
        }
    }

    /// SF Symbol icon name for the UI row.
    var icon: String {
        switch self {
        case .diplomaticMission: return "building.columns.fill"
        case .sezUnit:           return "building.2.crop.circle.fill"
        case .exportOrder:       return "airplane.departure"
        case .internationalOrg:  return "globe.americas.fill"
        case .governmentEntity:  return "building.fill"
        case .disabledPerson:    return "figure.roll"
        case .charitableTrust:   return "heart.circle.fill"
        case .other:             return "doc.text.magnifyingglass"
        }
    }
}

// MARK: - Tax Exemption Verification

/// Captures the eligibility verification details entered by the Sales Associate.
struct TaxExemptionVerification {
    var isEnabled: Bool = false
    var reason: TaxExemptionReason = .diplomaticMission
    var documentReference: String = ""   // ID number, LUT ref, PO number, etc.
    var verifiedByName: String = ""      // Associate name (auto-filled from AppState)
    var notes: String = ""               // Free-form notes

    /// Whether enough information has been captured to proceed.
    var isComplete: Bool {
        isEnabled && !documentReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Formatted reason string stored on the order for audit trail.
    var formattedReason: String {
        guard isEnabled else { return "" }
        var parts = [reason.rawValue]
        let ref = documentReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ref.isEmpty { parts.append("Ref: \(ref)") }
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { parts.append("Notes: \(n)") }
        if !verifiedByName.isEmpty { parts.append("Verified by: \(verifiedByName)") }
        return parts.joined(separator: " | ")
    }
}
