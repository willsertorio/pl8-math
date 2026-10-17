import CoreText
import SwiftUI
import UIKit
import PlateKit

/// The prototype's screens (reference/prototype-app-logic.js applyUILook and its LOOK_DEF, uiLook in
/// scene-layout-and-look.json): Space Grotesk (600 for text, 700 for headings and buttons), black on white, square
/// drawers and buttons with a rough edge, pill chips, frosted cards over the room.
enum Theme {
    /// Flat orange behind the room (#FF6200).
    static let background = Color(red: 1, green: 0x62 / 255, blue: 0)
    static let ink = Color.black
    static let paper = Color.white
    /// The prototype's --c-ink2 (values, small labels), --c-ink3 (chevrons, hints), --c-soft (chips and secondary
    /// buttons when off), --c-sel (tags, a picked row), --c-float (the session's cards).
    static let ink2 = Color.black.opacity(0.48)
    static let ink3 = Color.black.opacity(0.264)
    static let soft = Color.black.opacity(0.07)
    static let selected = Color.black.opacity(0.16)
    static let float = Color.white.opacity(0.94)

    /// Space Grotesk 700: headings, buttons, chips, tab labels.
    static func display(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Bold", size: size) }
    /// Space Grotesk 600: everything else.
    static func text(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-SemiBold", size: size) }

    /// Headings: 25 pt, tracking −0.01 em.
    static let heading = display(25)
    /// Small uppercase labels: 13 pt.
    static let label = display(13)
}

/// The fonts the app ships (Fonts/): Space Grotesk and Playfair Display (SIL Open Font License), Permanent Marker
/// (Apache 2.0). Registered once, at launch.
enum Fonts {
    private static let registered: Void = {
        for name in ["SpaceGrotesk-Medium", "SpaceGrotesk-SemiBold", "SpaceGrotesk-Bold", "PlayfairDisplay-Black", "PermanentMarker-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    static func register() { _ = registered }
}

// MARK: - The rough edge

/// A rectangle whose edges wobble like the prototype's rough filter (feTurbulence fractal noise at 0.039 per point,
/// two octaves, displacing the outline by up to ±2.25 pt). The same shape for the same size, every time.
struct RoughRectangle: Shape {
    var amplitude: CGFloat = 2.25
    var seed: UInt32 = 1

    func path(in rect: CGRect) -> Path {
        let step: CGFloat = 3
        var points: [CGPoint] = []
        func edge(from a: CGPoint, to b: CGPoint) {
            let length = hypot(b.x - a.x, b.y - a.y), count = max(1, Int(length / step))
            for i in 0..<count {
                let t = CGFloat(i) / CGFloat(count)
                points.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        for i in 0..<4 { edge(from: corners[i], to: corners[(i + 1) % 4]) }
        var path = Path()
        for (i, p) in points.enumerated() {
            // Like feDisplacementMap: x moves by one noise channel, y by another, each centred on zero.
            let moved = CGPoint(x: p.x + (Self.noise(p.x, p.y, seed) - 0.5) * amplitude * 2,
                                y: p.y + (Self.noise(p.x, p.y, seed &+ 101) - 0.5) * amplitude * 2)
            if i == 0 { path.move(to: moved) } else { path.addLine(to: moved) }
        }
        path.closeSubpath()
        return path
    }

    /// Two octaves of smooth value noise, 0…1.
    static func noise(_ x: CGFloat, _ y: CGFloat, _ seed: UInt32) -> CGFloat {
        let f: CGFloat = 0.039
        return (value(x * f, y * f, seed) * 2 + value(x * f * 2, y * f * 2, seed &+ 7)) / 3
    }

    private static func value(_ x: CGFloat, _ y: CGFloat, _ seed: UInt32) -> CGFloat {
        let xi = floor(x), yi = floor(y), fx = x - xi, fy = y - yi
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        func h(_ i: CGFloat, _ j: CGFloat) -> CGFloat {
            var v = UInt32(truncatingIfNeeded: Int(i) &* 374_761_393 &+ Int(j) &* 668_265_263) ^ seed &* 2_246_822_519
            v = (v ^ (v >> 13)) &* 1_274_126_177
            return CGFloat(v % 10_000) / 10_000
        }
        let a = h(xi, yi), b = h(xi + 1, yi), c = h(xi, yi + 1), d = h(xi + 1, yi + 1)
        return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy
    }
}

// MARK: - Buttons

/// Every button gives under the finger: it sinks quickly and springs back (prototype buildPhone).
private struct Press: ViewModifier {
    let isPressed: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1)
            .animation(isPressed ? .easeOut(duration: 0.11) : .spring(response: 0.28, dampingFraction: 0.6), value: isPressed)
    }
}

/// The prototype's bigButton: solid black, 40 pt, square with a rough edge, Space Grotesk 700 18 pt in white.
struct BlackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label(configuration: configuration)
    }

    private struct Label: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Theme.display(18))
                .tracking(0.18)
                .foregroundStyle(Theme.paper)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoughRectangle().fill(Theme.ink))
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(Rectangle())
                .modifier(Press(isPressed: configuration.isPressed))
        }
    }
}

