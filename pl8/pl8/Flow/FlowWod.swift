import CoreImage
import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// The whiteboard's face as a canvas you can wipe (flDrawBoard, flBoardWiper): the marker comes off wherever
/// the finger scrubs; once about 45 % of the writing area is wiped the board is clean.
@MainActor
final class FlowBoardCanvas {
    static let width = 1024, height = 662
    let context: CGContext
    let clean: UIImage
    var texture: TextureResource?
    private var cells = Set<Int>()
    private(set) var wiped = false

    init?() {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Self.width, height: Self.height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Top-left origin, like the prototype's canvas and UIKit's drawing.
        context.translateBy(x: 0, y: CGFloat(Self.height))
        context.scaleBy(x: 1, y: -1)
        self.context = context
        clean = FlowArt.whiteboard(nil)
    }

    func draw(_ lines: [FlowBoardLine]?) {
        UIGraphicsPushContext(context)
        FlowArt.drawBoard(context, lines: lines)
        UIGraphicsPopContext()
        cells = []
        wiped = false
        upload()
    }

    /// Wipes a circle round `point` (canvas pixels); true when the board has just become clean.
    func wipe(at point: CGPoint) -> Bool {
        guard !wiped else { return false }
        let r: CGFloat = 92
        context.saveGState()
        context.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: 2 * r, height: 2 * r))
        context.clip()
        UIGraphicsPushContext(context)
        clean.draw(in: CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
        UIGraphicsPopContext()
        context.restoreGState()
        if point.y > 150 {
            for ox in -1...1 {
                for oy in -1...1 {
                    let cx = Int(((point.x + CGFloat(ox) * r * 0.6) / CGFloat(Self.width) * 10).rounded(.down))
                    let cy = Int(((point.y + CGFloat(oy) * r * 0.6 - 150) / CGFloat(Self.height - 150) * 5).rounded(.down))
                    if (0..<10).contains(cx), (0..<5).contains(cy) { cells.insert(cy * 10 + cx) }
                }
            }
        }
        if cells.count >= 23 {
            wiped = true
            draw(nil)
            wiped = true
            return true
        }
        upload()
        return false
    }

    func reset() { cells = []; wiped = false }

    func upload() {
        guard let image = context.makeImage() else { return }
        if let texture {
            try? texture.replace(withImage: image, options: .init(semantic: .color))
        } else {
            texture = try? TextureResource(image: image, options: .init(semantic: .color))
        }
    }
}

extension Flow {
    /// Where the board rests (WB_REST): smaller, angled.
    static let boardScale: Float = 0.85, boardTurn: Float = -0.28
    static let boardCamera = (position: SIMD3<Float>(0, 1.9, 7.0), target: SIMD3<Float>(0, 1.1, 0))

    // MARK: - 6 · "You're strong! What are we doing today?" (flWod)

