import Testing
@testable import PlateKit

/// The PR notebook in pages (beta, 2026-11-09): eight PRs a page; a page turns on the spine with the finger.
@Suite("PR notebook pages")
struct NotebookPagesTests {
    let rows = (1...17).map { "Lift \($0)  100 kg" }

    @Test func eightPRsAPage() {
        #expect(NotebookPages.split(Array(rows.prefix(8))).count == 1)
        #expect(NotebookPages.split(Array(rows.prefix(9))).map(\.count) == [8, 1])
        #expect(NotebookPages.split(rows).map(\.count) == [8, 8, 1])
        #expect(NotebookPages.split(rows)[1].first == "Lift 9  100 kg")
    }

    @Test func noPRsIsOneEmptyPage() {
        #expect(NotebookPages.split([]) == [[]])
    }

    @Test func thePageFollowsTheFinger() {
        // Dragging left turns forward, right turns back; half a page width is half a turn.
        #expect(NotebookPages.progress(dx: -100, pageWidth: 200, forward: true) == 0.5)
        #expect(NotebookPages.progress(dx: 100, pageWidth: 200, forward: false) == 0.5)
        #expect(NotebookPages.progress(dx: 50, pageWidth: 200, forward: true) == 0)
        #expect(NotebookPages.progress(dx: -500, pageWidth: 200, forward: true) == 1)
    }

    @Test func pastHalfwayItTurnsOtherwiseItFallsBack() {
        #expect(NotebookPages.completes(progress: 0.6, flick: 0))
        #expect(!NotebookPages.completes(progress: 0.4, flick: 0))
        // A quick flick turns it from less than halfway.
        #expect(NotebookPages.completes(progress: 0.2, flick: 1.5))
    }

    @Test func onlyPagesThatExistTurn() {
        #expect(NotebookPages.canTurn(forward: true, from: 0, pages: 3))
        #expect(!NotebookPages.canTurn(forward: true, from: 2, pages: 3))
        #expect(!NotebookPages.canTurn(forward: false, from: 0, pages: 3))
        #expect(!NotebookPages.canTurn(forward: true, from: 0, pages: 1))
    }

    @Test func theLeafHangsOnTheSpine() {
        let leaf = FlowProps.notebookLeaf()
        #expect(leaf.name == "leafHinge")
        #expect(leaf.position.x == -1.05 / 2)
        let names = leaf.children.flatMap { $0.parts.map(\.name) }
        #expect(names.contains("leafFront") && names.contains("leafBack"))
    }
}
