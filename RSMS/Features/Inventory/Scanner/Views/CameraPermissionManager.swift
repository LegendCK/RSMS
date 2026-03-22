//
//  CameraPermissionManager.swift
//  RSMS
//
//  Observable wrapper around AVCaptureDevice camera permission.
//
//  Responsibilities:
//  - Expose the current AVAuthorizationStatus as a reactive property
//  - Request permission on demand (only when status is .notDetermined)
//  - Update status when the system returns the user's decision
//  - Provide a convenience helper to open Settings for denied/restricted
//
//  Usage in ScannerView:
//    @State private var cameraPermission = CameraPermissionManager()
//    …
//    .task { await cameraPermission.requestIfNeeded() }
//

import SwiftUI
import AVFoundation

@Observable
@MainActor
final class CameraPermissionManager {

    // MARK: - Published State

    /// Live authorization status. SwiftUI observes this and redraws automatically.
    private(set) var status: AVAuthorizationStatus

    // MARK: - Computed

    var isAuthorized: Bool  { status == .authorized }
    var isDenied: Bool      { status == .denied || status == .restricted }
    var isUndetermined: Bool { status == .notDetermined }

    // MARK: - Init

    init() {
        // Snapshot the current status synchronously so the initial render is correct
        self.status = AVCaptureDevice.authorizationStatus(for: .video)
    }

    // MARK: - Permission Request

    /// Call from `.task { }` in the view.
    /// - If already authorized: no-op (camera starts immediately).
    /// - If not determined: presents the system permission dialog and updates status.
    /// - If denied/restricted: status stays denied; view shows the Settings prompt.
    func requestIfNeeded() async {
        switch status {
        case .authorized:
            return  // Already good — nothing to do

        case .notDetermined:
            // This is the call that presents the system permission dialog.
            // requestAccess returns on an arbitrary background thread, so we
            // hop back to MainActor before writing the property.
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = granted ? .authorized : .denied

        case .denied, .restricted:
            // Re-read in case the user just granted from Settings and backgrounded back
            status = AVCaptureDevice.authorizationStatus(for: .video)

        @unknown default:
            status = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    /// Re-reads the authorization status from the system.
    /// Call from `.onReceive(NotificationCenter…willEnterForeground)` to handle
    /// the case where the user grants access in Settings and returns to the app.
    func refresh() {
        status = AVCaptureDevice.authorizationStatus(for: .video)
    }

    // MARK: - Settings Deep Link

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
