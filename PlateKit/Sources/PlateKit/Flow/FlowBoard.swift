import Foundation

/// What the whiteboard shows (Will, 2026-11-10): three lifts at most, then "…" when the workout has more; the rest
/// are in the session, set by set.
public enum FlowBoard {
    public static let maxLines = 3

    public static func shown(_ lines: [FlowBoardLine]) -> (lines: [FlowBoardLine], more: Bool) {
        (Array(lines.prefix(maxLines)), lines.count > maxLines)
    }

    /// The % a lift's line shows: a climb of single %s as its range ("60–80%"), otherwise the first set's.
    public static func percentText(_ targets: [Target]) -> String {
        guard let first = targets.first else { return "" }
        if targets.count > 1, targets.allSatisfy({ !$0.isFixed && !$0.plus && $0.high == nil }),
           let low = targets.map(\.low).min(), let high = targets.map(\.low).max(), high > low,
           targets.map(\.low) == targets.map(\.low).sorted() {
            return Target.range(low, high).text
        }
        return first.text
    }
}

/// Two PRs for one lift (an iCloud copy, two spellings): which one to keep.
public enum PRMerge {
    /// The one with a value, the newest among those; without any value, the newest.
    public static func keeper(of records: [(value: Double?, updated: Date)]) -> Int? {
        let withValue = records.indices.filter { records[$0].value != nil }
        let pool = withValue.isEmpty ? Array(records.indices) : withValue
        return pool.max { records[$0].updated < records[$1].updated }
    }
}

extension NotebookPages {
    /// The PR page's rows in alphabetical order, ignoring case.
    public static func ordered(_ rows: [String]) -> [String] {
        rows.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
