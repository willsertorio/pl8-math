import Foundation
import Testing
@testable import PlateKit

/// Writes the baked scene as JSON when PL8_SCENE_DUMP names a file, so it can be rendered next to the prototype
/// in a browser (three.js, unlit, the same as the phone). Does nothing otherwise.
@Suite("Scene dump for visual comparison")
struct SceneDumpTests {
    @Test func dumpBakedScene() throws {
        guard let path = ProcessInfo.processInfo.environment["PL8_SCENE_DUMP"] else { return }
        let pieces = SceneBake.pieces(plates: Plate.catalog(.kg), gymName: "79")
        var out = "["
        for (n, piece) in pieces.enumerated() {
            if n > 0 { out += "," }
            let paint: String
            switch piece.paint {
            case .colour(let c): paint = "{\"colour\":\"\(c.hex)\"}"
            case .picture(let picture, let tint):
                let what: String
                switch picture {
                case .plateFace(let plate):
                    let label = plate.size.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(plate.size)) : String(plate.size)
                    what = "{\"kind\":\"plate\",\"label\":\"\(label)\",\"colour\":\"\(plate.colorHex)\",\"bumper\":\(plate.kind == .bumper),\"unit\":\"\(plate.unit == .kg ? "KG" : "LB")\"}"
                case .prTable: what = "{\"kind\":\"pr\"}"
                case .flag(let text): what = "{\"kind\":\"flag\",\"text\":\"\(text)\"}"
                }
                paint = "{\"picture\":\(what),\"tint\":\"\(tint.hex)\"}"
            }
            let p = piece.mesh.positions.flatMap { [$0.x, $0.y, $0.z] }.map { String(format: "%.4f", $0) }.joined(separator: ",")
            let uv = piece.mesh.uvs.flatMap { [$0.x, $0.y] }.map { String(format: "%.4f", $0) }.joined(separator: ",")
            let i = piece.mesh.indices.map(String.init).joined(separator: ",")
            out += "{\"paint\":\(paint),\"walls\":[\(piece.walls.map { "\"\($0.rawValue)\"" }.joined(separator: ","))],\"p\":[\(p)],\"uv\":[\(uv)],\"i\":[\(i)]}"
        }
        out += "]"
        try out.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
