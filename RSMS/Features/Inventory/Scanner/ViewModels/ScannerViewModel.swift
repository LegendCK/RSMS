//
//  ScannerViewModel.swift
//  RSMS — Hardened v4 (Production Audit)
//
//  AUDIT FIXES v4:
//  1. startSession() reads store_id + userId from AppState and passes them as
//     ScanSessionContext — sessions now record who created them.
//  2. Handles new .busy guard result (another scan in flight, silently dropped).
//  3. Haptic feedback reuses a single pre-prepared generator (not created per scan).
//  4. operationFailed errors show without the stutter-redundant "Scan failed:" prefix.
//

import SwiftUI

// MARK: - ScanState

enum ScanState: Equatable {
    case idle
    case found(ScanResult)
    case warning(String)     // Business logic rejections: sold item, duplicate, etc.
    case error(String)       // Technical failures: network, session expired, etc.
}

// MARK: - ScannerViewModel

@Observable
@MainActor
final class ScannerViewModel {

    // MARK: - State

    var scanState: ScanState = .idle
    var sessionActive: Bool = false
    var recentScans: [ScanResult] = []
    var highlightedScanId: UUID? = nil
    var currentScanType: ScanType = .in
    var isStartingSession: Bool = false
    var totalSessionScans: Int = 0

    // MARK: - Dependencies

    private let manager: ScanManager
    /// Injected by ScannerView so the session can be tied to the correct store + user.
    var sessionContext: ScanSessionContext = ScanSessionContext(storeId: nil, userId: nil)

    // MARK: - Race Condition Guards

    /// Stored Task reference — cancelled when repair sheet opens to prevent card vanishing.
    private var clearTask: Task<Void, Never>?

    // MARK: - Haptic Generator (reused — not recreated per scan)

    // AUDIT FIX: Creating a new UINotificationFeedbackGenerator on every scan is wasteful
    // and can cause a subtle delay. Reuse one and call prepare() on session start.
    private let feedbackGenerator: UINotificationFeedbackGenerator

    // MARK: - Init

    init(manager: ScanManager) {
        self.manager = manager
        self.feedbackGenerator = UINotificationFeedbackGenerator()
    }

    convenience init() {
        self.init(manager: ScanManager.shared)
    }

    // MARK: - Session Control

    func startSession() async {
        guard !sessionActive else { return }
        isStartingSession = true
        defer { isStartingSession = false }

        // Prepare haptic generator for instant feedback when first scan fires
        feedbackGenerator.prepare()

        do {
            try await manager.startSession(type: currentScanType, context: sessionContext)
            sessionActive     = true
            scanState         = .idle
            recentScans       = []
            totalSessionScans = 0
        } catch {
            scanState = .error(friendlySessionError(error))
        }
    }

    func endSession() async {
        guard sessionActive else { return }
        cancelAutoDismiss()
        do {
            try await manager.endSession()
        } catch {
            print("[ScannerViewModel] endSession error (non-fatal): \(error)")
        }
        sessionActive = false
        scanState     = .idle
    }

    // MARK: - Barcode Detection

    func onBarcodeDetected(_ barcode: String) {
        guard sessionActive else { return }

        let guardResult = manager.evaluate(barcode: barcode)

        switch guardResult {
        case .debounced:
            return

        case .busy:
            // A scan is already processing — silently drop AVFoundation noise.
            // Do not show any UI so the in-flight result is not overwritten.
            return

        case .duplicate:
            feedbackGenerator.notificationOccurred(.warning)
            if let existing = recentScans.first(where: { $0.barcode == barcode }) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    highlightedScanId = existing.id
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeOut(duration: 0.3)) {
                        if self.highlightedScanId == existing.id {
                            self.highlightedScanId = nil
                        }
                    }
                }
            }
            // Keep showing found card if one is on screen
            if case .found = scanState { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                scanState = .warning("Already scanned in this session")
            }
            scheduleWarningClear(after: 2.5)
            return

        case .noActiveSession:
            // Shouldn't reach here if sessionActive checked above — defensive
            scanState = .error("No active session.")
            return

        case .proceed:
            break
        }

        Task {
            do {
                let result = try await manager.process(barcode: barcode)
                feedbackGenerator.notificationOccurred(.success)
                feedbackGenerator.prepare() // Pre-warm for the next scan
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    scanState = .found(result)
                    recentScans.insert(result, at: 0)
                    totalSessionScans += 1
                    if recentScans.count > 50 {
                        recentScans = Array(recentScans.prefix(50))
                    }
                }
                scheduleClearState(after: 5)
            } catch let scanErr as ScanError {
                feedbackGenerator.notificationOccurred(.error)
                feedbackGenerator.prepare()
                // ScanError.operationFailed messages are already human-readable
                // (formatted by ScanService error mapping — no "Scan failed:" prefix)
                let isBusinessLogicError: Bool
                if case .operationFailed = scanErr { isBusinessLogicError = true }
                else { isBusinessLogicError = false }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if isBusinessLogicError {
                        scanState = .warning(scanErr.errorDescription ?? "Operation not allowed.")
                    } else {
                        scanState = .error(scanErr.errorDescription ?? "Unknown error.")
                    }
                }
                scheduleClearState(after: 4)
            } catch _ as URLError {
                feedbackGenerator.notificationOccurred(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    scanState = .error("Network unavailable. Please check your connection.")
                }
                scheduleClearState(after: 4)
            } catch {
                feedbackGenerator.notificationOccurred(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    scanState = .error(error.localizedDescription)
                }
                scheduleClearState(after: 4)
            }
        }
    }

    // MARK: - Auto-Dismiss Control

    func cancelAutoDismiss() {
        clearTask?.cancel()
        clearTask = nil
    }

    // MARK: - Private Helpers

    private func scheduleClearState(after seconds: Double) {
        clearTask?.cancel()
        clearTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                scanState = .idle
            }
            clearTask = nil
        }
    }

    private func scheduleWarningClear(after seconds: Double) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            withAnimation(.easeOut(duration: 0.3)) {
                if case .warning = self.scanState {
                    self.scanState = .idle
                }
            }
        }
    }

    private func friendlySessionError(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("constraint") {
            return "Session setup failed — check your scan type selection."
        } else if raw.localizedCaseInsensitiveContains("network") || raw.localizedCaseInsensitiveContains("offline") {
            return "No network connection. Please check your connection and try again."
        } else if raw.localizedCaseInsensitiveContains("unauthorized") || raw.localizedCaseInsensitiveContains("permission") {
            return "Permission denied. Only Inventory Controllers can start scan sessions."
        }
        return "Failed to start session: \(raw)"
    }
}
