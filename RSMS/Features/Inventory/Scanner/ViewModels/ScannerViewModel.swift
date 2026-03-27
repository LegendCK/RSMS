//
//  ScannerViewModel.swift
//  RSMS — Hardened v2
//
//  @Observable MVVM ViewModel for the scanner screen.
//  Consumes ScanManager guard results (debounce / duplicate / proceed)
//  and maps them to UI-facing ScanState transitions.
//

import SwiftUI

enum ScanState: Equatable {
    case idle
    case scanning
    case found(ScanResult)
    case warning(String, ScanResult?)
    case error(String)
    case info(String, ScanResult?)
}

// MARK: - ScannerViewModel

@Observable
@MainActor
final class ScannerViewModel {

    // MARK: - State

    var scanState: ScanState = .idle
    var currentScanItem: ScanResult? = nil
    var sessionActive: Bool = false
    var currentScanType: ScanType = .stockIn
    var isStartingSession: Bool = false
    var totalSessionScans: Int = 0

    // MARK: - Dependencies

    private let manager: ScanManager

    init(manager: ScanManager) {
        self.manager = manager
    }

    convenience init() {
        self.init(manager: ScanManager.shared)
    }

    // MARK: - Session Control

    func startSession() async {
        guard !sessionActive else { return }
        isStartingSession = true
        defer { isStartingSession = false }

        do {
            try await manager.startSession(type: currentScanType)
            triggerFeedback(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                sessionActive = true
                scanState     = .idle
            }
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
            triggerFeedback(.warning)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                scanState = .warning("Already scanned", currentScanItem)
            }
            scheduleClearState(after: 2)
            return

        case .noActiveSession:
            // Race condition guard — shouldn't reach here but handle gracefully
            scanState = .error("No active session.")
            return

        case .proceed:
            break
        }

        // Dispatch async scan — keeps UI responsive
        scanState = .scanning
        Task {
            do {
                let result = try await manager.process(barcode: barcode)
                triggerFeedback(.success)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    currentScanItem = result
                    scanState = .found(result)
                    totalSessionScans += 1
                }
                // No auto-dismissal. The user must explicitly close it.
            } catch let scanErr as ScanError {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    switch scanErr {
                    case .stateWarning(let msg, let dto):
                        triggerFeedback(.warning)
                        let item = ScanResult(from: dto, barcode: barcode, scanType: currentScanType)
                        scanState = .warning(msg, item)
                    case .stateInfo(let msg, let dto):
                        triggerFeedback(.warning)
                        let item = ScanResult(from: dto, barcode: barcode, scanType: currentScanType)
                        scanState = .info(msg, item)
                    default:
                        triggerFeedback(.error)
                        scanState = .error(scanErr.errorDescription ?? "Unknown error.")
                    }
                }
                scheduleClearState(after: 4)
            } catch _ as URLError {
                triggerFeedback(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    scanState = .error("Network unavailable. Please check your connection.")
                }
                scheduleClearState(after: 4)
            } catch {
                triggerFeedback(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    let msg = error.localizedDescription
                    if msg.lowercased().contains("already") || msg.lowercased().contains("duplicate") {
                        scanState = .warning(msg, currentScanItem)
                    } else {
                        scanState = .error(msg)
                    }
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
