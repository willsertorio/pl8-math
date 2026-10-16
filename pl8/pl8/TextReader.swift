import Foundation
import UIKit
import Vision

/// Reads the text in an image with Vision, on the device (SPEC Part 5).
enum TextReader {
    /// The image's text lines, top to bottom. With `joiningRows`, pieces side by side on one row become one
    /// line, left to right — for lists like a box app's PRs, where the weight sits to the right of the lift.
    static func lines(in imageData: Data, joiningRows: Bool = false) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try recognize(VNImageRequestHandler(data: imageData, options: [:]), joiningRows: joiningRows)
        }.value
    }

    /// Same, for a camera photo (keeps its orientation).
    static func lines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            try recognize(VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]), joiningRows: false)
        }.value
    }

    private nonisolated static func recognize(_ handler: VNImageRequestHandler, joiningRows: Bool) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Corrections "fix" things like 1RM and @75-78%; the parser handles the raw text better.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "pt-BR"]

        try handler.perform([request])

        if joiningRows { return rows(request.results ?? []) }
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

extension TextReader {
    /// Groups pieces whose boxes overlap vertically by at least half the shorter one into rows, top to bottom,
    /// each read left to right.
    nonisolated static func rows(_ observations: [VNRecognizedTextObservation]) -> [String] {
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations.sorted(by: { $0.boundingBox.midY > $1.boundingBox.midY }) {
            let box = observation.boundingBox
            if let last = rows.last, let anchor = last.first?.boundingBox {
                let overlap = min(box.maxY, anchor.maxY) - max(box.minY, anchor.minY)
                if overlap >= 0.5 * min(box.height, anchor.height) {
                    rows[rows.count - 1].append(observation)
                    continue
                }
            }
            rows.append([observation])
        }
        return rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
        }
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
