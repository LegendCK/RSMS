//
//  SupabaseConfig.swift
//  infosys2
//
//  Supabase project credentials.
//  Replace the placeholder values with your actual Supabase project URL and anon key.
//

import Foundation

enum SupabaseConfig {
    private static var secrets: [String: String]? {
        guard let path = Bundle.main.path(forResource: "SupabaseSecrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            print("⚠️ Error: SupabaseSecrets.plist not found in bundle. Check RSMS/Config/SupabaseSecrets.plist.")
            return nil
        }
        return dict
    }

    static let projectURL: URL = {
        guard let urlString = secrets?["SUPABASE_URL"],
              let url = URL(string: urlString) else {
            // Fallback for previews or if not found
            return URL(string: "https://placeholder.supabase.co")!
        }
        return url
    }()

    static let anonKey: String = {
        return secrets?["SUPABASE_ANON_KEY"] ?? "MISSING_ANON_KEY"
    }()
}
