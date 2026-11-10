/// The PR notebook in pages (beta, 2026-11-09): a page holds eight PRs, and a page turns on the spine as the
/// finger drags across it, like a real notebook's.
public enum NotebookPages {
    public static let rowsPerPage = 8
    /// How far a turned leaf swings over the spine (the cover opens to 2.95).
    public static let turnedAngle: Float = 2.9

    /// The rows, eight to a page; no rows is one empty page.
    public static func split(_ rows: [String], perPage: Int = rowsPerPage) -> [[String]] {
        guard !rows.isEmpty else { return [[]] }
        return stride(from: 0, to: rows.count, by: perPage).map { Array(rows[$0..<min(rows.count, $0 + perPage)]) }
    }

    /// How far a turn has gone, 0…1: forward follows the finger leftwards, back rightwards; a page width is a turn.
    public static func progress(dx: Double, pageWidth: Double, forward: Bool) -> Double {
        let travel = forward ? -dx : dx
        return max(0, min(1, travel / max(1, pageWidth)))
    }

    /// Let go past halfway (or with a quick flick, in page widths a second) and the page finishes turning;
    /// otherwise it falls back.
    public static func completes(progress: Double, flick: Double) -> Bool {
        progress > 0.5 || flick > 1
    }

    public static func canTurn(forward: Bool, from page: Int, pages: Int) -> Bool {
        forward ? page + 1 < pages : page > 0
    }
}

extension FlowProps {
    /// A page that turns (the notebook's top leaf): on a hinge at the spine like the cover, its front the page
    /// being turned, its back blank paper. Hidden at rest; the app shows it while a page turns.
    public static func notebookLeaf() -> FlowNode {
        let w: Float = 1.05, h: Float = 1.4, d: Float = 0.1
        // Just above the block's top face (block at −0.01, 0.08 deep).
        var hinge = FlowNode("leafHinge", position: [-w / 2, 0, -d * 0.1 + d * 0.4 + 0.004])
        var leaf = FlowNode("leaf", position: [w / 2, 0, 0])
        for (i, face) in Geo.box(w, h, 0.004).enumerated() {
            switch i {
            case 4: leaf.parts.append(FlowPart("leafFront", mesh: face, paint: .picture(.notebookPage([]), tint: RGB(1, 1, 1)), shade: .toon))
            case 5: leaf.parts.append(FlowPart("leafBack", mesh: face, paint: .picture(.notebookBlank(edged: true), tint: RGB(1, 1, 1)), shade: .toon))
            default: leaf.parts.append(.toon("leafEdge", face, RGB(hex: "#F6F2EA")))
            }
        }
        hinge.add(leaf)
        return hinge
    }
}
