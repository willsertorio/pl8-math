import CoreGraphics
import Metal
import RealityKit
import SwiftUI
import UIKit
import PlateKit

/// A model drawn with the prototype's light. Its faces' colours come from where they face in the world now, so
/// when it turns its light stays put; a toon or standard face gets its colour from a tiny palette texture (one
/// texel per triangle), a printed face a tint on its picture.
final class FlowShadedModel {
    let model: ModelEntity
    var part: FlowPart
    /// Each triangle's normal in the model's own space.
    let normals: [SIMD3<Float>]
    /// The palette lives on the GPU; new colours are copied into it, the material stays.
    var palette: TextureResource?
    var paletteTexture: LowLevelTexture?
    /// The opacity of the palette material last given to the model (nil: give it one).
    var paletteOpacity: Float?
    var bakedOrientation: simd_quatf?
    var bakedState: State?
    var state = State()
    var dirty = true

    struct State: Equatable {
        var shine: Float = 0
        var opacity: Float = 1
        var grey = false
        /// How far towards `FlowLook.wash` (the abduction's beam greying a bell).
        var wash: Float = 0
    }

    init(model: ModelEntity, part: FlowPart) {
        self.model = model
        self.part = part
        normals = (0..<part.mesh.triangleCount).map { part.mesh.faceNormal($0) }
    }
}

extension Flow {
    // MARK: - FlowNode → entities

    /// The prop as RealityKit entities: one entity per node, a model per part; hit boxes are remembered.
    func build(_ node: FlowNode) -> Entity {
        let entity = Entity()
        entity.name = node.name
        entity.position = node.position
        entity.orientation = Self.quaternion(node.rotation)
        entity.scale = node.scale
        for part in node.parts { entity.addChild(model(part)) }
        if let size = node.hitBox { hitSizes[ObjectIdentifier(entity)] = size }
        for child in node.children { entity.addChild(build(child)) }
        return entity
    }

    /// three.js Euler XYZ: R = Rx · Ry · Rz.
    static func quaternion(_ e: SIMD3<Float>) -> simd_quatf {
        simd_quatf(angle: e.x, axis: [1, 0, 0]) * simd_quatf(angle: e.y, axis: [0, 1, 0]) * simd_quatf(angle: e.z, axis: [0, 0, 1])
    }

    func model(_ part: FlowPart) -> ModelEntity {
        var mesh = part.mesh
        if part.twoSided { mesh.append(mesh.insideOut()) }
        var lit = part
        lit.mesh = mesh
        let model: ModelEntity
        switch (part.shade, part.paint) {
        case (.toon, .colour), (.standard, .colour):
            let resource = cachedMesh(mesh, palette: true) ?? MeshResource.generateBox(size: 0.001)
            model = ModelEntity(mesh: resource, materials: [UnlitMaterial(applyPostProcessToneMap: false)])
        case (.occluder, _):
            let resource = cachedMesh(mesh, palette: false) ?? MeshResource.generateBox(size: 0.001)
            model = ModelEntity(mesh: resource, materials: [OcclusionMaterial()])
            model.name = part.name
            return model
        default:
            let resource = cachedMesh(mesh, palette: false) ?? MeshResource.generateBox(size: 0.001)
            model = ModelEntity(mesh: resource, materials: [UnlitMaterial(applyPostProcessToneMap: false)])
        }
        model.name = part.name
        // Lit on its first frame in the scene (reshade), where it really faces: lighting it here, before it's
        // placed, meant lighting it twice.
        shaded.append(FlowShadedModel(model: model, part: lit))
        return model
    }

    /// The same shape built once: the gym room's piles alone are thirty-odd identical plates, and the same props
    /// come back question after question. Keyed by every vertex, so only a true copy matches.
    func cachedMesh(_ mesh: LowPolyMesh, palette: Bool) -> MeshResource? {
        var hasher = Hasher()
        hasher.combine(palette)
        hasher.combine(mesh.positions.count)
        for p in mesh.positions { hasher.combine(p.x.bitPattern); hasher.combine(p.y.bitPattern); hasher.combine(p.z.bitPattern) }
        hasher.combine(mesh.indices)
        for uv in mesh.uvs { hasher.combine(uv.x.bitPattern); hasher.combine(uv.y.bitPattern) }
        let key = hasher.finalize()
        if let resource = meshCache[key] { return resource }
        guard let resource = try? Self.meshResource(mesh, palette: palette) else { return nil }
        if meshCache.count > 800 { meshCache.removeAll() }
        meshCache[key] = resource
        return resource
    }