    func stepWod() {
        UserDefaults.standard.set(true, forKey: Flow.setUpKey)
        setCamera(Self.boardCamera.position, Self.boardCamera.target)
        let board = makeBoard()
        board.entity.scale = SIMD3(repeating: Self.boardScale)
        add(board.entity)
        let instant = fromKit || fromMenu
        var busy = false
        var hasPlan = data.workout != nil
        var shadow: Entity?
        let restShadow = { [weak self] in
            guard let self else { return }
            shadow?.removeFromParent()
            // The prototype's ShadowMaterial is 0.18, but its shadow comes out about twice as dark as ours at that.
            shadow = self.groundShadow(of: board.entity, opacity: 0.33)
            if let shadow { self.add(shadow) }
        }
        if instant {
            board.entity.orientation = simd_quatf(angle: Self.boardTurn, axis: [0, 1, 0])
            board.canvas?.draw(data.boardLines)
            restShadow()
        } else {
            board.canvas?.draw(data.boardLines)
            board.entity.isEnabled = false
        }
        say(again ? "What are we doing today?" : "You’re strong! What are we doing today?") { [weak self] in
            guard let self, !instant else { return }
            // Pushed in: it rolls on from the right, turning as it comes, and slows to a stop with no bounce.
            board.entity.isEnabled = true
            board.entity.position.x = 3.6
            board.entity.orientation = simd_quatf(angle: -1.9, axis: [0, 1, 0])
            self.click(0.5)
            self.anim(1.3, { u in
                let e = Float(Ease.outQuart(u)), er = Float(1 - pow(1 - min(1, u * 1.08), 3))
                board.entity.position.x = 3.6 * (1 - e)
                board.entity.orientation = simd_quatf(angle: -1.9 + (Self.boardTurn + 1.9) * er, axis: [0, 1, 0])
                for wheel in board.wheels { wheel.orientation = simd_quatf(angle: -(1 - e) * 40, axis: [1, 0, 0]) }
            }, done: { restShadow() })
        }
        let start = { [weak self] in
            guard let self else { return }
            // Back from the kit to the same board: the same session, chips as they were.
            let same = self.plan != nil && self.data.session?.endedAt == nil && self.data.session?.workout === self.data.workout
            guard let plan = same ? self.plan : self.data.startSession() else { return }
            busy = true
            self.checkSound()
            self.buzz(.light)
            if !same {
                self.plan = plan
                self.setIndex = 0
                self.doneSets = []
                self.collected = []
            }
            let p0 = self.cam.position, t0 = self.cam.target, cy = 1.45 * Self.boardScale
            let p1 = SIMD3<Float>(0.15, cy, 0.7), t1 = SIMD3<Float>(0, cy, 0)
            self.anim(1.0, { u in
                let e = Float(Ease.inOutCubic(u))
                self.cam.position = p0 + (p1 - p0) * e
                self.cam.target = t0 + (t1 - t0) * e
            }, done: { [weak self] in self?.go(.kit) })
        }
        let ready = { [weak self] in
            guard let self else { return }
            board.canvas?.draw(self.data.boardLines)
            self.shine([board.entity], duration: 0.6)
            self.sparkles(at: [0.4, 1.6, 0.4], count: 5, spread: 1.2)
            busy = false
            hasPlan = true
        }
        hit = { [weak self] point in
            guard let self, !busy, board.entity.isEnabled, self.touches(point, board.entity) else { return nil }
            var moved = false
            return FlowDrag(move: { [weak self] p in
                guard let self, hasPlan else { return }
                if !moved {
                    guard hypot(p.x - point.x, p.y - point.y) >= 10 else { return }
                    moved = true
                }
                if self.wipeBoard(board, at: p) {
                    hasPlan = false
                    self.data.wipeBoard()
                }
                if Double.random(in: 0..<1) < 0.18 { self.click(2.6); self.buzz(.selection) }
            }, up: { [weak self] _, tap in
                guard let self, tap, !busy else { return }
                if hasPlan { start(); return }
                self.buzz(.light)
                self.checkSound()
                board.canvas?.reset()
                self.pickPhoto(.workout, reading: "Reading your workout…", read: { [weak self] image in
                    await self?.data.readWorkout(image) ?? false
                }, then: { ok in if ok { ready() } })
            })
        }
    }

    /// A whiteboard whose face is a wipeable canvas.
    func makeBoard() -> (entity: Entity, canvas: FlowBoardCanvas?, face: ModelEntity?, wheels: [Entity]) {
        let entity = build(FlowProps.whiteboard(lines: nil))
        let canvas = FlowBoardCanvas()
        let face = entity.findEntity(named: "board")?.children.first { $0.name == "face" } as? ModelEntity
        if let face, let canvas {
            // The canvas owns this face's picture from now on.
            shaded.removeAll { $0.model === face }
            canvas.upload()
            if let texture = canvas.texture {
                var material = UnlitMaterial(applyPostProcessToneMap: false)
                material.color = .init(tint: .white, texture: .init(texture))
                face.model?.materials = [material]
            }
        }
        let wheels = (0..<4).compactMap { entity.findEntity(named: "wheel\($0)") }
        return (entity, canvas, face, wheels)
    }

