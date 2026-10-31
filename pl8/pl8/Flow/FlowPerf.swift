import Foundation
import QuartzCore

/// Where the time goes, for the CI (the screenshot runs turn it on): each second, how long frames took apart
/// (mean, 95th percentile, worst), how much of that was the Flow's own work and its re-lighting, how many models
/// it re-lit; and how long each question took to build. Written to Documents/perf.log.
@MainActor
final class FlowPerf {
    var bakes = 0
    private var intervals: [Double] = []
    private var work: [Double] = []
    private var relight = 0.0
    private var lines: [String] = []
    private let start = CACurrentMediaTime()
    private var lastFlush = CACurrentMediaTime()
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("perf.log")

    init() {
        lines.append("   t  step      frames  mean ms  p95 ms  max ms  work ms (max)  relight ms  bakes")
        write()
    }

    /// One frame: the time since the last one, the Flow's own work in it and the part of that spent re-lighting.
    func frame(interval: Double, work: Double, relight: Double, step: String) {
        intervals.append(interval * 1000)
        self.work.append(work * 1000)
        self.relight += relight * 1000
        let now = CACurrentMediaTime()
        if now - lastFlush >= 1 { flush(step: step, now: now) }
    }

    /// Something that happened once, like building a question.
    func event(_ text: String, ms: Double) {
        lines.append(String(format: "%5.1f  %@ %.1f ms", CACurrentMediaTime() - start, text, ms))
    }

    private func flush(step: String, now: Double) {
        lastFlush = now
        guard !intervals.isEmpty else { return }
        let sorted = intervals.sorted(), n = Double(intervals.count)
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        lines.append(String(format: "%5.1f  %-8@ %6d  %7.1f  %6.1f  %6.1f  %6.1f (%5.1f)  %8.1f  %5d",
                            now - start, step as NSString, intervals.count, intervals.reduce(0, +) / n, p95, sorted.last ?? 0,
                            work.reduce(0, +) / n, work.max() ?? 0, relight / n, bakes))
        intervals = []
        work = []
        relight = 0
        bakes = 0
        write()
    }

    private func write() {
        try? lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
