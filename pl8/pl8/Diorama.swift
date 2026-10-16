import RealityKit
import SwiftUI
import UIKit
import CoreText
import PlateKit

/// Turns PlateKit's baked diorama (`SceneBake`) into RealityKit models. Every piece is an `UnlitMaterial` with
/// tone mapping off, so the phone shows exactly the colours PlateKit worked out from the prototype's light.
@MainActor
enum Diorama {
    static let background = uiColor(Look.background)

    static func uiColor(_ colour: RGB) -> UIColor {
        UIColor(red: CGFloat(colour.r), green: CGFloat(colour.g), blue: CGFloat(colour.b), alpha: 1)
    }

    /// A flat colour that keeps its exact value: RealityKit's tone mapping (which darkened the orange in M5) is off.
    static func flat(_ colour: UIColor) -> UnlitMaterial {
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: colour)
        return material
    }

    /// One model per baked piece. Each is named after the walls it shows with ("walls:back,right"), so
    /// `showWalls(from:in:)` can cut away the walls between the camera and the room.
    static func entities(for pieces: [BakedPiece]) -> [Entity] {
        var textures: [Picture: TextureResource] = [:]
        return pieces.compactMap { piece in
            let material: UnlitMaterial
            switch piece.paint {
            case .colour(let colour):
                material = flat(uiColor(colour))
            case .picture(let picture, let tint):
                if textures[picture] == nil, let image = PictureArt.image(picture).cgImage {
                    textures[picture] = try? TextureResource.generate(from: image, options: .init(semantic: .color))
                }
                var m = UnlitMaterial(applyPostProcessToneMap: false)
                if let texture = textures[picture] {
                    m.color = .init(tint: uiColor(tint), texture: .init(texture))
                } else {
                    m.color = .init(tint: uiColor(tint))
                }
                material = m
            }
            guard let model = try? ModelEntity(mesh: meshResource(piece.mesh), materials: [material]) else { return nil }
            model.name = "walls:" + piece.walls.map(\.rawValue).sorted().joined(separator: ",")
            return model
        }
    }

    /// Hides every piece whose wall is between the camera (in room space) and the room, like the prototype's
    /// cut-away.
    static func showWalls(from camera: SIMD3<Float>, in world: Entity) {
        for child in world.children where child.name.hasPrefix("walls:") {
            let names = child.name.dropFirst("walls:".count).split(separator: ",")
            child.isEnabled = names.allSatisfy { RoomLayout.Wall(rawValue: String($0))?.isVisible(from: camera) ?? true }
        }
    }

    static func meshResource(_ mesh: LowPolyMesh) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: "part")
        descriptor.positions = MeshBuffers.Positions(mesh.positions)
        var normals = Array(repeating: SIMD3<Float>(0, 1, 0), count: mesh.positions.count)
        for triangle in 0..<mesh.triangleCount {
            let normal = mesh.faceNormal(triangle)
            for corner in 0..<3 { normals[Int(mesh.indices[triangle * 3 + corner])] = normal }
        }
        descriptor.normals = MeshBuffers.Normals(normals)
        if mesh.uvs.count == mesh.positions.count {
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(mesh.uvs)
        }
        descriptor.primitives = .triangles(mesh.indices)
        return try MeshResource.generate(from: [descriptor])
    }

    /// The room's transform that puts the camera at `position` looking at `target`, for a camera fixed at the
    /// origin looking down −Z. Moving the world instead of the camera works whether or not RealityView uses our
    /// camera entity.
    static func worldTransform(target: SIMD3<Float>, position: SIMD3<Float>) -> Transform {
        let eye = Entity()
        eye.look(at: target, from: position, relativeTo: nil)
        return Transform(matrix: eye.transform.matrix.inverse)
    }
}

/// The printed surfaces, drawn like the prototype's canvases (reference/prototype-app-logic.js faceTexture,
/// buildPRWall, drawFlag) and recoloured to the palette the same way: its black becomes box dark, its white box
/// light.
@MainActor
enum PictureArt {
    static func image(_ picture: Picture) -> UIImage {
        switch picture {
        case .plateFace(let plate): plateFace(plate)
        case .prTable: prTable()
        case .flag(let text): flag(text)
        }
    }

