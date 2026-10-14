import Foundation
import UIKit
import Vision

/// Reads the text in an image with Vision, on the device (SPEC Part 5).
enum TextReader {
    /// The image's text lines, top to bottom.
    static func lines(in imageData: Data) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try recognize(VNImageRequestHandler(data: imageData, options: [:]))
        }.value
    }

    /// Same, for a camera photo (keeps its orientation).
    static func lines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            try recognize(VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]))
        }.value
    }

    private nonisolated static func recognize(_ handler: VNImageRequestHandler) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Corrections "fix" things like 1RM and @75-78%; the parser handles the raw text better.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "pt-BR"]

        try handler.perform([request])

        return (request.results ?? [])
            .sorted { a, b in
                // Vision's origin is bottom-left: higher midY means higher on screen.
                if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.005 {
                    return a.boundingBox.midY > b.boundingBox.midY
                }
                return a.boundingBox.minX < b.boundingBox.minX
            }
            .compactMap { $0.topCandidates(1).first?.string }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