    /// The mesh with a normal per face and either its own texture coordinates or, for a palette, one texel per
    /// triangle.
    static func meshResource(_ mesh: LowPolyMesh, palette: Bool) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: "flow")
        descriptor.positions = MeshBuffers.Positions(mesh.positions)
        var normals = Array(repeating: SIMD3<Float>(0, 1, 0), count: mesh.positions.count)
        var uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: mesh.positions.count)
        let layout = paletteLayout(mesh.triangleCount)
        for triangle in 0..<mesh.triangleCount {
            let normal = mesh.faceNormal(triangle)
            let texel = SIMD2<Float>((Float(triangle % layout.width) + 0.5) / Float(layout.width),
                                     1 - (Float(triangle / layout.width) + 0.5) / Float(layout.rows))
            for corner in 0..<3 {
                let index = Int(mesh.indices[triangle * 3 + corner])
                normals[index] = normal
                if palette { uvs[index] = texel }
            }
        }
        descriptor.normals = MeshBuffers.Normals(normals)
        if palette {
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        } else if mesh.uvs.count == mesh.positions.count {
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(mesh.uvs)
        }
        descriptor.primitives = .triangles(mesh.indices)
        return try MeshResource.generate(from: [descriptor])
    }

    static func paletteLayout(_ count: Int) -> (width: Int, rows: Int) {
        let width = max(1, min(count, 2048))
        return (width, max(1, (count + width - 1) / width))
    }

    // MARK: - Light, again when things turn

    /// Re-lights what has turned (or shines, fades, goes grey) since it was last lit, then sends the new colours
    /// to the GPU in one go. New models always; others up to a budget per frame: a falling plate's colours
    /// lagging a frame can't be seen.
    func reshade() {
        var budget = 160
        for item in shaded {
            guard item.model.scene != nil else { continue }
            guard let baked = item.bakedOrientation else { bake(item); continue }
            guard budget > 0 else { continue }
            let orientation = item.model.orientation(relativeTo: nil)
            if item.dirty || abs(simd_dot(baked.vector, orientation.vector)) < 0.99985 || item.bakedState != item.state {
                bake(item)
                budget -= 1
            }
        }
        uploadPalettes()
    }

    /// The palettes' new colours, copied into their GPU textures with one command buffer.
    private func uploadPalettes() {
        guard !paletteUploads.isEmpty else { return }
        let uploads = paletteUploads
        paletteUploads = [:]
        guard let queue = Self.paletteQueue, let commands = queue.makeCommandBuffer() else { return }
        var bytes: [UInt8] = []
        var copies: [(offset: Int, width: Int, height: Int, target: MTLTexture)] = []
        for upload in uploads.values {
            copies.append((bytes.count, upload.width, upload.height, upload.texture.replace(using: commands)))
            bytes += upload.bytes
        }
        guard let staging = queue.device.makeBuffer(bytes: bytes, length: bytes.count, options: .storageModeShared),
              let blit = commands.makeBlitCommandEncoder() else { return }
        for copy in copies {
            blit.copy(from: staging, sourceOffset: copy.offset, sourceBytesPerRow: copy.width * 4,
                      sourceBytesPerImage: copy.width * copy.height * 4, sourceSize: MTLSize(width: copy.width, height: copy.height, depth: 1),
                      to: copy.target, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        }
        blit.endEncoding()
        commands.commit()
    }

    static let paletteQueue = MTLCreateSystemDefaultDevice()?.makeCommandQueue()

    /// A palette's GPU texture: one sRGB texel per triangle.
    static func paletteTexture(width: Int, height: Int) -> LowLevelTexture? {
        var descriptor = LowLevelTexture.Descriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .rgba8Unorm_srgb
        descriptor.width = width
        descriptor.height = height
        descriptor.depth = 1
        descriptor.mipmapLevelCount = 1
        descriptor.textureUsage = [.shaderRead]
        return try? LowLevelTexture(descriptor: descriptor)
    }

    func bake(_ item: FlowShadedModel) {
        perf?.bakes += 1
        let orientation = item.model.orientation(relativeTo: nil)
        item.bakedOrientation = orientation
        item.bakedState = item.state
        item.dirty = false
        let part = item.part, state = item.state
        let opacity = part.opacity * state.opacity
        if state.grey {
            item.paletteOpacity = nil
            var material = UnlitMaterial(applyPostProcessToneMap: false)
            material.color = .init(tint: FlowLook.missing.uiColor)
            material.blending = .transparent(opacity: .init(floatLiteral: FlowLook.missingOpacity * opacity))
            item.model.model?.materials = [material]
            return
        }
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        switch (part.shade, part.paint) {
        case (.occluder, _):
            return
        case (.flat, .colour(let colour)):
            material.color = .init(tint: Self.washed(colour, state.wash).uiColor)
        case (.flat, .picture(let picture, let tint)):
            guard let texture = texture(picture) else { return }
            material.color = .init(tint: Self.washed(tint, state.wash).uiColor, texture: .init(texture))
            if Self.hasAlpha(picture) || opacity < 1 {
                material.blending = .transparent(opacity: .init(floatLiteral: opacity))
            }
            item.model.model?.materials = [material]
            return
        case (_, .picture(let picture, let tint)):
            guard let texture = texture(picture) else { return }
            let normal = orientation.act(item.normals.first ?? [0, 0, 1])
            let light: RGB
            switch part.shade {
            case .standard(let roughness, let metalness):
                light = FlowLight.standard(tint, normal: normal, roughness: roughness, metalness: metalness, shine: state.shine)
            default:
                light = FlowLight.toon(tint, normal: normal, shine: state.shine)
            }
            material.color = .init(tint: Self.washed(light, state.wash).uiColor, texture: .init(texture))
        case (_, .colour(let base)):
            // One texel per triangle, lit where it faces now.
            let layout = Self.paletteLayout(item.normals.count)
            var bytes = [UInt8](repeating: 255, count: layout.width * layout.rows * 4)
            for (index, normal) in item.normals.enumerated() {
                let world = orientation.act(normal)
                var colour: RGB
                switch part.shade {
                case .standard(let roughness, let metalness):
                    colour = FlowLight.standard(base, normal: world, roughness: roughness, metalness: metalness, shine: state.shine)
                default:
                    colour = FlowLight.toon(base, normal: world, shine: state.shine)
                }
                colour = Self.washed(colour, state.wash)
                bytes[index * 4] = UInt8((colour.r * 255).rounded())
                bytes[index * 4 + 1] = UInt8((colour.g * 255).rounded())
                bytes[index * 4 + 2] = UInt8((colour.b * 255).rounded())
            }
            if item.paletteTexture == nil {
                item.paletteTexture = Self.paletteTexture(width: layout.width, height: layout.rows)
                item.palette = item.paletteTexture.flatMap { try? TextureResource(from: $0) }
            }
            guard let texture = item.paletteTexture, let palette = item.palette else { return }
            paletteUploads[ObjectIdentifier(texture)] = (texture, bytes, layout.width, layout.rows)
            // Only new colours: the model keeps its material.
            if item.paletteOpacity == opacity { return }
            item.paletteOpacity = opacity
            material.color = .init(tint: .white, texture: .init(palette))
        }
        if opacity < 1 { material.blending = .transparent(opacity: .init(floatLiteral: opacity)) }
        item.model.model?.materials = [material]
    }

    static func washed(_ colour: RGB, _ amount: Float) -> RGB {
        guard amount > 0 else { return colour }
        let w = FlowLook.wash
        return RGB(colour.r + (w.r - colour.r) * amount, colour.g + (w.g - colour.g) * amount, colour.b + (w.b - colour.b) * amount)
    }


    /// The models under `entity` (to shine them, grey them out or fade them).
    func shadedModels(under entity: Entity) -> [FlowShadedModel] {
        shaded.filter { item in
            var node: Entity? = item.model
            while let current = node {
                if current === entity { return true }
                node = current.parent
            }
            return false
        }
    }

    func setOpacity(_ opacity: Float, under entity: Entity) {
        for item in shadedModels(under: entity) { item.state.opacity = opacity }
    }

    func setGrey(_ grey: Bool, under entity: Entity) {
        for item in shadedModels(under: entity) { item.state.grey = grey }
    }

    func setWash(_ amount: Float, under entity: Entity) {
        for item in shadedModels(under: entity) { item.state.wash = amount }
    }

    // MARK: - Pictures

    static func hasAlpha(_ picture: FlowPicture) -> Bool {
        switch picture {
        case .text, .shadowBlob, .star: true
        default: false
        }
    }

    func texture(_ picture: FlowPicture) -> TextureResource? {
        if let cached = textures[picture] { return cached }
        guard let image = FlowArt.image(picture).cgImage,
              let texture = try? TextureResource(image: image, options: .init(semantic: .color)) else { return nil }
        if textures.count > 200 { textures.removeAll() }
        textures[picture] = texture
        return texture
    }
}

