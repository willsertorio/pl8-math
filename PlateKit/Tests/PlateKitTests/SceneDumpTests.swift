import Foundation
import Testing
@testable import PlateKit

/// Writes the baked scene (ours.json) and the camera shots (shots.json) into the folder PL8_SCENE_DUMP names, so
/// tools/visual-check can render them next to the prototype in a browser (three.js, unlit, like the phone).
/// Does nothing otherwise.
@Suite("Scene dump for visual comparison")
struct SceneDumpTests {
    @Test func dumpBakedScene() throws {
        guard let folder = ProcessInfo.processInfo.environment["PL8_SCENE_DUMP"] else { return }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let path = folder + "/ours.json"
        let shots = RoomLayout.Station.allCases.map { station -> String in
            let shot = RoomLayout.shots[station]!
            func v(_ p: SIMD3<Float>) -> String { "[\(p.x),\(p.y),\(p.z)]" }
            return "\"\(station.rawValue)\":{\"T\":\(v(shot.target)),\"P\":\(v(shot.position)),\"fov\":\(shot.fieldOfView)}"
        }
        try ("{" + shots.joined(separator: ",") + "}").write(toFile: folder + "/shots.json", atomically: true, encoding: .utf8)
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
                case .whiteboard: what = "{\"kind\":\"wb\"}"
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
