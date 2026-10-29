import Foundation

/// A piece of a Flow prop: its shape, what it's painted with and how the light treats it.
public struct FlowPart: Sendable {
    public enum Shade: Hashable, Sendable {
        /// The prototype's MeshToonMaterial: three steps of sun over the hemisphere.
        case toon
        /// MeshStandardMaterial: plates and bars.
        case standard(roughness: Float, metalness: Float)
        /// MeshBasicMaterial: exactly its colour (labels, the board's face, ink).
        case flat
        /// Depth only, never seen: hides what's behind it (the scale's hole in the floor).
        case occluder
    }

    public enum Paint: Hashable, Sendable {
        case colour(RGB)
        /// A picture the app draws, multiplied by the light (and by `tint`).
        case picture(FlowPicture, tint: RGB)
    }

    public var name: String
    public var mesh: LowPolyMesh
    public var paint: Paint
    public var shade: Shade
    public var opacity: Float
    /// Seen from both sides (the flag).
    public var twoSided: Bool

    public init(_ name: String = "", mesh: LowPolyMesh, paint: Paint, shade: Shade, opacity: Float = 1, twoSided: Bool = false) {
        self.name = name
        self.mesh = mesh
        self.paint = paint
        self.shade = shade
        self.opacity = opacity
        self.twoSided = twoSided
    }

    public static func toon(_ name: String = "", _ mesh: LowPolyMesh, _ colour: RGB) -> FlowPart {
        FlowPart(name, mesh: mesh, paint: .colour(colour), shade: .toon)
    }

    public static func flat(_ name: String = "", _ mesh: LowPolyMesh, _ colour: RGB) -> FlowPart {
        FlowPart(name, mesh: mesh, paint: .colour(colour), shade: .flat)
    }
}

/// Pictures on the props. The app draws them (CoreGraphics), like the prototype's canvases.
public enum FlowPicture: Hashable, Sendable {
    /// textTex: centred text in Space Grotesk, transparent around it. Sizes in the canvas's pixels.
    case text(String, width: Int, height: Int, size: Int, colour: RGB, dy: Int)
    case plateFace(Plate)
    /// The whiteboard: light with a fine grid, "Today's sesh", then the workout (nil: clean).
    case whiteboard([FlowBoardLine]?)
    case notebookCover(String)
    /// The PR page: ruled, "PRs", one row per PR.
    case notebookPage([String])
    /// The gym box's front: its name in Space Grotesk on light.
    case gymFront(String)
    /// The gym's flag: its name in light on dark.
    case flag(String)
    /// softShadow: a soft round shadow.
    case shadowBlob
    /// flSparkles' star.
    case star
}

/// A lift on the whiteboard (flDrawBoard): "A. BACK SQUAT", "5 × 5 @ 75%", "→ 100 kg".
public struct FlowBoardLine: Hashable, Sendable {
    public let title: String
    public let format: String
    public let load: String

    public init(title: String, format: String, load: String) {
        self.title = title
        self.format = format
        self.load = load
    }
}

/// A prop as the prototype builds it: a three.js Group tree. Rotation is Euler XYZ in radians (three.js order).
public struct FlowNode: Sendable {
    public var name: String
    public var position: SIMD3<Float>
    public var rotation: SIMD3<Float>
    public var scale: SIMD3<Float>
    public var parts: [FlowPart]
    public var children: [FlowNode]
    /// An invisible box that only catches taps (the prototype's hit boxes): its size.
    public var hitBox: SIMD3<Float>?

    public init(_ name: String = "", position: SIMD3<Float> = .zero, rotation: SIMD3<Float> = .zero, scale: SIMD3<Float> = [1, 1, 1],
                parts: [FlowPart] = [], children: [FlowNode] = [], hitBox: SIMD3<Float>? = nil) {
        self.name = name
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.parts = parts
        self.children = children
        self.hitBox = hitBox
    }

    /// One part placed by its own transform (the prototype's `mesh.position / rotation`).
    public static func part(_ part: FlowPart, at position: SIMD3<Float> = .zero, rotation: SIMD3<Float> = .zero) -> FlowNode {
        FlowNode(part.name, position: position, rotation: rotation, parts: [part])
    }

    public mutating func add(_ child: FlowNode) { children.append(child) }

    public mutating func add(_ part: FlowPart, at position: SIMD3<Float> = .zero, rotation: SIMD3<Float> = .zero) {
        children.append(.part(part, at: position, rotation: rotation))
    }

    // MARK: - Looking things up

    public func find(_ name: String) -> FlowNode? {
        if self.name == name { return self }
        for child in children { if let found = child.find(name) { return found } }
        return nil
    }

    public func findPart(_ name: String) -> FlowPart? {
        if let part = parts.first(where: { $0.name == name }) { return part }
        for child in children { if let found = child.findPart(name) { return found } }
        return nil
    }

    public func findAll(_ match: (FlowNode) -> Bool) -> [FlowNode] {
        (match(self) ? [self] : []) + children.flatMap { $0.findAll(match) }
    }

    // MARK: - Transforms (without simd, so it runs on Linux too)

    /// Point in this node's space → its parent's.
    public func apply(_ p: SIMD3<Float>) -> SIMD3<Float> {
        FlowNode.rotate(p * scale, by: rotation) + position
    }

    /// Euler XYZ like three.js: R = Rx · Ry · Rz, so Z turns first.
    public static func rotate(_ p: SIMD3<Float>, by e: SIMD3<Float>) -> SIMD3<Float> {
        var v = p
        if e.z != 0 { let s = sine(e.z), c = cosine(e.z); v = [v.x * c - v.y * s, v.x * s + v.y * c, v.z] }
        if e.y != 0 { let s = sine(e.y), c = cosine(e.y); v = [v.x * c + v.z * s, v.y, -v.x * s + v.z * c] }
        if e.x != 0 { let s = sine(e.x), c = cosine(e.x); v = [v.x, v.y * c - v.z * s, v.y * s + v.z * c] }
        return v
    }

    /// The box around every part (not hit boxes), in this node's parent space.
    public func bounds() -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        func visit(_ node: FlowNode, _ toRoot: @escaping (SIMD3<Float>) -> SIMD3<Float>) {
            let here: (SIMD3<Float>) -> SIMD3<Float> = { toRoot(node.apply($0)) }
            for part in node.parts where part.shade != .occluder {
                for p in part.mesh.positions {
                    let q = here(p)
                    lo = SIMD3(Swift.min(lo.x, q.x), Swift.min(lo.y, q.y), Swift.min(lo.z, q.z))
                    hi = SIMD3(Swift.max(hi.x, q.x), Swift.max(hi.y, q.y), Swift.max(hi.z, q.z))
                }
            }
            for child in node.children { visit(child, here) }
        }
        visit(self, { $0 })
        return (lo, hi)
    }
}
