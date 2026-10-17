import SwiftUI
import UIKit
import VisionKit

/// Camera with live text highlighting (VisionKit). Capture takes a photo for Vision to read.
struct WhiteboardScanner: View {
    var onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scanner: DataScannerViewController?
    @State private var shutterCount = 0
    @State private var isCapturing = false

    /// The camera needs a supported device and the user's permission.
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScannerView(scanner: $scanner)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bigBlack)
                    .frame(width: 120)
                Button(isCapturing ? "Reading…" : "Capture") { capture() }
                    .buttonStyle(.bigBlack)
                    .disabled(scanner == nil || isCapturing)
            }
            .padding(16)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterCount)
    }

    private func capture() {
        guard let scanner else { return }
        shutterCount += 1
        isCapturing = true
        Task {
            defer { isCapturing = false }
            if let image = try? await scanner.capturePhoto() {
                onCapture(image)
                dismiss()
            }
        }
    }
}

private struct ScannerView: UIViewControllerRepresentable {
    @Binding var scanner: DataScannerViewController?

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        // Start once it's on screen, and don't change SwiftUI state while views are being made.
        DispatchQueue.main.async {
            try? controller.startScanning()
            scanner = controller
        }
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: ()) {
        controller.stopScanning()
    }
}