/// The prototype's secondary button (Edit, Cancel): the soft grey, rough edged, black text.
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(17))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(RoughRectangle().fill(Theme.soft))
            .contentShape(Rectangle())
            .modifier(Press(isPressed: configuration.isPressed))
    }
}

/// Plain, but it still gives under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(Press(isPressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == BlackButtonStyle {
    static var black: BlackButtonStyle { BlackButtonStyle() }
    static var bigBlack: BlackButtonStyle { BlackButtonStyle() }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// The prototype's field: 56 pt, 14 pt corners, white, Space Grotesk 700 at 24 pt.
struct OutlineFieldStyle: TextFieldStyle {
    var size: CGFloat = 24

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(Theme.display(size))
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.paper))
    }
}

extension View {
    /// A block of content on a white drawer.
    func drawer() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Theme.ink)
            .background(Theme.paper)
    }

    /// Small uppercase label (the set card's lift, section names).
    func sectionLabel() -> some View {
        self.font(Theme.label).tracking(1.04).textCase(.uppercase).foregroundStyle(Theme.ink2)
    }
}

// MARK: - Chips

/// The prototype's chip: a 40 pt pill, black with white text when on, the soft grey when off; Space Grotesk 700
/// at 16 pt, tabular figures.
struct Chip<Content: View>: View {
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .font(Theme.display(16))
                .monospacedDigit()
                .lineLimit(1)
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .frame(height: 40)
                .foregroundStyle(isOn ? Theme.paper : Theme.ink)
                .background(Capsule().fill(isOn ? Theme.ink : Theme.soft))
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
    }
}

/// A plate's colour as a dot sized by its diameter (10 + 14 × d points): on a picked chip it gets a white ring,
/// otherwise a fine dark one.
struct PlateDot: View {
    let plate: Plate
    var isOn = false

    var body: some View {
        let size = CGFloat(10 + 14 * plate.diameter)
        Circle()
            .fill(Color(hex: plate.colorHex))
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Color.black.opacity(isOn ? 0 : 0.18), lineWidth: 1))
            .overlay(Circle().stroke(Theme.paper, lineWidth: isOn ? 2 : 0).padding(-1))
    }
}

/// Chips wrapping onto as many lines as they need, 8 pt apart (prototype chipWrap).
struct Flow<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder let content: () -> Content

    var body: some View {
        FlowLayout(spacing: spacing).callAsFunction(content)
    }
}

/// The layout behind `Flow`.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        var items: [Int] = [], x: CGFloat = 0, height: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !items.isEmpty && x + spacing + size.width > width {
                rows.append((items, x, height))
                items = []; x = 0; height = 0
            }
            x += (items.isEmpty ? 0 : spacing) + size.width
            height = max(height, size.height)
            items.append(index)
        }
        if !items.isEmpty { rows.append((items, x, height)) }
        return rows
    }
}

// MARK: - Drawers

/// The prototype's sheet: white, square, a rough edge, no handle; a 44 pt bar with a back arrow on the left and an
/// action on the right; the content below with 16 pt sides, as tall as it is (up to 62 % of the screen, then it
/// scrolls).
struct Drawer<Content: View>: View {
    var back: (() -> Void)? = nil
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var maxHeight: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let back {
                    Button(action: back) {
                        ProtoIcon(kind: .back).frame(width: 24, height: 24).frame(width: 40, height: 40)
                    }
                    .buttonStyle(.pressable)
                    .padding(.leading, -8)
                    .accessibilityLabel("Back")
                }
                Spacer()
                if let action, let onAction {
                    Button(action, action: onAction)
                        .font(Theme.text(17))
                        .buttonStyle(.pressable)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)

            ScrollView {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .frame(height: min(contentHeight, maxHeight ?? UIScreen.main.bounds.height * 0.62))
        }
        .foregroundStyle(Theme.ink)
        .background(RoughRectangle().fill(Theme.paper).padding(.bottom, -60).ignoresSafeArea(edges: .bottom))
    }
}

/// The question at the top of a drawer: 25 pt, then a little air (prototype bigQ).
struct DrawerHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.heading)
            .tracking(-0.25)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 18)
    }
}

/// A list row (prototype row): 44 pt or taller, 16 pt sides, 17 pt; an optional value in grey, a check, a chevron.
struct ListRow: View {
    let label: String
    var value: String? = nil
    var valueIsHint = false
    var checked = false
    var chevron = false
    var labelColor: Color = Theme.ink

    var body: some View {
        HStack(spacing: 12) {
            Text(label).foregroundStyle(labelColor).frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value).monospacedDigit().foregroundStyle(valueIsHint ? Theme.ink3 : Theme.ink2)
            }
            if checked { Text("✓").font(Theme.text(19)) }
            if chevron { Text("›").font(Theme.text(15)).foregroundStyle(Theme.ink3) }
        }
        .font(Theme.text(17))
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// An option with its icon and an optional tag ("FASTEST"), like the prototype's chooser rows.
struct OptionRow: View {
    let title: String
    let icon: ProtoIcon.Kind
    var tag: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Rectangle().fill(icon == .keys ? Color.clear : Theme.ink)
                ProtoIcon(kind: icon).frame(width: 19, height: 19).foregroundStyle(icon == .keys ? Theme.ink : Theme.paper)
            }
            .frame(width: 34, height: 34)
            Text(title).font(Theme.display(17)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
            if let tag {
                Text(tag.uppercased())
                    .font(Theme.display(11))
                    .tracking(0.66)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.selected)
            }
            Text("›").font(Theme.text(17)).foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .foregroundStyle(Theme.ink)
        .contentShape(Rectangle())
    }
}

