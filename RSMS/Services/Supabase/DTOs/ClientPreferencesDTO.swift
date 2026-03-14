//
//  ClientPreferencesDTO.swift
//  infosys2
//

import Foundation

struct ClientPreferences: Codable {
    var preferredCategories: [String] = []
    var preferredBrands: [String] = []
    var communicationPreference: String = "Email"
}

struct ClientSizes: Codable {
    var ring: String = ""
    var wrist: String = ""
    var dress: String = ""
    var shoe: String = ""
    var jacket: String = ""
}

struct ClientAnniversary: Codable, Identifiable {
    var id = UUID()
    var label: String
    var date: String
}

/// A wrapper to store structured data in the `notes` column of the `clients` table.
struct ClientNotesBlob: Codable {
    var notes: String = ""
    var preferences: ClientPreferences = ClientPreferences()
    var sizes: ClientSizes = ClientSizes()
    var anniversaries: [ClientAnniversary] = []
    
    /// Encodes to a JSON string
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Decodes from a JSON string
    static func from(jsonString: String?) -> ClientNotesBlob {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ClientNotesBlob.self, from: data) else {
            // If it fails to decode, maybe it's just a raw notes string from before
            var blob = ClientNotesBlob()
            blob.notes = jsonString ?? ""
            return blob
        }
        return decoded
    }
}
