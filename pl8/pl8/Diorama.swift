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