/// Kilograms | Pounds, like the prototype's segmented control: the picked side a white pill with a soft shadow.
struct Segmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                let on = option.0 == selection
                Button { selection = option.0 } label: {
                    Text(option.1)
                        .font(on ? Theme.text(13) : .custom("SpaceGrotesk-Medium", size: 13))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 7).fill(on ? Theme.paper : .clear)
                            .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 4, y: 3))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .frame(height: 32)
    }
}

// MARK: - Icons

/// The prototype's line icons, drawn from its SVG paths on a 24-point grid.
struct ProtoIcon: View {
    enum Kind { case back, photo, camera, keys, train, prs, gym, history, plates }
    let kind: Kind

    var body: some View {
        Canvas { context, size in
            let s = size.width / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            var path = Path()
            var width: CGFloat = 2
            switch kind {
            case .back:
                width = 2.4
                path.move(to: p(20, 12)); path.addLine(to: p(4.5, 12))
                path.move(to: p(10.5, 5.5)); path.addLine(to: p(4, 12)); path.addLine(to: p(10.5, 18.5))
            case .photo:
                width = 1.9
                path.addRoundedRect(in: CGRect(origin: p(3, 5), size: CGSize(width: 18 * s, height: 14 * s)), cornerSize: CGSize(width: 3 * s, height: 3 * s))
                path.addEllipse(in: CGRect(origin: p(7.4, 8.4), size: CGSize(width: 3.2 * s, height: 3.2 * s)))
                path.move(to: p(4, 17)); path.addLine(to: p(9, 12.5)); path.addLine(to: p(12.5, 15.5)); path.addLine(to: p(15.5, 13)); path.addLine(to: p(20, 17))
            case .camera:
                width = 1.9
                path.move(to: p(4, 8)); path.addLine(to: p(7, 8)); path.addLine(to: p(8.6, 5.8)); path.addLine(to: p(15.4, 5.8))
                path.addLine(to: p(17, 8)); path.addLine(to: p(20, 8)); path.addLine(to: p(20, 19)); path.addLine(to: p(4, 19)); path.closeSubpath()
                path.addEllipse(in: CGRect(origin: p(8.6, 9.8), size: CGSize(width: 6.8 * s, height: 6.8 * s)))
            case .keys:
                width = 1.9
                path.addRoundedRect(in: CGRect(origin: p(2.5, 6), size: CGSize(width: 19 * s, height: 12 * s)), cornerSize: CGSize(width: 2.5 * s, height: 2.5 * s))
                for x: CGFloat in [6, 9, 12, 15, 18] { path.move(to: p(x, 10)); path.addLine(to: p(x + 0.01, 10)) }
                path.move(to: p(7.5, 14)); path.addLine(to: p(16.5, 14))
            case .train:
                path.move(to: p(2, 12)); path.addLine(to: p(22, 12))
                for (x, h) in [(5, 4), (8, 6), (16, 6), (19, 4)] as [(CGFloat, CGFloat)] { path.move(to: p(x, 12 - h)); path.addLine(to: p(x, 12 + h)) }
            case .prs:
                path.move(to: p(8, 4)); path.addLine(to: p(16, 4)); path.addLine(to: p(16, 9))
                path.addArc(center: p(12, 9), radius: 4 * s, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
                path.closeSubpath()
                path.move(to: p(8, 6)); path.addLine(to: p(5, 6)); path.addQuadCurve(to: p(8, 10), control: p(5, 10))
                path.move(to: p(16, 6)); path.addLine(to: p(19, 6)); path.addQuadCurve(to: p(16, 10), control: p(19, 10))
                path.move(to: p(12, 13)); path.addLine(to: p(12, 17))
                path.move(to: p(8, 20)); path.addLine(to: p(16, 20))
            case .gym:
                path.move(to: p(3, 21)); path.addLine(to: p(3, 9)); path.addLine(to: p(12, 4)); path.addLine(to: p(21, 9)); path.addLine(to: p(21, 21))
                path.move(to: p(9, 21)); path.addLine(to: p(9, 15)); path.addLine(to: p(15, 15)); path.addLine(to: p(15, 21))
            case .history:
                path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: 18 * s, height: 18 * s)))
                path.move(to: p(12, 7)); path.addLine(to: p(12, 12)); path.addLine(to: p(15.5, 14))
            case .plates:
                width = 2.2
                path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: 18 * s, height: 18 * s)))
                path.addEllipse(in: CGRect(origin: p(9.5, 9.5), size: CGSize(width: 5 * s, height: 5 * s)))
            }
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: width * s, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

extension Color {
    /// "#D3262E" → Color.
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