    /// A plate's face: a darker band at the edge, two fine rings, the number at the top and the unit at the
    /// bottom; bumpers also say COMPETITION and Ø 450 MM down the sides.
    static func plateFace(_ plate: Plate) -> UIImage {
        let size: CGFloat = 512, c = size / 2, r = size / 2
        let base = RGB(hex: plate.colorHex)
        let bumper = plate.kind == .bumper
        let label = plate.size.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(plate.size)) : String(plate.size)
        let unit = plate.unit == .kg ? "KG" : "LB"
        // Dark print on the light plates (yellow, white), white on the rest — the prototype's `ink`.
        let lightPlate = ["#F3C318", "#F2F2EE"].contains(plate.colorHex.uppercased())
        let ink = lightPlate ? UIColor(Color(hex: "#1A1A1A")) : UIColor.white
        return draw(CGSize(width: size, height: size)) { g in
            g.setFillColor(Diorama.uiColor(base).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: size, height: size))
            g.setStrokeColor(Diorama.uiColor(base.offsetLightness(-0.08)).cgColor)
            g.setLineWidth(14)
            g.strokeEllipse(in: circle(c, r * 0.955))
            g.setStrokeColor(Diorama.uiColor(base.offsetLightness(-0.14)).withAlphaComponent(0.55).cgColor)
            g.setLineWidth(3)
            g.strokeEllipse(in: circle(c, r * 0.905))
            g.strokeEllipse(in: circle(c, r * (bumper ? 0.40 : 0.52)))
            if bumper {
                text(label, size: 104, weight: .bold, colour: ink, at: CGPoint(x: c, y: c - r * 0.66), in: g)
                text(unit, size: 60, weight: .bold, colour: ink, at: CGPoint(x: c, y: c + r * 0.66), in: g)
                text("COMPETITION", size: 26, weight: .semibold, colour: ink, at: CGPoint(x: c - r * 0.66, y: c), angle: -.pi / 2, in: g)
                text("Ø 450 MM", size: 26, weight: .semibold, colour: ink, at: CGPoint(x: c + r * 0.66, y: c), angle: .pi / 2, in: g)
            } else {
                text(label, size: 118, weight: .bold, colour: ink, at: CGPoint(x: c, y: c - r * 0.73), in: g)
                text(unit, size: 70, weight: .bold, colour: ink, at: CGPoint(x: c, y: c + r * 0.75), in: g)
            }
        }
    }

    /// The PR board's empty table: "My PR's", a heavy rule, 8 ruled rows and 4 column lines.
    static func prTable() -> UIImage {
        let dark = Diorama.uiColor(Look.boxDark), light = Diorama.uiColor(Look.boxLight)
        return draw(CGSize(width: 1024, height: 680)) { g in
            g.setFillColor(light.cgColor)
            g.fill(CGRect(x: 0, y: 0, width: 1024, height: 680))
            text("My PR's", size: 58, weight: .bold, colour: dark, at: CGPoint(x: 40, y: 62), centred: false, in: g)
            g.setFillColor(dark.cgColor)
            g.fill(CGRect(x: 30, y: 164, width: 964, height: 6))
            g.setStrokeColor(dark.cgColor)
            g.setLineWidth(2)
            for row in 0..<8 {
                let y = CGFloat(224 + row * 60)
                g.strokeLineSegments(between: [CGPoint(x: 30, y: y), CGPoint(x: 994, y: y)])
            }
            for x: CGFloat in [330, 500, 640, 820] {
                g.strokeLineSegments(between: [CGPoint(x: x - 18, y: 112), CGPoint(x: x - 18, y: 644)])
            }
        }
    }

    /// The flag: the gym's name, as big as fits two-thirds of the width and 60 % of the height, in light on the
    /// dark cloth, in the prototype's Playfair Display Black.
    static func flag(_ name: String) -> UIImage {
        let size = CGSize(width: 740, height: 512)
        let dark = Diorama.uiColor(Look.boxDark), light = Diorama.uiColor(Look.boxLight)
        return draw(size) { g in
            g.setFillColor(dark.cgColor)
            g.fill(CGRect(origin: .zero, size: size))
            guard !name.isEmpty else { return }
            // Sized and centred on the letters' own outlines, like the prototype's measureText, so digits
            // (no descenders) sit in the middle rather than on a line box that leaves room below them.
            let probe = glyphBounds(name, font: flagFont(300))
            let points = 300 * min(size.width * 0.66 / max(1, probe.width), size.height * 0.6 / max(1, probe.height))
            let font = flagFont(points)
            let glyphs = glyphBounds(name, font: font)
            let attributed = NSAttributedString(string: name, attributes: [.font: font, .foregroundColor: light])
            // `draw(at:)` takes the line's top-left; the baseline sits `ascender` below it.
            let baseline = size.height / 2 + glyphs.height / 2 + glyphs.minY
            attributed.draw(at: CGPoint(x: size.width / 2 - glyphs.midX, y: baseline - font.ascender))
        }
    }

    /// Playfair Display Black (SIL Open Font License, Fonts/PlayfairDisplay-OFL.txt), loaded from the app on first
    /// use; the system's heaviest serif if it's missing.
    /// The letters' outline box, from the baseline (y up, as Core Text measures it).
    static func glyphBounds(_ string: String, font: UIFont) -> CGRect {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: font]))
        return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    }

    static func flagFont(_ size: CGFloat) -> UIFont {
        _ = registerPlayfair
        if let playfair = UIFont(name: "PlayfairDisplayRoman-Black", size: size) { return playfair }
        let font = UIFont.systemFont(ofSize: size, weight: .black)
        guard let serif = font.fontDescriptor.withDesign(.serif) else { return font }
        return UIFont(descriptor: serif, size: size)
    }

    private static let registerPlayfair: Void = {
        if let url = Bundle.main.url(forResource: "PlayfairDisplay-Black", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    // MARK: - Drawing helpers

    private static func draw(_ size: CGSize, _ body: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { body($0.cgContext) }
    }

    private static func circle(_ centre: CGFloat, _ radius: CGFloat) -> CGRect {
        CGRect(x: centre - radius, y: centre - radius, width: radius * 2, height: radius * 2)
    }

    private static func text(_ string: String, size: CGFloat, weight: UIFont.Weight, colour: UIColor, at point: CGPoint,
                             angle: CGFloat = 0, centred: Bool = true, in g: CGContext) {
        let font = UIFont(name: "Helvetica-Bold", size: size) ?? .systemFont(ofSize: size, weight: weight)
        text(string, font: weight == .semibold ? (UIFont(name: "Helvetica", size: size) ?? font) : font,
             colour: colour, at: point, angle: angle, centred: centred, in: g)
    }

    /// Draws `string` with its centre (or, when not `centred`, its left edge's middle) at `point`, turned by `angle`.
    private static func text(_ string: String, font: UIFont, colour: UIColor, at point: CGPoint, angle: CGFloat = 0,
                             centred: Bool = true, in g: CGContext) {
        let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: colour])
        let bounds = attributed.size()
        g.saveGState()
        g.translateBy(x: point.x, y: point.y)
        g.rotate(by: angle)
        attributed.draw(at: CGPoint(x: centred ? -bounds.width / 2 : 0, y: -bounds.height / 2))
        g.restoreGState()
    }
}
