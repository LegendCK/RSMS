//
//  TaxService.swift
//  RSMS
//
//  Fetches tax rates from the Supabase `tax_rates` table.
//  Provides a cached default rate so cart ViewModels never need hardcoded values.
//

import Foundation
import Supabase

@MainActor
final class TaxService {

    static let shared = TaxService()
    private let client = SupabaseManager.shared.client

    /// Cached default tax rate (decimal, e.g. 0.18 = 18%).
    /// Falls back to 0.18 (standard GST) if Supabase has no rows.
    private(set) var defaultRate: Double = 0.18

    /// All active tax rates keyed by country code.
    private(set) var ratesByCountry: [String: TaxRateDTO] = [:]

    /// Whether rates have been fetched at least once this session.
    private(set) var hasFetched = false

    private init() {}

    // MARK: - Fetch

    /// Loads active tax rates from Supabase.
    /// Safe to call multiple times — subsequent calls refresh the cache.
    func fetchRates() async {
        do {
            let rows: [TaxRateDTO] = try await client
                .from("tax_rates")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            ratesByCountry = Dictionary(
                rows.map { ($0.country, $0) },
                uniquingKeysWith: { _, latest in latest }
            )

            // Use India rate as default since this is an Indian retail app,
            // fall back to the first available rate, then to the existing cached value.
            if let inRate = ratesByCountry["IN"] {
                defaultRate = inRate.rate
            } else if let first = rows.first {
                defaultRate = first.rate
            }

            hasFetched = true
            print("[TaxService] Loaded \(rows.count) tax rate(s) — default rate: \(defaultRate)")
        } catch {
            print("[TaxService] Failed to fetch tax rates: \(error.localizedDescription)")
            // Keep whatever cached value we have (initial 0.18 or previous fetch)
        }
    }

    /// Returns the tax rate for a given country, falling back to defaultRate.
    func rate(for country: String = "IN") -> Double {
        ratesByCountry[country]?.rate ?? defaultRate
    }
}
