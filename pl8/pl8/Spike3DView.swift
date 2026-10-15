import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// M5: one plate on the bar in RealityKit with the target look (SPEC 2.5, Part 5 "risk to spike early").
/// Compare outline and shading options on the phone; the chosen look is logged in DECISIONS.md.
struct Spike3DView: View {
    @State private var outline: SpikeScene.Outline = .sketch
    @State private var shading: SpikeScene.Shading = .toon
    @State private var plateSize: Double = 25
    @State private var width: Double = 0.006
    @State private var roughness: Double = 0.6
    @State private var yaw: Float = -0.7
    @State private var pitch: Float = 0.3
    @State private var dragStart: (yaw: Float, pitch: Float)?

    private var config: SpikeScene.Config {
        SpikeScene.Config(
            outline: outline,
            shading: shading,
            plate: Plate.find(plateSize, .kg) ?? Plate.catalog(.kg)[0],
            width: Float(width),
            roughness: Float(roughness)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            RealityView { content in
                for entity in SpikeScene.entities(config) {
                    content.add(entity)
                }
            } update: { content in
                if let root = content.entities.first(where: { $0.name == SpikeScene.rootName }) {
                    root.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
                }
            }
            // Rebuild the scene when a look setting changes; dragging only turns it.
            .id(config.key)
            .background(Theme.background)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? (yaw, pitch)
                        dragStart = start
                        yaw = start.yaw + Float(value.translation.width) / 150
                        pitch = min(1.2, max(-1.2, start.pitch + Float(value.translation.height) / 150))
                    }
                    .onEnded { _ in dragStart = nil }
            )

            controls
        }
        .background(Theme.background)
        .navigationTitle("3D test")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Outline", selection: $outline) {
                ForEach(SpikeScene.Outline.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Shading", selection: $shading) {
                ForEach(SpikeScene.Shading.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Plate", selection: $plateSize) {
                ForEach([25.0, 20, 15, 10, 5], id: \.self) { Text("\(WeightUnit.trimmed($0)) kg").tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Line").font(.subheadline.weight(.semibold)).frame(width: 64, alignment: .leading)
                Slider(value: $width, in: 0.002...0.014, step: 0.001)
            }
            HStack {
                Text("Rough").font(.subheadline.weight(.semibold)).frame(width: 64, alignment: .leading)
                Slider(value: $roughness, in: 0...1.5, step: 0.1)
            }
            .disabled(outline != .sketch)

            Text("Drag the bar to turn it.").font(.footnote).foregroundStyle(.secondary)
        }
        .drawer()
        .padding(16)
    }
}

/// Builds the M5 test scene from PlateKit's low-poly meshes.
@MainActor
enum SpikeScene {
    enum Outline: String, CaseIterable { case none = "None", line = "Line", sketch = "Sketch" }
    enum Shading: String, CaseIterable { case toon = "Toon", smooth = "Smooth" }

    struct Config {
        let outline: Outline
        let shading: Shading
        let plate: Plate
        let width: Float
        let roughness: Float

        var key: String { "\(outline)-\(shading)-\(plate.size)-\(width)-\(roughness)" }
    }

    static let rootName = "spike-root"

    /// The direction the "sun" shines (down, from the front right).
    static let light = SIMD3<Float>(-0.5, -1, -0.7)

    /// Palette (reference/scene-layout-and-look.json).
    static let ink = UIColor(Color(hex: "#6C3713"))          // boxDark: the hand-drawn line
    static let background = UIColor(Color(hex: "#FF6200"))
    static let steel = UIColor(Color(hex: "#B9BEC6"))