/// The prototype's canvases (textTex, flDrawBoard, notebookModel2, gymRoomModel, softShadow, flSparkles).
@MainActor
enum FlowArt {
    static func image(_ picture: FlowPicture) -> UIImage {
        switch picture {
        case .text(let text, let width, let height, let size, let colour, let dy):
            return draw(width, height, opaque: false) { _ in
                let font = UIFont(name: "SpaceGrotesk-Bold", size: CGFloat(size)) ?? .boldSystemFont(ofSize: CGFloat(size))
                centred(text, font: font, colour: colour.uiColor, at: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2 + CGFloat(dy)))
            }
        case .plateFace(let plate):
            return PictureArt.plateFace(plate)
        case .whiteboard(let lines):
            return whiteboard(lines)
        case .notebookCover(let title):
            return draw(512, 680) { g in
                g.setFillColor(FlowLook.dark.uiColor.cgColor)
                g.fill(CGRect(x: 0, y: 0, width: 512, height: 680))
                g.setFillColor(UIColor(white: 1, alpha: 0.07).cgColor)
                for y in stride(from: 0, to: 680, by: 6) { g.fill(CGRect(x: 0, y: y, width: 512, height: 2)) }
                g.setFillColor(FlowLook.light.uiColor.cgColor)
                g.fill(CGRect(x: 70, y: 230, width: 372, height: 170))
                centred(title, font: marker(92), colour: FlowLook.dark.uiColor, at: CGPoint(x: 256, y: 318))
            }
        case .notebookPage(let rows):
            return draw(512, 680) { g in
                g.setFillColor(UIColor(red: 0xFB / 255, green: 0xF8 / 255, blue: 0xF2 / 255, alpha: 1).cgColor)
                g.fill(CGRect(x: 0, y: 0, width: 512, height: 680))
                g.setStrokeColor(UIColor(red: 70 / 255, green: 110 / 255, blue: 190 / 255, alpha: 0.28).cgColor)
                g.setLineWidth(2)
                for y in stride(from: 120, to: 680, by: 62) { g.strokeLineSegments(between: [CGPoint(x: 30, y: y), CGPoint(x: 490, y: y)]) }
                g.setStrokeColor(UIColor(red: 210 / 255, green: 60 / 255, blue: 60 / 255, alpha: 0.35).cgColor)
                g.strokeLineSegments(between: [CGPoint(x: 78, y: 0), CGPoint(x: 78, y: 680)])
                let ink = UIColor(red: 0x1C / 255, green: 0x2A / 255, blue: 0x55 / 255, alpha: 1)
                baseline("PRs", font: marker(48), colour: ink, at: CGPoint(x: 96, y: 88))
                for (i, row) in rows.enumerated() { baseline(row, font: marker(34), colour: ink, at: CGPoint(x: 96, y: 170 + CGFloat(i) * 62)) }
            }
        case .gymFront(let name):
            return draw(256, 256) { g in
                g.setFillColor(FlowLook.light.uiColor.cgColor)
                g.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
                centred(name, font: grotesk(84), colour: FlowLook.dark.uiColor, at: CGPoint(x: 128, y: 134))
            }
        case .flag(let name):
            return draw(320, 200) { g in
                g.setFillColor(FlowLook.dark.uiColor.cgColor)
                g.fill(CGRect(x: 0, y: 0, width: 320, height: 200))
                centred(name, font: grotesk(74), colour: FlowLook.light.uiColor, at: CGPoint(x: 160, y: 104))
            }
        case .shadowBlob:
            return draw(128, 128, opaque: false) { g in
                // The prototype's 0.38 / 0.16 come out about 1.45 times darker and wider on its screens than ours did at
                // 0.46 / 0.19 (measured on six screens), so these are scaled up to match what it shows.
                let colours = [UIColor(white: 0, alpha: 0.67).cgColor, UIColor(white: 0, alpha: 0.28).cgColor, UIColor(white: 0, alpha: 0).cgColor]
                guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours as CFArray,
                                                locations: [0, 0.55, 1]) else { return }
                g.drawRadialGradient(gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 4, endCenter: CGPoint(x: 64, y: 64),
                                     endRadius: 62, options: [.drawsBeforeStartLocation])
            }
        case .star:
            return draw(64, 64, opaque: false) { g in
                g.setFillColor(UIColor.white.cgColor)
                g.beginPath()
                for i in 0..<8 {
                    let a = CGFloat(i) * .pi / 4, r: CGFloat = i % 2 == 1 ? 7 : 31
                    let p = CGPoint(x: 32 + cos(a) * r, y: 32 + sin(a) * r)
                    if i == 0 { g.move(to: p) } else { g.addLine(to: p) }
                }
                g.closePath()
                g.fillPath()
            }
        }
    }

    /// flDrawBoard: the light board with a fine grid, "Today's sesh" underlined, then up to four lifts.
    static func whiteboard(_ lines: [FlowBoardLine]?) -> UIImage {
        draw(1024, 662) { g in
            drawBoard(g, lines: lines)
        }
    }

    static func drawBoard(_ g: CGContext, lines: [FlowBoardLine]?) {
        let w: CGFloat = 1024, h: CGFloat = 662
        g.setFillColor(FlowLook.light.uiColor.cgColor)
        g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        g.setStrokeColor(UIColor(red: 108 / 255, green: 55 / 255, blue: 19 / 255, alpha: 0.11).cgColor)
        g.setLineWidth(2)
        for x in stride(from: 0, through: w, by: 40) { g.strokeLineSegments(between: [CGPoint(x: x, y: 0), CGPoint(x: x, y: h)]) }
        for y in stride(from: 0, through: h, by: 40) { g.strokeLineSegments(between: [CGPoint(x: 0, y: y), CGPoint(x: w, y: y)]) }
        let ink = FlowLook.dark.uiColor
        let title = "Today's sesh", titleFont = marker(64)
        baseline(title, font: titleFont, colour: ink, at: CGPoint(x: 48, y: 100))
        let width = (title as NSString).size(withAttributes: [.font: titleFont]).width
        g.setStrokeColor(ink.cgColor)
        g.setLineWidth(5)
        g.strokeLineSegments(between: [CGPoint(x: 48, y: 124), CGPoint(x: 48 + width, y: 118)])
        guard let lines else { return }
        var y: CGFloat = 210
        for line in lines.prefix(4) {
            baseline(line.title, font: marker(50), colour: ink, at: CGPoint(x: 48, y: y))
            baseline(line.format, font: marker(40), colour: ink, at: CGPoint(x: 100, y: y + 56))
            baseline(line.load, font: marker(40), colour: ink, at: CGPoint(x: 600, y: y + 56))
            y += 150
        }
    }

    // MARK: - Drawing helpers

    static func draw(_ width: Int, _ height: Int, opaque: Bool = true, _ body: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            body(context.cgContext)
        }
    }

    static func marker(_ size: CGFloat) -> UIFont { UIFont(name: "PermanentMarker-Regular", size: size) ?? .systemFont(ofSize: size) }
    static func grotesk(_ size: CGFloat) -> UIFont { UIFont(name: "SpaceGrotesk-Bold", size: size) ?? .boldSystemFont(ofSize: size) }

    /// Canvas fillText with textAlign centre, textBaseline middle.
    static func centred(_ text: String, font: UIFont, colour: UIColor, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
        let size = (text as NSString).size(withAttributes: attributes)
        // "middle" is the middle of the em box: centre the cap height and descender like canvas does.
        let middle = (font.ascender + font.descender) / 2
        (text as NSString).draw(at: CGPoint(x: point.x - size.width / 2, y: point.y - font.ascender + middle), withAttributes: attributes)
    }

    /// Canvas fillText at the alphabetic baseline, left aligned.
    static func baseline(_ text: String, font: UIFont, colour: UIColor, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
        (text as NSString).draw(at: CGPoint(x: point.x, y: point.y - font.ascender), withAttributes: attributes)
    }
}
