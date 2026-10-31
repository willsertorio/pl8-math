import Foundation

/// A colour, sRGB, 0…1 per channel.
public struct RGB: Hashable, Sendable {
    public var r: Float, g: Float, b: Float

    public init(_ r: Float, _ g: Float, _ b: Float) {
        self.r = r; self.g = g; self.b = b
    }

    /// "#RRGGBB".
    public init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(Float((value >> 16) & 0xFF) / 255, Float((value >> 8) & 0xFF) / 255, Float(value & 0xFF) / 255)
    }

    public var hex: String {
        let channel = { (v: Float) -> String in
            let byte = Int((min(1, max(0, v)) * 255).rounded())
            return String(byte, radix: 16, uppercase: true).count == 1 ? "0" + String(byte, radix: 16, uppercase: true)
                                                                        : String(byte, radix: 16, uppercase: true)
        }
        return "#" + channel(r) + channel(g) + channel(b)
    }

    /// Linear light, as the renderer does its maths in.
    public var linear: SIMD3<Float> { SIMD3(Self.toLinear(r), Self.toLinear(g), Self.toLinear(b)) }

    public init(linear: SIMD3<Float>) {
        self.init(Self.toSRGB(linear.x), Self.toSRGB(linear.y), Self.toSRGB(linear.z))
    }

    /// The same colour, `amount` (0…1) lighter or darker in HSL lightness (three.js `offsetHSL(0, 0, amount)`).
    public func offsetLightness(_ amount: Float) -> RGB {
        let maxC = max(r, g, b), minC = min(r, g, b), l = (maxC + minC) / 2
        var h: Float = 0, s: Float = 0
        if maxC != minC {
            let d = maxC - minC
            s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
            if maxC == r { h = (g - b) / d + (g < b ? 6 : 0) } else if maxC == g { h = (b - r) / d + 2 } else { h = (r - g) / d + 4 }
            h /= 6
        }
        return RGB(hue: h, saturation: s, lightness: min(1, max(0, l + amount)))
    }

    init(hue h: Float, saturation s: Float, lightness l: Float) {
        guard s > 0 else { self.init(l, l, l); return }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q
        func channel(_ t0: Float) -> Float {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        self.init(channel(h + 1.0 / 3), channel(h), channel(h - 1.0 / 3))
    }

    static func toLinear(_ c: Float) -> Float {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func toSRGB(_ c: Float) -> Float {
        let v = min(1, max(0, c))
        return v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055
    }
}

/// The prototype's look, copied from reference/prototype-app-logic.js (initScene, syncArt, sceneLook) with Will's
/// palette (scene-layout-and-look.json): white things are drawn in box light, black things in box dark, lit by a
/// hemisphere sky of 2.7 and one sun of 1.5 from (−8, 20, 12), no tone mapping. Baking that maths into flat colours
/// gives the phone the prototype's exact colours.
public enum Look {
    public static let boxLight = RGB(hex: "#F0E2F3")
    public static let boxDark = RGB(hex: "#6C3713")
    public static let background = RGB(hex: "#FF6200")
    /// The ink lines (the prototype's LineBasicMaterial and sketch line), unlit.
    public static let ink = boxDark

    /// The prototype's animation scenes (the title, the session-over scale, the loader) are two-tone: everything
    /// posterized to the theme's dark or light by its brightness, after its grade (contrast 0.71, then brightness
    /// 0.68), so only what's brighter than about 0.83 comes out light.
    public static func duotone(_ colour: RGB) -> RGB {
        let brightness = 0.299 * colour.r + 0.587 * colour.g + 0.114 * colour.b
        return ((brightness - 0.5) * 0.71 + 0.5) * 0.68 >= 0.5 ? duotoneLight : duotoneDark
    }

    public static var duotoneLight: RGB { FlowLook.light }
    public static var duotoneDark: RGB { FlowLook.dark }

    /// The animation scenes' light (the prototype's AnimLayer): a white hemisphere of 2.7 and a 1.5 sun from
    /// (2, 6.46, 3) (sunA 60°), on toon materials whose ramp has three steps (70, 160, 255). How much light a face
    /// with this normal gets (three.js: albedo / π × this, in linear light).
    public static func animationLight(normal: SIMD3<Float>) -> Float {
        let towardsSun = SIMD3<Float>(2, 4 * sin(Float.pi / 3) + 3, 3), ramp: [Float] = [70 / 255, 160 / 255, 1]
        let u = normal.dot(towardsSun) / (normal.dot(normal) * towardsSun.dot(towardsSun)).squareRoot() * 0.5 + 0.5
        return (ambient + sunIntensity * ramp[min(2, max(0, Int(u * 3)))]) / .pi
    }

    public static let ambient: Float = 2.7
    public static let sunIntensity: Float = 1.5
    /// How finely the sun's angle is stepped: each step is one flat colour.
    public static let sunSteps = 8

    /// three.js Lambert: albedo / π × (sky + sun × max(0, n·l)), in linear light, clamped.
    public static func lit(_ albedo: RGB, sun: Float) -> RGB {
        let light = (ambient + sunIntensity * max(0, sun)) / Float.pi
        return RGB(linear: albedo.linear * light)
    }

    /// The step (0 … `sunSteps`) of sun a face with this normal gets.
    public static func sunStep(normal: SIMD3<Float>) -> Int {
        Int((max(0, normal.dot(Sunlight.towardsSun)) * Float(sunSteps)).rounded())
    }

    public static func sun(step: Int) -> Float { Float(step) / Float(sunSteps) }
}
