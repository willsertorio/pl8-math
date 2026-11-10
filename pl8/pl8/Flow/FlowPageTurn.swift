import RealityKit
import UIKit
import PlateKit

/// The PR notebook's top page as it folds (Will, 2026-11-10): a dog-ear at the top right when there's another page,
/// and a turn that peels from that corner (`PageFold`). Three pieces: the part that stays flat, and the part that
/// lifts, front and back. The lifting part carries the page's dark edge, so the notebook's border folds with it;
/// the sketch pass outlines it wherever it stands out against the red.
@MainActor
final class FlowPageTurn {
    let entity = Entity()
    let fold = PageFold(width: 1.05, height: 1.4)
    private let flat = ModelEntity(), flapFront = ModelEntity(), flapBack = ModelEntity()
    private weak var flow: Flow?
    private var rows: [String] = []
    private(set) var t: Float = PageFold.dogEar
    private var angle: Float?

    init(flow: Flow) {
        self.flow = flow
        // On the page block (its top at 0.03 in the notebook's space), under the closed cover.
        entity.position = [0, 0, 0.032]
        for model in [flat, flapFront, flapBack] { entity.addChild(model) }
    }

    /// Which page it shows.
    func show(_ rows: [String]) {
        self.rows = rows
        guard let flow else { return }
        paint(flat, flow.texture(.notebookPage(rows)))
        paint(flapFront, flow.texture(.notebookPage(rows, edged: true)))
        paint(flapBack, flow.texture(.notebookBlank(edged: true)))
        update()
    }

    /// Where the fold is (0 … 1, `PageFold.dogEar` at rest), and how far the lifted part has turned (nil: the
    /// fold's own angle; the dog-ear lies flatter while the notebook closes).
    func set(_ t: Float, angle: Float? = nil) {
        self.t = t
        self.angle = angle
        update()
    }

    private func update() {
        let parts = fold.parts(at: t)
        let theta = angle ?? fold.angle(at: t)
        func place(_ p: SIMD2<Float>, lift: Float) -> SIMD3<Float> { fold.place(p, at: t, lift: lift, angle: theta) }
        let w = fold.width, h = fold.height
        func uv(_ p: SIMD2<Float>, mirrored: Bool = false) -> SIMD2<Float> {
            let u = (p.x + w / 2) / w
            return [mirrored ? 1 - u : u, (p.y + h / 2) / h]
        }
        build(flat, parts.flat.map { SIMD3($0.x, $0.y, 0) }, parts.flat.map { uv($0) }, reversed: false)
        build(flapFront, parts.flap.map { place($0, lift: 0.0015) }, parts.flap.map { uv($0) }, reversed: false)
        build(flapBack, parts.flap.map { place($0, lift: 0) }, parts.flap.map { uv($0, mirrored: true) }, reversed: true)
        // Lit where each part faces, like the other pages (toon).
        let world = entity.orientation(relativeTo: nil)
        let n = fold.flapNormal(at: t, angle: theta)
        tint(flat, world.act([0, 0, 1]))
        tint(flapFront, world.act(n))
        // The back a shade darker than the page, so the fold reads against it.
        tint(flapBack, world.act(-n), shade: 0.86)
    }

    /// A convex polygon as a fan of triangles; nothing when it's empty.
    private func build(_ model: ModelEntity, _ points: [SIMD3<Float>], _ uvs: [SIMD2<Float>], reversed: Bool) {
        guard points.count >= 3 else { model.isEnabled = false; return }
        var indices: [UInt32] = []
        for i in 1..<(points.count - 1) {
            indices += reversed ? [0, UInt32(i + 1), UInt32(i)] : [0, UInt32(i), UInt32(i + 1)]
        }
        let mesh = LowPolyMesh(positions: points, indices: indices, uvs: uvs)
        guard let resource = try? Flow.meshResource(mesh, palette: false) else { model.isEnabled = false; return }
        if model.model == nil {
            model.model = ModelComponent(mesh: resource, materials: [UnlitMaterial(applyPostProcessToneMap: false)])
        } else {
            model.model?.mesh = resource
        }
        model.isEnabled = true
    }

    private var textures: [ObjectIdentifier: TextureResource] = [:]

    private func paint(_ model: ModelEntity, _ texture: TextureResource?) {
        textures[ObjectIdentifier(model)] = texture
    }

    private func tint(_ model: ModelEntity, _ normal: SIMD3<Float>, shade: Float = 1) {
        guard model.isEnabled, let texture = textures[ObjectIdentifier(model)] else { return }
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: FlowLight.toon(RGB(shade, shade, shade), normal: normal).uiColor, texture: .init(texture))
        model.model?.materials = [material]
    }
}
