//
//  ScannerView.swift
//  RSMS — v4 (Crash Fix)
//
//  CRASH FIX: Removed ImagePicker, BarcodeImageScanner (don't exist in project)
//  and replaced PressableButton._onButtonGesture (private Apple API) with a
//  safe DragGesture-based press detection.
//
//  Layers (back to front):
//    1. Dark gradient background
//    2. BarcodeScannerView (live camera feed, full-screen)
//    3. ScanFrameView (vignette + corner brackets + scan line)
//    4. Success flash
//    5. Top HUD (session status, scan type, count)
//    6. Bottom panel — single state-driven layer
//

import SwiftUI
import AVFoundation

// MARK: - ScannerView

struct ScannerView: View {

    // MARK: State

    @State private var viewModel: ScannerViewModel?
    @State private var cameraPermission: CameraPermissionManager?
    @State private var flashOverlay     = false
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            // ── 1. Background ──────────────────────────────────────────────
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.06),
                         Color(red: 0.08, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let viewModel, let cameraPermission {
                // ── 2. Camera Preview ──────────────────────────────────────────
                if cameraPermission.isAuthorized {
                    BarcodeScannerView { barcode in
                        Task { @MainActor in
                            viewModel.onBarcodeDetected(barcode)
                            triggerSuccessFlash()
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    cameraPermissionView(cameraPermission)
                }

                // ── 3. Scan Frame ───────────────────────────────────────────────
                if cameraPermission.isAuthorized {
                    ScanFrameView(sessionActive: viewModel.sessionActive)
                }

                // ── 4. Success Flash ────────────────────────────────────────────
                if flashOverlay {
                    Color.white.opacity(0.08)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // ── 5. HUD + Bottom Panel ───────────────────────────────────────
                VStack(spacing: 0) {
                    topHUD(viewModel)
                        .padding(.top, 8)
                    Spacer()
                    bottomPanel(viewModel)
                        .padding(.bottom, 16)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: viewModel?.scanState)
        .animation(.easeInOut(duration: 0.2), value: flashOverlay)
        .task { @MainActor in
            // Avoid re-initialization on background/foreground transitions
            guard viewModel == nil else { return }
            
            let vm = ScannerViewModel()
            let cp = CameraPermissionManager()
            
            self.viewModel = vm
            self.cameraPermission = cp
            
            await cp.requestIfNeeded()
            // Inject store + user context so sessions record who created them
            vm.sessionContext = ScanSessionContext(
                storeId: appState.currentStoreId,
                userId:  appState.currentUserProfile?.id
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in cameraPermission?.refresh() }
    }

    // MARK: - Top HUD

    private func topHUD(_ viewModel: ScannerViewModel) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("BARCODE SCANNER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(Color.white.opacity(0.5))
                Text(viewModel.currentScanType.displayName.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }

            Spacer()

            HStack(spacing: 8) {
                sessionPill(viewModel)

                if viewModel.sessionActive {
                    Text("\(viewModel.totalSessionScans)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColors.accent.opacity(0.25), in: Capsule())
                }

                scanTypeMenu(viewModel)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.6))
    }

    private func sessionPill(_ viewModel: ScannerViewModel) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(viewModel.sessionActive ? Color.green : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(viewModel.sessionActive ? "ACTIVE" : "INACTIVE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(viewModel.sessionActive ? .green : Color.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(
            viewModel.sessionActive ? Color.green.opacity(0.4) : Color.white.opacity(0.1),
            lineWidth: 0.5
        ))
    }

    private func scanTypeMenu(_ viewModel: ScannerViewModel) -> some View {
        Menu {
            ForEach(ScanType.allCases, id: \.self) { type in
                Button {
                    if !viewModel.sessionActive {
                        viewModel.currentScanType = type
                    }
                } label: {
                    HStack {
                        Text(type.displayName)
                        if viewModel.currentScanType == type {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(viewModel.sessionActive)
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    // MARK: - Bottom Panel

    private func bottomPanel(_ viewModel: ScannerViewModel) -> some View {
        VStack(spacing: 10) {
            // Status banner (always rendered, adapts to state)
            statusBanner(viewModel)

            // Recent scans — ONLY when no card is showing
            if viewModel.sessionActive,
               !viewModel.recentScans.isEmpty,
               !isFoundState(viewModel) {
                RecentScansListView(viewModel: viewModel)
                    .frame(maxHeight: 200)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Scanned item card
            if case .found(let result) = viewModel.scanState {
                ScannedItemCard(result: result, onRepairTap: {
                    viewModel.cancelAutoDismiss()
                })
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Session buttons
            sessionButtons(viewModel)
                .padding(.horizontal, 16)
        }
    }

    private func isFoundState(_ viewModel: ScannerViewModel) -> Bool {
        if case .found = viewModel.scanState { return true }
        return false
    }

    // MARK: - Status Banner

    @ViewBuilder
    private func statusBanner(_ viewModel: ScannerViewModel) -> some View {
        switch viewModel.scanState {
        case .idle:
            if viewModel.sessionActive {
                toastBanner(icon: "viewfinder",
                            text: "Point camera at a barcode",
                            color: Color.white.opacity(0.45))
            }

        case .found(let result):
            toastBanner(icon: scanTypeIcon(for: viewModel.currentScanType),
                        text: scanSuccessMessage(result: result, type: viewModel.currentScanType),
                        color: statusBannerColor(for: result.itemStatus))

        case .warning(let msg):
            toastBanner(icon: "exclamationmark.triangle.fill",
                        text: msg,
                        color: Color(red: 1.0, green: 0.75, blue: 0.2))

        case .error(let msg):
            toastBanner(icon: "xmark.circle.fill",
                        text: msg,
                        color: Color(red: 1, green: 0.35, blue: 0.35))
        }
    }

    private func toastBanner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 13))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.10, green: 0.09, blue: 0.12).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.35), lineWidth: 0.75)
                )
        )
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Banner Content Helpers

    private func scanTypeIcon(for type: ScanType) -> String {
        switch type {
        case .in:     return "arrow.down.circle.fill"
        case .out:    return "arrow.up.circle.fill"
        case .audit:  return "checkmark.circle.fill"
        case .return: return "arrow.uturn.left.circle.fill"
        }
    }

    private func scanSuccessMessage(result: ScanResult, type: ScanType) -> String {
        switch type {
        case .in:     return "Received · \(result.itemStatus.displayName)"
        case .out:    return "Dispatched · \(result.itemStatus.displayName)"
        case .audit:  return "Audited · \(result.itemStatus.displayName) (no change)"
        case .return: return "Returned · \(result.itemStatus.displayName)"
        }
    }

    private func statusBannerColor(for status: ProductItemStatus) -> Color {
        switch status {
        case .inStock:  return Color(red: 0.2, green: 0.85, blue: 0.5)
        case .sold:     return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .reserved: return Color(red: 1.0, green: 0.65, blue: 0.15)
        case .damaged:  return Color(red: 0.9, green: 0.5, blue: 0.1)
        case .returned: return Color(red: 0.65, green: 0.45, blue: 1.0)
        }
    }

    // MARK: - Session Buttons

    private func sessionButtons(_ viewModel: ScannerViewModel) -> some View {
        Group {
            if viewModel.sessionActive {
                scannerButton(
                    label: "End Session",
                    icon: "stop.circle.fill",
                    tint: Color(red: 0.85, green: 0.2, blue: 0.2),
                    action: { Task { await viewModel.endSession() } }
                )
            } else {
                if viewModel.isStartingSession {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.black)
                        Text("Starting session…")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.5), AppColors.accent.opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                } else {
                    scannerButton(
                        label: "Start Session",
                        icon: "barcode.viewfinder",
                        tint: AppColors.accent,
                        action: { Task { await viewModel.startSession() } }
                    )
                }
            }
        }
    }

    private func scannerButton(
        label: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                )
                .shadow(color: tint.opacity(0.4), radius: 10, y: 5)
        }
    }

    // MARK: - Camera Permission View

    private func cameraPermissionView(_ manager: CameraPermissionManager) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.white.opacity(0.3))

            VStack(spacing: 8) {
                Text("Camera Access Required")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Enable camera access in Settings to scan barcodes.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Button("Open Settings") { manager.openSettings() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(AppColors.accent.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(AppColors.accent.opacity(0.3), lineWidth: 0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Flash Helper

    private func triggerSuccessFlash() {
        guard !flashOverlay else { return }
        withAnimation { flashOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation { self.flashOverlay = false }
        }
    }
}

#Preview {
    NavigationStack {
        ScannerView()
    }
    .environment(AppState())
}
