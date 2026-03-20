//
//  BarcodeImageScanner.swift
//  RSMS — DEV TOOL (remove before shipping)
//
//  Detects barcodes from a UIImage using Apple's Vision framework.
//  Supports: Code128, EAN-13, QR, PDF417, Aztec.
//
//  Usage:
//    let barcode = try await BarcodeImageScanner.detect(from: image)
//    viewModel.onBarcodeDetected(barcode)
//

import UIKit
import Vision

// MARK: - BarcodeImageScanner

/// Vision-based barcode detector for still images.
/// DEV TOOL: isolated so it's trivial to delete later.
enum BarcodeImageScanner {

    // MARK: - Errors

    enum ScanError: LocalizedError {
        case noBarcodeFound
        case cgImageConversionFailed

        var errorDescription: String? {
            switch self {
            case .noBarcodeFound:          return "No barcode found in image."
            case .cgImageConversionFailed: return "Could not read image data."
            }
        }
    }

    // MARK: - Detection

    static func detect(from image: UIImage) async throws -> String {
        guard let normalizedImage = image.normalizedForVision(),
              let cgImage = normalizedImage.cgImage else {
            throw ScanError.cgImageConversionFailed
        }

        #if targetEnvironment(simulator)
        // Vision barcode detector ML model is not available in any simulator.
        // CIDetector is CPU-based and works, but supports QR codes only.
        // For Code128/other symbologies, test on a real device.
        let ciImage = CIImage(cgImage: cgImage)
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        if let value = features?.first?.messageString, !value.isEmpty {
            return value
        }
        throw ScanError.noBarcodeFound

        #else
        // Real device — use modern Vision API (iOS 18+) or legacy fallback
        if #available(iOS 18.0, *) {
            var request = DetectBarcodesRequest()
            request.symbologies = [.code128, .ean13, .qr, .pdf417, .aztec, .code39]

            let observations = try await request.perform(
                on: cgImage,
                orientation: normalizedImage.cgImageOrientation
            )

            guard let first = observations.first,
                  let value = first.payloadString,
                  !value.isEmpty else {
                throw ScanError.noBarcodeFound
            }
            return value

        } else {
            // iOS 17 fallback
            return try await withCheckedThrowingContinuation { continuation in
                var didResume = false

                let request = VNDetectBarcodesRequest { request, error in
                    guard !didResume else { return }
                    didResume = true

                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = request.results as? [VNBarcodeObservation] ?? []
                    let valid = observations.filter { obs in
                        let supported: [VNBarcodeSymbology] = [
                            .code128, .ean13, .qr, .pdf417, .aztec, .code39
                        ]
                        return supported.contains(obs.symbology)
                            && !(obs.payloadStringValue ?? "").isEmpty
                    }

                    if let first = valid.first, let value = first.payloadStringValue {
                        continuation.resume(returning: value)
                    } else {
                        continuation.resume(throwing: ScanError.noBarcodeFound)
                    }
                }
                request.usesCPUOnly = true

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: normalizedImage.cgImageOrientation,
                    options: [:]
                )
                do {
                    try handler.perform([request])
                } catch {
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        #endif
    }
}

// MARK: - UIImage Helpers

private extension UIImage {
    /// Converts UIImageOrientation to CGImagePropertyOrientation for Vision.
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }

    /// Redraws into a standard sRGB bitmap with quiet zone padding.
    /// Padding is required — Vision needs white margin to locate barcode edges.
    func normalizedForVision() -> UIImage? {
        let size = self.size
        guard size.width > 0, size.height > 0 else { return self }

        let padding: CGFloat = 40
        let paddedSize = CGSize(width: size.width + padding * 2,
                                height: size.height + padding * 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: paddedSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: paddedSize))
            self.draw(in: CGRect(x: padding, y: padding,
                                 width: size.width, height: size.height))
        }
    }
}
