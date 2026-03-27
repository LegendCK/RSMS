//
//  ScanManager.swift
//  RSMS
//
//  Hardened v2:
//  - Duplicate detection: [String: Date] dictionary, 2-second window
//    (same barcode after >2s is allowed again — works for A→B→A flows)
//  - Debounce: 500 ms AVFoundation stream guard combined with timestamp check
//  - ScanProcessor abstraction preserved for future batch/offline swap
//  - Session lifecycle: start / end / cleanUpStale
//

import Foundation

// MARK: - ScanProcessor Protocol

/// Abstraction for scan execution strategy.
/// Phase 1: RealTimeScanProcessor (Supabase direct)
/// Phase 2: BatchScanProcessor (CoreData + sync) — swap without touching callers
protocol ScanProcessor: Sendable {
    func process(barcode: String, sessionId: UUID, type: ScanType) async throws -> ScanResultDTO
}

// MARK: - Phase 1: Real-Time Processor

final class RealTimeScanProcessor: ScanProcessor {
    private let service: ScanServiceProtocol

    init(service: ScanServiceProtocol = ScanService.shared) {
        self.service = service
    }

    func process(barcode: String, sessionId: UUID, type: ScanType) async throws -> ScanResultDTO {
        // Execute the safe sequence defined in ScanService (lookup → log → mutate)
        return try await service.processScan(barcode: barcode, sessionId: sessionId, type: type)
    }
}

// MARK: - ScanResult (display model)

struct ScanResult: Identifiable, Equatable {
    let id: UUID
    let barcode: String
    let productName: String
    let sku: String
    let price: Double
    let status: String
    let brand: String?
    let imageUrls: [String]?
    let scannedAt: Date
    let scanType: ScanType

    var formattedPrice: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "INR"
        return f.string(from: NSNumber(value: price)) ?? "₹\(price)"
    }

    var itemStatus: ProductItemStatus {
        ProductItemStatus(rawValue: status) ?? .inStock
    }

    init(from dto: ScanResultDTO, barcode: String, scanType: ScanType) {
        self.id          = UUID()
        self.barcode     = barcode
        self.productName = dto.productName
        self.sku         = dto.sku
        self.price       = dto.price
        self.status      = dto.itemStatus
        self.brand       = dto.brand
        self.imageUrls   = dto.imageUrls
        self.scannedAt   = Date()
        self.scanType    = scanType
    }
}

// MARK: - ScanManager

/// @MainActor session manager.
///
/// Duplicate detection uses [String: Date]:
///   - Same barcode within `duplicateWindowSeconds` → treated as duplicate
///   - Same barcode after the window → processed normally (A→B→A is valid)
///
/// Debounce (500 ms) guards against the AVFoundation stream firing dozens
/// of callbacks for a single physical scan event.
@MainActor
final class ScanManager {
    static let shared = ScanManager(
        processor: RealTimeScanProcessor(service: ScanService.shared),
        service: ScanService.shared
    )
    // MARK: - Configuration

    /// Rapid-fire guard: ignore re-detection within this interval (AVFoundation stream).
    let debounceInterval: TimeInterval = 0.8

    /// Same barcode within this window → duplicate warning. After the window → allowed.
    let duplicateWindowSeconds: TimeInterval = 2.0

    // MARK: - Dependencies

    private var processor: ScanProcessor
    private let service: ScanServiceProtocol

    // MARK: - Session State

    private(set) var currentSessionId: UUID?
    private(set) var currentScanType: ScanType = .audit

    // MARK: - Duplicate / Debounce Tracking

    /// Maps barcode → last time it was *successfully processed* (not just seen).
    /// Cleared on endSession(); individual entries expire after `duplicateWindowSeconds`.
    private var lastScanTimes: [String: Date] = [:]

    /// Tracks the very last barcode *seen* by the camera + the time it was seen.
    /// Used purely for the AVFoundation stream debounce.
    private var lastSeenBarcode: String?
    private var lastSeenTime: Date?

    // MARK: - Init

    private init(
        processor: ScanProcessor,
        service: ScanServiceProtocol
    ) {
        self.processor = processor
        self.service   = service
    }

    // MARK: - Session Lifecycle

    func startSession(type: ScanType) async throws {
        let sessionId = try await service.createSession(type: type)
        currentSessionId  = sessionId
        currentScanType   = type
        lastScanTimes     = [:]
        lastSeenBarcode   = nil
        lastSeenTime      = nil
    }

    func endSession() async throws {
        guard let sessionId = currentSessionId else { return }
        try await service.endSession(sessionId)
        currentSessionId = nil
        lastScanTimes    = [:]
    }

    // MARK: - Stale Session Recovery

    /// Call on app launch to close any sessions that never received an `ended_at`.
    /// Prevents orphaned ACTIVE sessions in the database.
    func cleanUpStaleSessions() async {
        do {
            try await service.closeStaleSessions()
        } catch {
            print("[ScanManager] Stale session cleanup failed (non-fatal): \(error)")
        }
    }

    // MARK: - Scan Guard

    enum ScanGuardResult {
        case proceed
        case debounced          // AVFoundation stream noise — silently ignore
        case duplicate(Date)    // Same barcode within duplicate window — show warning
        case noActiveSession
    }

    /// Evaluates whether a detected barcode should be processed.
    /// Call this BEFORE `process(barcode:)`.
    func evaluate(barcode: String) -> ScanGuardResult {
        guard currentSessionId != nil else { return .noActiveSession }

        let now = Date()

        // 1. AVFoundation debounce — same barcode seen again within 500 ms
        if barcode == lastSeenBarcode,
           let lastSeen = lastSeenTime,
           now.timeIntervalSince(lastSeen) < debounceInterval {
            return .debounced
        }

        // Update "last seen" regardless of outcome
        lastSeenBarcode = barcode
        lastSeenTime    = now

        // 2. Duplicate window check — same barcode processed recently
        if let lastProcessed = lastScanTimes[barcode],
           now.timeIntervalSince(lastProcessed) < duplicateWindowSeconds {
            return .duplicate(lastProcessed)
        }

        return .proceed
    }

    // MARK: - Scan Processing

    /// Full scan pipeline. Only call after `guard` returns `.proceed`.
    func process(barcode: String) async throws -> ScanResult {
        guard let sessionId = currentSessionId else {
            throw ScanError.noActiveSession
        }

        // Record the processed time BEFORE the network call to handle concurrent scans
        lastScanTimes[barcode] = Date()

        do {
            let dto = try await processor.process(
                barcode:   barcode,
                sessionId: sessionId,
                type:      currentScanType
            )
            return ScanResult(from: dto, barcode: barcode, scanType: currentScanType)
        } catch {
            // On failure, remove the timestamp so the user can retry
            lastScanTimes.removeValue(forKey: barcode)
            throw error
        }
    }

    // MARK: - Processor Swap (future batch mode)

    func switchProcessor(to newProcessor: ScanProcessor) {
        processor = newProcessor
    }
}

// MARK: - Errors

enum ScanError: LocalizedError {
    case noActiveSession
    case barcodeNotFound(String)
    case networkUnavailable
    case operationFailed(String)
    case stateWarning(String, ScanResultDTO)
    case stateInfo(String, ScanResultDTO)

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active session. Tap 'Start Session' to begin."
        case .barcodeNotFound(let code):
            return "Unknown barcode: \(code)"
        case .networkUnavailable:
            return "Network unavailable. Check your connection."
        case .operationFailed(let detail):
            return "Scan failed: \(detail)"
        case .stateWarning(let msg, _):
            return msg
        case .stateInfo(let msg, _):
            return msg
        }
    }
}
