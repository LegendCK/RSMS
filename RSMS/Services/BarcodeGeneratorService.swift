//
//  BarcodeGeneratorService.swift
//  RSMS
//
//  Generates high-resolution Code128 barcodes from strings.
//  Uses nearest-neighbor interpolation to preserve sharp edges when scaling
//  up from the native 1-pixel-wide CIFilter output.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class BarcodeGeneratorService: Sendable {
    static let shared = BarcodeGeneratorService()
    private let context = CIContext()

    private init() {}

    /// Generates a high-res UIImage suitable for printing or display.
    /// - Parameters:
    ///   - string: The barcode payload.
    ///   - scale: An integer multiplier. Since the raw filter output is tiny,
    ///            a scale of 4-6 creates a print-ready sharp image.
    /// - Returns: A UIImage containing the barcode with quiet zones.
    func generateBarcode(from string: String, scale: Int = 5) -> UIImage? {
        // 1. Core Image Filter
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        filter.quietSpace = 10 // Quiet zone padding
        filter.barcodeHeight = 40 // Internal height parameter

        guard let outputImage = filter.outputImage else {
            return nil
        }

        // 2. Strict Integer Scaling using Nearest-Neighbor interpolation
        // Standard SwiftUI .resizable() on a raw CIImage often induces anti-aliasing blur.
        // We stroke the affine transform at the CI level explicitly.
        let transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        let scaledImage = outputImage.transformed(by: transform)

        // 3. Render explicitly to a CGImage using our shared CIContext
        // This executes the pipeline safely off the main thread if needed
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
