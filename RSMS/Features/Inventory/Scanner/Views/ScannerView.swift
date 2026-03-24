//
//  ScannerView.swift
//  RSMS — Premium Redesign
//
//  Full-screen camera preview inside a luxury dark-theme scanner UI.
//  Architecture: MVVM via ScannerViewModel → ScanManager → ScanService (unchanged).
//
//  Layers (back to front):
//    1. Dark gradient background
//    2. BarcodeScannerView (live camera feed, full-screen)
//    3. ScanFrameView (SwiftUI vignette + corner brackets + animated scan line)
//    4. Top HUD (session status, scan type, count)
//    5. Bottom panel (status banner, scanned item card, session buttons)
//

import SwiftUI
import AVFoundation

// MARK: - ScannerView

struct ScannerView: View {

    // MARK: State

    @State private var viewModel        = ScannerViewModel()
    @State private var cameraPermission = CameraPermissionManager()
    @State private var showImagePicker  = false     // DEV TOOL
    @State private var isProcessingImage = false    // DEV TOOL
    @State private var flashOverlay     = false     // Success flash

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

            // ── 2. Camera Preview ──────────────────────────────────────────
            if cameraPermission.isAuthorized {
                BarcodeScannerView { barcode in
                    viewModel.onBarcodeDetected(barcode)
                    triggerSuccessFlash()
                }
                .ignoresSafeArea()
            } else {
                cameraPermissionView
            }

            // ── 3. Scan Frame (vignette + brackets + scan line) ────────────
            if cameraPermission.isAuthorized {
                ScanFrameView(sessionActive: viewModel.sessionActive)
            }

            // ── 4. Success Flash ───────────────────────────────────────────
            if flashOverlay {
                Color.white.opacity(0.08)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── 5. HUD + Bottom Panel ──────────────────────────────────────
            VStack(spacing: 0) {
                topHUD
                    .padding(.top, 8)

                Spacer()

                bottomPanel
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: viewModel.scanState)
        .animation(.easeInOut(duration: 0.2), value: flashOverlay)
        .task { await cameraPermission.requestIfNeeded() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in cameraPermission.refresh() }
        // DEV TOOL: image picker
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { image in
                Task { await processPickedImage(image) }
            }
        }
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        HStack(alignment: .center, spacing: 10) {
            // Back / title area
            VStack(alignment: .leading, spacing: 3) {
                Text("BARCODE SCANNER")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .tracking(2.5)
                    .foregroundStyle(Color.white.opacity(0.5))

                Text(viewModel.currentScanType.displayName.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }

            Spacer()

            // Right pills
            HStack(spacing: 8) {
                // Session status pill
                sessionPill

                // Scan count
                if viewModel.sessionActive {
                    Text("\(viewModel.totalSessionScans)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColors.accent.opacity(0.25), in: Capsule())
                }

                // Scan type menu
                scanTypeMenu
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.6))
    }

    private var sessionPill: some View {
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

    private var scanTypeMenu: some View {
        Menu {
            ForEach(ScanType.allCases, id: \.self) { type in
                Button {
                    if !viewModel.sessionActive { viewModel.currentScanType = type }
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

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            // Status banner
            statusBanner

            // Recent Scans List
            if viewModel.sessionActive && !viewModel.recentScans.isEmpty {
                RecentScansListView(viewModel: viewModel)
                    .frame(maxHeight: 200) // bounded height
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Scanned item card
            if case .found(let result) = viewModel.scanState {
                ScannedItemCard(result: result)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Session control buttons
            sessionButtons
                .padding(.horizontal, 16)

            // DEV TOOL: Photo picker button
            devPhotoButton
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        switch viewModel.scanState {
        // duplicate banner is intentionally removed/suppressed

        case .error(let msg):
            toastBanner(icon: "xmark.circle.fill", text: msg, color: Color(red: 1, green: 0.35, blue: 0.35))
            
        case .found(_) where viewModel.currentScanType == .return:
            toastBanner(icon: "checkmark.circle.fill", text: "Item marked as returned", color: .purple)

        case .idle where viewModel.sessionActive:
            toastBanner(icon: "viewfinder", text: "Point camera at a barcode", color: Color.white.opacity(0.5))

        default:
            EmptyView()
        }
    }

    private func toastBanner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 13))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Session Buttons (gradient, press animation)

    private var sessionButtons: some View {
        Group {
            if viewModel.sessionActive {
                // End Session — destructive gradient
                PressableButton(
                    label: { Label("End Session", systemImage: "stop.circle.fill") },
                    tint: Color(red: 0.85, green: 0.2, blue: 0.2),
                    action: { Task { await viewModel.endSession() } }
                )
            } else {
                // Start Session — accent gradient
                PressableButton(
                    label: {
                        if viewModel.isStartingSession {
                            HStack(spacing: 8) {
                                ProgressView().tint(.black).scaleEffect(0.8)
                                Text("Starting…")
                            }
                        } else {
                            Label("Start Session", systemImage: "barcode.viewfinder")
                        }
                    },
                    tint: AppColors.accent,
                    action: { Task { await viewModel.startSession() } },
                    disabled: viewModel.isStartingSession
                )
            }
        }
    }

    // MARK: - DEV TOOL: Photo Picker Button

    private var devPhotoButton: some View {
        Button {
            showImagePicker = true
        } label: {
            HStack(spacing: 8) {
                if isProcessingImage {
                    ProgressView().tint(AppColors.accent).scaleEffect(0.75)
                    Text("Detecting barcode…")
                } else {
                    Image(systemName: "photo.on.rectangle")
                    Text("Upload from Photos")
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.accent.opacity(0.25), lineWidth: 0.75)
            )
        }
        .disabled(isProcessingImage || !viewModel.sessionActive)
        .opacity(viewModel.sessionActive ? 1 : 0.4)
    }

    // MARK: - Camera Permission View

    private var cameraPermissionView: some View {
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

            Button("Open Settings") { cameraPermission.openSettings() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(AppColors.accent.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(AppColors.accent.opacity(0.3), lineWidth: 0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: - Helpers

    private func triggerSuccessFlash() {
        guard !flashOverlay else { return }
        withAnimation { flashOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation { flashOverlay = false }
        }
    }

    // DEV TOOL: process image from photo library
    private func processPickedImage(_ image: UIImage) async {
        guard viewModel.sessionActive else { return }
        isProcessingImage = true
        defer { isProcessingImage = false }

        do {
            let barcode = try await BarcodeImageScanner.detect(from: image)
            viewModel.onBarcodeDetected(barcode)
            triggerSuccessFlash()
        } catch {
            await MainActor.run {
                withAnimation {
                    viewModel.scanState = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - PressableButton
// Reusable gradient button with scale-down press animation

struct PressableButton<Label: View>: View {
    @ViewBuilder let label: () -> Label
    let tint: Color
    let action: () -> Void
    var disabled: Bool = false

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                )
                .shadow(color: tint.opacity(0.4), radius: pressed ? 4 : 10, y: pressed ? 2 : 5)
                .scaleEffect(pressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        ._onButtonGesture(pressing: { isPressing in
            pressed = isPressing
        }, perform: {})
    }
}

#Preview {
    NavigationStack {
        ScannerView()
    }
    .environment(AppState())
}
