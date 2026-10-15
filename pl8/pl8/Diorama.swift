import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// Shared pieces for the 3D box (SPEC 2.1, 2.5): palette, materials, and outlined parts built from
/// PlateKit's low-poly meshes with the sketch outline chosen in M5 (DECISIONS 2026-10-15).
@MainActor
enum Diorama {
    // Palette (reference/scene-layout-and-look.json)
    static let ink = UIColor(Color(hex: "#6C3713"))         // boxDark: the hand-drawn line
    static let boxLight = UIColor(Color(hex: "#F0E2F3"))
    static let background = UIColor(Color(hex: "#FF6200"))
    static let paper = UIColor(Color(hex: "#FFFFFF"))
    static let wood = UIColor(Color(hex: "#C89B6D"))
    static let steel = UIColor(Color(hex: "#B9BEC6"))
    static let rubber = UIColor(Color(hex: "#2B2B2B"))

    /// Outline roughness from M5.
    static let roughness: Float = 0.3

    /// A flat colour that keeps its exact value: RealityKit's tone mapping (which darkened the orange in M5) is off.
    static func flat(_ colour: UIColor) -> UnlitMaterial {
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: colour)
        return material
    }

    /// The smooth, lit look chosen in M5.
    static func lit(_ colour: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: colour, roughness: 0.85, isMetallic: false)
    }

    /// A shape with its sketch outline (two rough inverted hulls). `outline` is the line width in metres:
    /// bigger things seen from further away need a thicker line.
    static func part(_ mesh: LowPolyMesh, colour: UIColor, outline: Float, at position: SIMD3<Float> = .zero,
                     rotationDegrees: Float = 0, name: String = "") -> Entity {
        let entity = Entity()
        entity.name = name
        entity.position = position
        entity.orientation = simd_quatf(angle: rotationDegrees * .pi / 180, axis: [0, 1, 0])
        if let body = try? ModelEntity(mesh: meshResource(mesh), materials: [lit(colour)]) {
            entity.addChild(body)
        }
        if outline > 0 {
            let hulls = [
                mesh.hull(width: outline, roughness: roughness, seed: 1),
                mesh.hull(width: outline * 0.7, roughness: roughness, seed: 2),
            ]
            for hull in hulls {
                if let line = try? ModelEntity(mesh: meshResource(hull), materials: [flat(ink)]) {
                    entity.addChild(line)
                }
            }
        }
        return entity
    }

    /// A flat-coloured shape with no outline (lines on the floor, the backdrop).
    static func flatPart(_ mesh: LowPolyMesh, colour: UIColor, at position: SIMD3<Float> = .zero) -> Entity {
        guard let model = try? ModelEntity(mesh: meshResource(mesh), materials: [flat(colour)]) else { return Entity() }
        model.position = position
        return model
    }

    /// A prop from PlateKit's recipe: parts of the same tone merged into one mesh, and one sketch outline around
    /// the outlined parts. `line` is the outline width in metres. The placement is baked into the meshes so the
    /// baked sunlight (PlateKit's `Sunlight`) sees each face the way it sits in the room.
    static func prop(_ parts: [PropPart], line: Float, placement: RoomLayout.Placement, name: String = "") -> Entity {
        let entity = Entity()
        entity.name = name

        var byTone: [PropPart.Tone: LowPolyMesh] = [:]
        var outlined = LowPolyMesh()
        for part in parts {
            let mesh = part.mesh.placed(placement)
            byTone[part.tone, default: LowPolyMesh()] = byTone[part.tone, default: LowPolyMesh()].combined(with: mesh)
            if part.outlined { outlined = outlined.combined(with: mesh) }
        }
        for (tone, mesh) in byTone {
            let bands: [Int: LowPolyMesh] = switch tone {
            case .dark, .faint: [Sunlight.levels - 1: mesh]       // flat: the sun doesn't change them
            default: Sunlight.bands(mesh)
            }
            for (level, band) in bands {
                if let body = try? ModelEntity(mesh: meshResource(band), materials: [material(tone, level: level)]) {
                    entity.addChild(body)
                }
            }
        }
        if outlined.triangleCount > 0 {
            for hull in [outlined.hull(width: line, roughness: roughness, seed: 1),
                         outlined.hull(width: line * 0.7, roughness: roughness, seed: 2)] {
                if let ink = try? ModelEntity(mesh: meshResource(hull), materials: [flat(Diorama.ink)]) {
                    entity.addChild(ink)
                }
            }
        }
        return entity
    }

    // Baked light, measured off the prototype's screenshots: white in full sun, and the soft lavender of faces
    // turned away from the sun and of shadows.
    static let sunWhite = UIColor(Color(hex: "#FEF9FF"))
    static let shade = UIColor(Color(hex: "#DED4E2"))

    /// The prototype's black and white become the palette's dark and the baked light (SPEC 2.5); plates keep
    /// their colours, a little darker out of the sun. All flat: no RealityKit lights or tone mapping.
    static func material(_ tone: PropPart.Tone, level: Int) -> UnlitMaterial {
        let sun = Sunlight.brightness(level: level)
        switch tone {
        case .dark:
            return flat(ink)
        case .faint:
            return flat(UIColor(Color(hex: "#C8B4C2")))          // tile seams: a faint hairline
        case .light:
            return flat(blend(shade, sunWhite, sun))
        case .steel:
            return flat(darken(UIColor(Color(hex: "#D3D8DD")), sun))
        case .plate(let plate):
            return flat(darken(UIColor(Color(hex: plate.colorHex)), sun))
        }
    }

    static func blend(_ a: UIColor, _ b: UIColor, _ t: Float) -> UIColor {
        var (ar, ag, ab, aa): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (br, bg, bb, ba): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = CGFloat(t)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t, alpha: 1)
    }

    /// A colour out of the sun: shade is to sun-white what this is to the full colour.
    static func darken(_ colour: UIColor, _ sun: Float) -> UIColor {
        blend(blend(colour, .black, 0.12), colour, sun)
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
        descriptor.primitives = .triangles(mesh.indices)
        return try MeshResource.generate(from: [descriptor])
    }

    /// The room's transform that puts `shot` in front of a camera fixed at the origin looking down −Z.
    /// Moving the world instead of the camera works whether or not RealityView uses our camera entity.
    static func worldTransform(for shot: RoomLayout.Shot) -> Transform {
        let eye = Entity()
        eye.look(at: shot.target, from: shot.position, relativeTo: nil)
        return Transform(matrix: eye.transform.matrix.inverse)
    }
}
