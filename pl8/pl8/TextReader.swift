import Foundation
import Vision

/// Reads the text in an image with Vision, on the device (SPEC Part 5).
enum TextReader {
    /// The image's text lines, top to bottom.
    static func lines(in imageData: Data) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Corrections "fix" things like 1RM and @75-78%; the parser handles the raw text better.
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US", "pt-BR"]

            try VNImageRequestHandler(data: imageData, options: [:]).perform([request])

            return (request.results ?? [])
                .sorted { a, b in
                    // Vision's origin is bottom-left: higher midY means higher on screen.
                    if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.005 {
                        return a.boundingBox.midY > b.boundingBox.midY
                    }
                    return a.boundingBox.minX < b.boundingBox.minX
                }
                .compactMap { $0.topCandidates(1).first?.string }
        }.value
    }
}
