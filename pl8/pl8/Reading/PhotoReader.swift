import Foundation
import UIKit
import PlateKit

/// Reads a workout or PR photo in stages and stops at the first that gives a result that passes the checks
/// (docs/DATA-AND-SERVICES.md §2): the text on the phone (Vision), then the rules (PlateKit), then Apple's
/// on-device model where the phone has it, then the cloud, only with the user's consent. Photos are never kept.
enum PhotoReader {
    /// Where a read ended (the analytics `photo_read` event's `stage`).
    enum Stage: String {
        case rules
        case onDeviceModel = "on_device_model"
        case cloud
        case failed
    }

    /// The board's blocks, the text they came from, and how they were read.
    struct WorkoutRead {
        let blocks: [StrengthBlock]
        let text: String
        let stage: Stage
        let milliseconds: Int
    }

    struct PRRead {
        let entries: [PREntry]
        let stage: Stage
        let milliseconds: Int
    }

    /// Below this much recognised text, the cloud gets the photo itself (§2, step 3).
    static let enoughText = 8
    /// How long each stage may take (§2.1).
    static let onDeviceSeconds = 6.0

    static func workout(_ image: UIImage, unit: WeightUnit, consent: () async -> Bool) async -> WorkoutRead {
        let start = ContinuousClock.now
        func done(_ blocks: [StrengthBlock], _ text: String, _ stage: Stage) -> WorkoutRead {
            WorkoutRead(blocks: blocks, text: text, stage: stage, milliseconds: milliseconds(since: start))
        }
        let lines = (try? await TextReader.lines(in: image)) ?? []
        let text = lines.joined(separator: "\n")
        // 1. The rules: the box app's format, then a whiteboard's. A block outside the limits is left out.
        let ruled = WorkoutParser.parse(text).filter(\.isLikely)
        if !ruled.isEmpty { return done(ruled, text, .rules) }
        // 2. Apple's on-device model, on phones that have it.
        if text.count >= enoughText, let result = await onDevice(.workout, text: text) {
            let blocks = result.strengthBlocks()
            if !blocks.isEmpty { return done(blocks, text, .onDeviceModel) }
        }
        // 3. The cloud, once the user has said yes.
        if let result = await cloud(.workout, text: text, image: image, unit: unit, consent: consent) {
            let blocks = result.strengthBlocks()
            if !blocks.isEmpty { return done(blocks, text, .cloud) }
        }
        return done([], text, .failed)
    }

    static func prs(_ image: UIImage, unit: WeightUnit, consent: () async -> Bool) async -> PRRead {
        let start = ContinuousClock.now
        func done(_ entries: [PREntry], _ stage: Stage) -> PRRead {
            PRRead(entries: entries, stage: stage, milliseconds: milliseconds(since: start))
        }
        let lines = (try? await TextReader.lines(in: image)) ?? []
        let text = lines.joined(separator: "\n")
        // 1. The rules, line by line; then with the pieces of each row joined (a box app's list).
        var entries = PRParser.parse(text).filter(\.isLikely)
        if entries.isEmpty, let rows = try? await TextReader.lines(in: image.pngData() ?? Data(), joiningRows: true) {
            entries = PRParser.parse(rows.joined(separator: "\n")).filter(\.isLikely)
        }
        if !entries.isEmpty { return done(entries, .rules) }
        // 2. and 3., as for a workout.
        if text.count >= enoughText, let result = await onDevice(.prs, text: text) {
            let read = result.prEntries()
            if !read.isEmpty { return done(read, .onDeviceModel) }
        }
        if let result = await cloud(.prs, text: text, image: image, unit: unit, consent: consent) {
            let read = result.prEntries()
            if !read.isEmpty { return done(read, .cloud) }
        }
        return done([], .failed)
    }

    // MARK: - Stages

    private static func onDevice(_ kind: ReadResult.Kind, text: String) async -> ReadResult? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceReader.isAvailable {
            let result = await withTimeout(onDeviceSeconds) { try? await OnDeviceReader.read(kind, text: text) }
            return result??.validated()
        }
        #endif
        return nil
    }

    private static func cloud(_ kind: ReadResult.Kind, text: String, image: UIImage, unit: WeightUnit,
                              consent: () async -> Bool) async -> ReadResult? {
        guard CloudReader.isAvailable, await CloudConsent.allowed(asking: consent) else { return nil }
        // The text when there is some; the photo only when the phone found almost none.
        let photo = text.count < enoughText ? image : nil
        return await CloudReader.read(kind, text: text, image: photo, unit: unit)?.validated()
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Int {
        let elapsed = ContinuousClock.now - start
        return Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
    }
}

/// `work`'s result, or nil if it takes longer than `seconds` (it's cancelled then).
func withTimeout<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await work() }
        group.addTask {
            try? await Task.sleep(for: .seconds(seconds))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
