//
//  BarcodeScannerView.swift
//  RSMS
//
//  UIViewRepresentable wrapper around AVCaptureSession.
//  Supports Code128 and EAN-13, continuous scanning mode.
//
//  Authorization contract:
//  This view is ONLY rendered by ScannerView when AVAuthorizationStatus == .authorized.
//  No permission logic here — that is handled entirely by CameraPermissionManager.
//  No reticle drawing — handled by ScanFrameView (SwiftUI overlay).
//

import SwiftUI
import AVFoundation
import Vision
import CoreImage

// MARK: - BarcodeScannerView

struct BarcodeScannerView: UIViewRepresentable {
    var onBarcodeDetected: (String) -> Void

    func makeUIView(context: Context) -> BarcodeCameraView {
        let view = BarcodeCameraView()
        view.onBarcodeDetected = onBarcodeDetected
        view.startSession()
        return view
    }

    func updateUIView(_ uiView: BarcodeCameraView, context: Context) {
        uiView.onBarcodeDetected = onBarcodeDetected
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {}
}

// MARK: - BarcodeCameraView (UIView)

final class BarcodeCameraView: UIView {
    var onBarcodeDetected: ((String) -> Void)?

    private let captureSession  = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let context = CIContext(options: [.workingColorSpace: NSNull()]) // Force strip color space issues
    private var lastScanTime: TimeInterval = 0
    private let scanDebounceInterval: TimeInterval = 0.5

    // MARK: - Setup

    /// Starts the capture session directly.
    /// Caller (ScannerView via CameraPermissionManager) guarantees authorization.
    func startSession() {
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Use video data output for Vision processing instead of metadata output
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.processing"))
        }

        captureSession.commitConfiguration()

        // Preview layer
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.frame           = bounds
        preview.videoGravity    = .resizeAspectFill
        layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension BarcodeCameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Debounce scans to avoid excessive processing
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastScanTime >= scanDebounceInterval else { return }
        lastScanTime = currentTime
        
        // Convert sample buffer to CIImage
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Normalize the image to prevent "Could not create inference context" error
        guard let cgImage = context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        ) else { return }
        
        // Create Vision request
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error {
                print("[BarcodeCameraView] Vision error: \(error)")
                return
            }
            
            let observations = request.results as? [VNBarcodeObservation] ?? []
            
            // Filter to supported symbologies + non-empty payloads
            let validObservations = observations.filter { obs in
                let supported: [VNBarcodeSymbology] = [
                    .code128, .ean13, .qr, .pdf417, .aztec, .code39
                ]
                return supported.contains(obs.symbology)
                    && !(obs.payloadStringValue ?? "").isEmpty
            }
            
            if let first = validObservations.first,
               let value = first.payloadStringValue {
                DispatchQueue.main.async {
                    self.onBarcodeDetected?(value)
                }
            }
        }
        
        // Perform Vision request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}
