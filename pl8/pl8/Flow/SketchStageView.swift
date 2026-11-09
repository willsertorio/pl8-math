import os
import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// An ARView like the Flow's (non-AR, transparent, the prototype's sketch pass) for scenes built elsewhere: the
/// opening's title plates and the session's scale. The prototype draws its animation layers with the same pass.
struct SketchStageView: UIViewRepresentable {
    /// The scene's entities, a camera among them.
    let entities: () -> [Entity]
    /// Handed the view once it's made (the scale casts its touches through it).
    var made: (ARView) -> Void = { _ in }

    func makeUIView(context: Context) -> SketchARView {
        let view = SketchARView(frame: CGRect(x: 0, y: 0, width: 393, height: 852), cameraMode: .nonAR, automaticallyConfigureSession: false)
        Flow.configure(view, pass: view.pass)
        // Counts the frames really drawn, so an animation can wait for the first one (the scale did all its
        // falling before the phone showed it, beta 2026-11-09).
        let post = view.renderCallbacks.postProcess, drawn = view.drawn
        view.renderCallbacks.postProcess = { context in
            post?(context)
            drawn.withLock { $0 += 1 }
        }
        let anchor = AnchorEntity(world: .zero)
        for entity in entities() { anchor.addChild(entity) }
        view.scene.addAnchor(anchor)
        made(view)
        return view
    }

    func updateUIView(_ view: SketchARView, context: Context) {}
}

/// Keeps its sketch pass told how wide the view is.
final class SketchARView: ARView {
    let pass = SketchPass()
    /// Frames drawn so far (the render callback can come off the main thread).
    let drawn = OSAllocatedUnfairLock(initialState: 0)

    override func layoutSubviews() {
        super.layoutSubviews()
        pass.pointsWide = Float(max(1, bounds.width))
    }
}