    /// The finger on the board: where it is on the canvas, wiped; true when the board just became clean.
    func wipeBoard(_ board: (entity: Entity, canvas: FlowBoardCanvas?, face: ModelEntity?, wheels: [Entity]), at point: CGPoint) -> Bool {
        guard let canvas = board.canvas, let front = board.entity.findEntity(named: "board") else { return false }
        let r = ray(point)
        let inverse = front.transformMatrix(relativeTo: nil).inverse
        let o4 = inverse * SIMD4(r.origin, 1), d4 = inverse * SIMD4(r.direction, 0)
        guard abs(d4.z) > 1e-6 else { return false }
        let s = (0.02 - o4.z) / d4.z
        guard s > 0 else { return false }
        let x = o4.x + d4.x * s, y = o4.y + d4.y * s
        let u = x / 1.7 + 0.5, v = y / 1.1 + 0.5
        guard (0...1).contains(u), (0...1).contains(v) else { return false }
        let cleaned = canvas.wipe(at: CGPoint(x: CGFloat(u) * CGFloat(FlowBoardCanvas.width), y: CGFloat(1 - v) * CGFloat(FlowBoardCanvas.height)))
        if cleaned {
            buzz(.success)
            checkSound()
            sparkles(at: board.entity.convert(position: [0, 1.45, 0.3], to: nil), count: 5, spread: 0.9)
        }
        return cleaned
    }

    /// The sun's shadow of a still prop on the floor (the prototype's ShadowMaterial under a shadow-casting sun):
    /// every face of it flattened along the sun's rays onto y = 0, softened a little, at `opacity`.
    func groundShadow(of entity: Entity, opacity: Float, pixelsPerMetre: Float = 160) -> Entity? {
        let sun = FlowLight.sun
        var triangles: [[SIMD2<Float>]] = []
        for item in shadedModels(under: entity) where item.part.shade != .occluder {
            let matrix = item.model.transformMatrix(relativeTo: nil)
            let mesh = item.part.mesh
            for tri in 0..<mesh.triangleCount {
                let flat: [SIMD2<Float>] = (0..<3).map { c in
                    let p = mesh.positions[Int(mesh.indices[tri * 3 + c])]
                    let w = matrix * SIMD4(p, 1)
                    let q = SIMD3(w.x, w.y, w.z) - sun * (w.y / sun.y)
                    return SIMD2(q.x, q.z)
                }
                // All turned the same way: a closed shape's back faces land reversed and would cancel its front
                // faces under the winding fill (the legs cast nothing).
                let a = flat[1] - flat[0], b = flat[2] - flat[0], area = a.x * b.y - a.y * b.x
                if abs(area) > 1e-9 { triangles.append(area > 0 ? flat : Array(flat.reversed())) }
            }
        }
        guard !triangles.isEmpty else { return nil }
        let all = triangles.flatMap { $0 }
        let lo = all.reduce(SIMD2<Float>(repeating: .infinity)) { simd_min($0, $1) } - 0.1
        let hi = all.reduce(SIMD2<Float>(repeating: -.infinity)) { simd_max($0, $1) } + 0.1
        let size = hi - lo
        let width = max(4, min(1024, Int(size.x * pixelsPerMetre))), height = max(4, min(1024, Int(size.y * pixelsPerMetre)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let mask = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            let g = context.cgContext
            g.setFillColor(UIColor(white: 0, alpha: CGFloat(opacity)).cgColor)
            let path = CGMutablePath()
            for tri in triangles {
                let points = tri.map { CGPoint(x: CGFloat(($0.x - lo.x) / size.x) * CGFloat(width), y: CGFloat(($0.y - lo.y) / size.y) * CGFloat(height)) }
                path.addLines(between: points)
                path.closeSubpath()
            }
            g.addPath(path)
            g.fillPath(using: .winding)
        }
        // PCF-soft edges: a small blur.
        var image = mask.cgImage
        if let input = mask.cgImage.map({ CIImage(cgImage: $0) }),
           let blurred = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputImageKey: input, kCIInputRadiusKey: 2.0])?.outputImage {
            image = CIContext().createCGImage(blurred, from: input.extent)
        }
        guard let image, let texture = try? TextureResource(image: image, options: .init(semantic: .color)) else { return nil }
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        let plane = ModelEntity(mesh: (try? Flow.meshResource(Geo.plane(size.x, size.y), palette: false)) ?? .generatePlane(width: size.x, depth: size.y),
                                materials: [material])
        // Laid flat facing up (like softShadow): the picture's top row, the far side (smallest z), goes to −Z.
        plane.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        plane.position = [(lo.x + hi.x) / 2, 0.002, (lo.y + hi.y) / 2]
        plane.name = "groundShadow"
        return plane
    }
}
