//
//  StripeConfig.swift
//  RSMS
//
//  Stripe publishable key for client-side payment confirmation.
//  The secret key (sk_...) NEVER goes here — it lives in the
//  Supabase Edge Function environment only.
//
//  HOW TO SET UP:
//  1. Go to https://dashboard.stripe.com/test/apikeys
//  2. Copy your "Publishable key" (starts with pk_test_...)
//  3. Paste it below replacing the placeholder
//

import Foundation

enum StripeConfig {
    private static var secrets: [String: String]? {
        guard let path = Bundle.main.path(forResource: "StripeSecrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            print("⚠️ Error: StripeSecrets.plist not found in bundle. Check RSMS/Config/StripeSecrets.plist.")
            return nil
        }
        return dict
    }

    /// Stripe **publishable** key — safe to embed in client apps.
    static let publishableKey: String = {
        return secrets?["STRIPE_PUBLISHABLE_KEY"] ?? "pk_test_placeholder"
    }()

    /// Stripe API base URL (used for direct REST calls)
    static let apiBaseURL = "https://api.stripe.com/v1"
}
