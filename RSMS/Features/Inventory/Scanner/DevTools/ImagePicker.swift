//
//  ImagePicker.swift
//  RSMS — DEV TOOL (remove before shipping)
//
//  PHPickerViewController wrapped as a UIViewControllerRepresentable.
//  Used to select a single photo from the library for barcode detection
//  in the simulator (which has no camera).
//
//  Integration: present this sheet, receive a UIImage in the callback,
//  then pass it to BarcodeImageScanner.detectBarcode(_:).
//

import SwiftUI
import PhotosUI

// MARK: - ImagePicker

/// Wraps PHPickerViewController for single-image selection.
/// DEV TOOL: isolated here so it's easy to delete later.
struct ImagePicker: UIViewControllerRepresentable {
    var onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter         = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImageSelected: onImageSelected) }

    // MARK: Coordinator

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImageSelected: (UIImage) -> Void

        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }

            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self?.onImageSelected(image)
                }
            }
        }
    }
}