    static func entities(_ config: Config) -> [Entity] {
        let root = Entity()
        root.name = rootName
        root.position = [0, 0, -1.1]                         // in front of the camera at the origin

        // Olympic bar along X, shifted so the loaded sleeve is in the middle of the view.
        let shift = SIMD3<Float>(-0.78, 0, 0)
        let thickness = Float(config.plate.thickness)
        let parts: [(LowPolyMesh, UIColor)] = [
            (LowPolyMesh.cylinder(radius: 0.014, length: 1.31, sides: 10), steel),
            (LowPolyMesh.cylinder(radius: 0.04, length: 0.03, sides: 12).translated(by: [0.67, 0, 0]), steel),
            (LowPolyMesh.cylinder(radius: 0.04, length: 0.03, sides: 12).translated(by: [-0.67, 0, 0]), steel),
            (LowPolyMesh.cylinder(radius: 0.025, length: 0.415, sides: 12).translated(by: [0.8925, 0, 0]), steel),
            (LowPolyMesh.cylinder(radius: 0.025, length: 0.415, sides: 12).translated(by: [-0.8925, 0, 0]), steel),
            (LowPolyMesh.plate(radius: Float(config.plate.diameter) / 2, holeRadius: 0.026, thickness: thickness, sides: 14)
                .translated(by: [0.686 + thickness / 2, 0, 0]),
             UIColor(Color(hex: config.plate.colorHex))),
        ]

        for (mesh, colour) in parts {
            let moved = mesh.translated(by: shift)
            if let body = model(moved, colour: colour, shading: config.shading) {
                root.addChild(body)
            }
            for hull in hulls(moved, config) {
                if let line = try? ModelEntity(mesh: meshResource(hull, faceMaterials: nil), materials: [UnlitMaterial(color: ink)]) {
                    root.addChild(line)
                }
            }
        }

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 40
        camera.look(at: root.position, from: [0, 0.05, 0], relativeTo: nil)

        let sun = DirectionalLight()
        sun.light.intensity = 3000
        sun.look(at: root.position, from: root.position - light * 2, relativeTo: nil)

        // A flat orange backdrop, in case the 3D view doesn't show the SwiftUI background through it.
        let backdrop = ModelEntity(mesh: .generatePlane(width: 40, height: 40), materials: [UnlitMaterial(color: background)])
        backdrop.position = [0, 0, -12]

        return [root, camera, sun, backdrop]
    }

    private static func model(_ mesh: LowPolyMesh, colour: UIColor, shading: Shading) -> ModelEntity? {
        switch shading {
        case .toon:
            // Three flat shades of the colour, chosen per face by PlateKit's toon bands.
            let bands = mesh.toonBands(lightDirection: light, levels: 3)
            let materials: [any Material] = [0.62, 0.82, 1.0].map { UnlitMaterial(color: shade(colour, $0)) }
            guard let resource = try? meshResource(mesh, faceMaterials: bands) else { return nil }
            return ModelEntity(mesh: resource, materials: materials)
        case .smooth:
            guard let resource = try? meshResource(mesh, faceMaterials: nil) else { return nil }
            return ModelEntity(mesh: resource, materials: [SimpleMaterial(color: colour, roughness: 0.7, isMetallic: false)])
        }
    }

    private static func hulls(_ mesh: LowPolyMesh, _ config: Config) -> [LowPolyMesh] {
        switch config.outline {
        case .none:
            return []
        case .line:
            return [mesh.hull(width: config.width, roughness: 0, seed: 1)]
        case .sketch:
            // Two rough lines on top of each other, like a pencil going round twice.
            return [
                mesh.hull(width: config.width, roughness: config.roughness, seed: 1),
                mesh.hull(width: config.width * 0.7, roughness: config.roughness, seed: 2),
            ]
        }
    }

    private static func meshResource(_ mesh: LowPolyMesh, faceMaterials: [UInt32]?) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: "part")
        descriptor.positions = MeshBuffers.Positions(mesh.positions)
        var normals = Array(repeating: SIMD3<Float>(0, 1, 0), count: mesh.positions.count)
        for triangle in 0..<mesh.triangleCount {
            let normal = mesh.faceNormal(triangle)
            for corner in 0..<3 { normals[Int(mesh.indices[triangle * 3 + corner])] = normal }
        }
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(mesh.indices)
        if let faceMaterials {
            descriptor.materials = .perFace(faceMaterials)
        }
        return try MeshResource.generate(from: [descriptor])
    }

    private static func shade(_ colour: UIColor, _ factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        colour.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: a)
    }
}
