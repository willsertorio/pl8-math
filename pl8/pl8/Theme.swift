import SwiftUI

/// The look from SPEC 2.5 / reference/scene-layout-and-look.json (uiLook), with the system font for now.
enum Theme {
    /// Flat orange behind everything (#FF6200).
    static let background = Color(red: 1, green: 0x62 / 255, blue: 0)
    static let ink = Color.black
    static let paper = Color.white

    /// Headings: 25 pt bold (Space Grotesk 700 later).
    static let heading = Font.system(size: 25, weight: .bold)
    /// Small uppercase section labels.
    static let label = Font.system(size: 13, weight: .bold)
}

/// Solid black, square buttons: 40 pt, or 56 pt for the big ones.
struct BlackButtonStyle: ButtonStyle {
    var big = false

    func makeBody(configuration: Configuration) -> some View {
        BlackButton(configuration: configuration, big: big)
    }

    private struct BlackButton: View {
        let configuration: ButtonStyleConfiguration
        let big: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: big ? 20 : 17, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .frame(maxWidth: .infinity)
                .frame(height: big ? 56 : 40)
                .background(Theme.ink.opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.3))
                .contentShape(Rectangle())
        }
    }
}

extension ButtonStyle where Self == BlackButtonStyle {
    static var black: BlackButtonStyle { BlackButtonStyle() }
    static var bigBlack: BlackButtonStyle { BlackButtonStyle(big: true) }
}

/// Outlined fields: 56 pt tall, 14 pt corners, 24 pt text.
struct OutlineFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 24, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(height: 56)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: 2))
    }
}

extension View {
    /// A drawer/card: white, square corners, 2 pt black border.
    func drawer() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper)
            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
    }

    /// Small uppercase label above a group of controls.
    func sectionLabel() -> some View {
        self.font(Theme.label).textCase(.uppercase)
    }
}

/// A selectable chip: black when on, outlined when off.
struct Chip<Content: View>: View {
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .frame(maxWidth: .infinity)
                .foregroundStyle(isOn ? Theme.paper : Theme.ink)
                .background(isOn ? Theme.ink : Theme.paper)
                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
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
