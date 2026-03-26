//
//  FeatureFlags.swift
//  RSMS
//
//  Central feature flag configuration.
//  Toggle features on/off without code changes — just flip the bool.
//

import Foundation

enum FeatureFlags {

    // MARK: - Customer Email OTP

    /// When `true`, customers must verify a 6-digit email OTP after
    /// entering their password. Staff roles are never affected.
    ///
    /// **Set to `false` to disable OTP entirely** (e.g. during development
    /// or to avoid hitting Resend rate limits).
    static let isCustomerOTPEnabled: Bool = false
}
