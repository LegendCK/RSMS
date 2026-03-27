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
    /// Stripe **publishable** key — safe to embed in client apps.
    /// Replace this placeholder with your actual pk_test_... or pk_live_... key.
    static let publishableKey = "pk_test_51TF6PDH7VOyOxIMCW9Djs4I00HMWRs4yReLBAz2MhJTftVXfEvoo7wefZyuodA5jlD3AOC565NM2rJyupqFd9yO400nHf5WdRL"

    /// Stripe API base URL (used for direct REST calls)
    static let apiBaseURL = "https://api.stripe.com/v1"
}
