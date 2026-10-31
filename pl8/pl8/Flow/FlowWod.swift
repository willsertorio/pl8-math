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

    /// Clean, with question marks: the screenshot couldn't be read.
    func drawUnread() {
        UIGraphicsPushContext(context)
        FlowArt.drawUnreadBoard(context)
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
        if mode == .firstRun, !UserDefaults.standard.bool(forKey: Flow.setUpKey) {
            Analytics.send(.onboardingCompleted(seconds: Int(Date.now.timeIntervalSince(onboardingStart ?? .now))))
        }
        UserDefaults.standard.set(true, forKey: Flow.setUpKey)
        setCamera(Self.boardCamera.position, Self.boardCamera.target)
        let board = makeBoard()
        board.entity.scale = SIMD3(repeating: Self.boardScale)
        add(board.entity)
        let instant = fromKit || fromMenu
        var busy = false
        var hasPlan = data.workout != nil
        if instant {
            board.entity.orientation = simd_quatf(angle: Self.boardTurn, axis: [0, 1, 0])
            board.canvas?.draw(data.boardLines)
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
            })
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
                }, then: { ok in if ok { ready() } else { board.canvas?.drawUnread() } })
            })
        }
    }

    /// A whiteboard whose face is a wipeable canvas.
    /// - Parameter shadow: its own soft blob (the menu gives its items theirs).
    func makeBoard(shadow: Bool = true) -> (entity: Entity, canvas: FlowBoardCanvas?, face: ModelEntity?, wheels: [Entity]) {
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
        // v2: the menu's soft blob under it, in its own units so it rolls in and turns with it (flBoardShadow).
        if shadow {
            let blob = softShadow(0.7 / 0.62)
            blob.scale = [1, 0.6, 1]
            blob.position.y = 0.004
            entity.addChild(blob)
        }
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
}
