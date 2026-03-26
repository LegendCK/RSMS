//
//  ScanManager.swift
//  RSMS — Hardened v3 (Production Audit)
//
//  AUDIT FIXES:
//  1. startSession() now accepts ScanSessionContext (storeId + userId) and passes
//     it to ScanService.createSession() so sessions record who created them.
//  2. isProcessingScan flag prevents concurrent async Tasks for the same barcode.
//     Without this, rapid scanning could fire 2–3 simultaneous network calls,
//     leading to duplicate DB writes and race-condition state overwrites.
//  3. ScanProcessor.process() protocol updated to match ScanService.
//

import Foundation

// MARK: - ScanProcessor Protocol

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
/// Guard layers (evaluated in order):
///   1. isProcessingScan mutex — blocks concurrent network calls for different barcodes
///      scanned in rapid succession before the first call returns.
///   2. AVFoundation debounce (500 ms) — suppresses stream duplicates of the SAME barcode.
///   3. Duplicate window (2 s) — prevents re-processing the same barcode too quickly.
@MainActor
final class ScanManager {
    static let shared = ScanManager(
        processor: RealTimeScanProcessor(service: ScanService.shared),
        service: ScanService.shared
    )

    // MARK: - Configuration

    let debounceInterval: TimeInterval = 0.5
    let duplicateWindowSeconds: TimeInterval = 2.0

    // MARK: - Dependencies

    private var processor: ScanProcessor
    private let service: ScanServiceProtocol

    // MARK: - Session State

    private(set) var currentSessionId: UUID?
    private(set) var currentScanType: ScanType = .audit

    // MARK: - Scan Lock (concurrent scan guard)

    /// Prevents two async Task blocks from running a network scan simultaneously.
    /// Without this lock, scanning A then B before A resolves fires two concurrent
    /// Supabase calls — both could write to the DB and overwrite each other's state.
    private(set) var isProcessingScan: Bool = false

    // MARK: - Duplicate / Debounce Tracking

    private var lastScanTimes: [String: Date] = [:]
    private var lastSeenBarcode: String?
    private var lastSeenTime: Date?

    // MARK: - Init

    private init(processor: ScanProcessor, service: ScanServiceProtocol) {
        self.processor = processor
        self.service   = service
    }

    // MARK: - Session Lifecycle

    /// Start a session with the IC's store and user ID for audit trail.
    func startSession(type: ScanType, context: ScanSessionContext) async throws {
        let sessionId = try await service.createSession(type: type, context: context)
        currentSessionId  = sessionId
        currentScanType   = type
        lastScanTimes     = [:]
        lastSeenBarcode   = nil
        lastSeenTime      = nil
        isProcessingScan  = false
    }

    func endSession() async throws {
        guard let sessionId = currentSessionId else { return }
        try await service.endSession(sessionId)
        currentSessionId  = nil
        lastScanTimes     = [:]
        isProcessingScan  = false
    }

    // MARK: - Stale Session Recovery

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
        case debounced
        case duplicate(Date)
        case noActiveSession
        case busy               // Another scan is in flight — try again shortly
    }

    func evaluate(barcode: String) -> ScanGuardResult {
        guard currentSessionId != nil else { return .noActiveSession }

        // Lock guard: prevent concurrent scans
        guard !isProcessingScan else { return .busy }

        let now = Date()

        // AVFoundation debounce
        if barcode == lastSeenBarcode,
           let lastSeen = lastSeenTime,
           now.timeIntervalSince(lastSeen) < debounceInterval {
            return .debounced
        }

        lastSeenBarcode = barcode
        lastSeenTime    = now

        // Duplicate window
        if let lastProcessed = lastScanTimes[barcode],
           now.timeIntervalSince(lastProcessed) < duplicateWindowSeconds {
            return .duplicate(lastProcessed)
        }

        return .proceed
    }

    // MARK: - Scan Processing

    func process(barcode: String) async throws -> ScanResult {
        guard let sessionId = currentSessionId else {
            throw ScanError.noActiveSession
        }

        // Set lock BEFORE the network call
        isProcessingScan = true
        lastScanTimes[barcode] = Date()

        defer { isProcessingScan = false }   // Always clear lock — even on throw

        do {
            let dto = try await processor.process(
                barcode:   barcode,
                sessionId: sessionId,
                type:      currentScanType
            )
            return ScanResult(from: dto, barcode: barcode, scanType: currentScanType)
        } catch {
            // Remove timestamp so the user can retry the same barcode
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

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active session. Tap 'Start Session' to begin."
        case .barcodeNotFound(let code):
            return "Unknown barcode: \(code)"
        case .networkUnavailable:
            return "Network unavailable. Check your connection."
        case .operationFailed(let detail):
            return detail   // Already human-readable from ScanService error mapping
        }
    }
}
