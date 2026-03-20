//
//  ScannerViewModel.swift
//  RSMS — Hardened v2
//
//  @Observable MVVM ViewModel for the scanner screen.
//  Consumes ScanManager guard results (debounce / duplicate / proceed)
//  and maps them to UI-facing ScanState transitions.
//

import SwiftUI

// MARK: - ScanState

enum ScanState: Equatable {
    case idle
    case found(ScanResult)
    case duplicate(String)   // Human-readable "Already scanned: <barcode>"
    case error(String)       // Human-readable error from ScanError.errorDescription
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

    init(manager: ScanManager = .shared) {
        self.manager = manager
    }

    // MARK: - Session Control

    func startSession() async {
        guard !sessionActive else { return }
        isStartingSession = true
        defer { isStartingSession = false }

        do {
            try await manager.startSession(type: currentScanType)
            sessionActive = true
            scanState     = .idle
            recentScans   = []
            totalSessionScans = 0
        } catch {
            scanState = .error("Failed to start session: \(error.localizedDescription)")
        }
    }

    func endSession() async {
        guard sessionActive else { return }
        do {
            try await manager.endSession()
        } catch {
            print("[ScannerViewModel] endSession error (non-fatal): \(error)")
        }
        sessionActive = false
        scanState     = .idle
    }

    // MARK: - Barcode Detection

    /// Entry point called by BarcodeScannerView on every detected barcode.
    func onBarcodeDetected(_ barcode: String) {
        guard sessionActive else {
            // Don't interrupt with an error if user hasn't started yet —
            // just silently ignore; the Start Session button is visible.
            return
        }

        let guardResult = manager.evaluate(barcode: barcode)

        switch guardResult {
        case .debounced:
            // Silent — AVFoundation stream noise, no UI change needed
            return

        case .duplicate:
            // Just highlight the duplicate scan briefly
            triggerFeedback(.warning)
            
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
            return

        case .noActiveSession:
            // Race condition guard — shouldn't reach here but handle gracefully
            scanState = .error("No active session.")
            return

        case .proceed:
            break
        }

        // Dispatch async scan — keeps UI responsive
        Task {
            do {
                let result = try await manager.process(barcode: barcode)
                triggerFeedback(.success)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    scanState = .found(result)
                    recentScans.insert(result, at: 0)
                    totalSessionScans += 1
                    
                    if recentScans.count > 50 {
                        recentScans = Array(recentScans.prefix(50))
                    }
                }
                // Auto-dismiss the result card after 5 seconds
                scheduleClearState(after: 5, clearFound: true)
            } catch let scanErr as ScanError {
                triggerFeedback(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    // ScanError.barcodeNotFound already contains "Unknown barcode: <value>"
                    scanState = .error(scanErr.errorDescription ?? "Unknown error.")
                }
                scheduleClearState(after: 4)
            } catch let error as URLError {
                triggerFeedback(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    scanState = .error("Network unavailable. Please check your connection.")
                }
                scheduleClearState(after: 4)
            } catch {
                triggerFeedback(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    scanState = .error(error.localizedDescription)
                }
                scheduleClearState(after: 4)
            }
        }
    }

    // MARK: - Helpers

    private func scheduleClearState(after seconds: Double, clearFound: Bool = false) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            withAnimation(.easeOut(duration: 0.3)) {
                if case .found = scanState, !clearFound { return }
                scanState = .idle
            }
        }
    }

    private func triggerFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }
}
