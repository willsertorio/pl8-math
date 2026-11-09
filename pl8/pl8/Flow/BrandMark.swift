import CoreText
import SwiftUI
import UIKit

/// The pl8(math) logo (Will, 2026-11-09): "pℓ8(mαth)" in Helvetica Neue Bold, each letter spaced by hand (no font
/// kerning), the parentheses at 94 % and raised 0.02 em. Every value is a fraction of `size`, so it scales as one.
struct BrandMark: View {
    /// The letters' size: 67 pt on a 390 pt-wide screen.
    var size: CGFloat
    var colour: Color

    static let font = "HelveticaNeue-Bold"
    static let text = "pℓ8(mαth)"   // ℓ U+2113, α U+03B1

    /// One letter: the space after it (em of its own size) and whether it's a parenthesis.
    struct Letter {
        let character: String
        let after: CGFloat
        var paren = false
    }

    /// The spacing table (−0.03 em tracking included). After "(" the −0.020 em is of the parenthesis's own size.
    static let letters: [Letter] = [
        .init(character: "p", after: -0.130),
        .init(character: "ℓ", after: -0.095),
        .init(character: "8", after: -0.045),
        .init(character: "(", after: -0.020, paren: true),
        .init(character: "m", after: -0.065),
        .init(character: "α", after: -0.085),
        .init(character: "t", after: -0.035),
        .init(character: "h", after: -0.030),
        .init(character: ")", after: 0, paren: true),
    ]
    static let parenScale: CGFloat = 0.94
    static let parenRaise: CGFloat = 0.02

    /// 67 pt at 390 pt wide, in proportion elsewhere.
    static func size(forWidth width: CGFloat) -> CGFloat { 67 * width / 390 }

    var body: some View {
        Self.letters.reduce(Text("")) { text, letter in
            let letterSize = letter.paren ? size * Self.parenScale : size
            var piece = Text(letter.character)
                .font(.custom(Self.font, size: letterSize))
                .kerning(letter.after * letterSize)
            if letter.paren { piece = piece.baselineOffset(Self.parenRaise * size) }
            return text + piece.foregroundStyle(colour)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityLabel("pl8(math)")
    }

    /// Which font really draws each letter (for the CI check: ℓ and α must not fall back to another font).
    static func fontsUsed() -> [(String, String)] {
        let base = CTFontCreateWithName(font as CFString, 67, nil)
        return letters.map { letter in
            let used = CTFontCreateForString(base, letter.character as CFString, CFRange(location: 0, length: (letter.character as NSString).length))
            return (letter.character, CTFontCopyPostScriptName(used) as String)
        }
    }
}
