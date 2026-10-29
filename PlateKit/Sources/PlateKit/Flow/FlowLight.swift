import Foundation

/// The Flow's colours (HANDOFF 1, "Look").
public enum FlowLook {
    /// Question screens, the menu and the scale.
    public static let orange = RGB(hex: "#FF6200")
    /// The kit and sets background, the whiteboard, the gym room's walls, ink on orange.
    public static let light = RGB(hex: "#F0E2F3")
    /// Ink on light: text, cards, chips, buttons, the notebook cover, the board frame.
    public static let dark = RGB(hex: "#6C3713")
    /// Dust from impacts.
    public static let dust = RGB(hex: "#E9E2D6")
    /// A plate you don't have: grey and see-through. The prototype's grey at 30 % comes out #B85C22 over the
    /// orange once lit; this flat grey gives the same.
    public static let missing = RGB(hex: "#4F4F4F")
    public static let missingOpacity: Float = 0.4
    /// The abduction's beam as the prototype shows it once its sketch pass has run: a grainy haze that mutes the
    /// orange (its additive white mostly lands in the bell it takes). Each wall of the beam at most this opaque.
    public static let beam = RGB(hex: "#70808C")
    public static let beamOpacity: Float = 0.163
    /// What the beam washes the bell it takes towards.
    public static let wash = RGB(hex: "#BEB4B2")
}

/// The prototype's light, worked out per face so RealityKit can draw exact flat colours (unlit, no tone
/// mapping). three.js r169: a hemisphere light (sky white, ground #8A7A70, 2.2) and a sun (1.6 from
/// (2.5, 6, 4)); `MeshToonMaterial` with a 3-step ramp for the props, `MeshStandardMaterial` for plates and bars.
public enum FlowLight {
    /// Towards the sun.
    public static let sun = SIMD3<Float>(2.5, 6, 4).normalized
    public static let sunIntensity: Float = 1.6
    public static let hemisphere: Float = 2.2
    static let ground = RGB(hex: "#8A7A70").linear
    static let sky = SIMD3<Float>(1, 1, 1)

    /// The toon ramp: a 3-texel gradient map (90, 175, 255), nearest-sampled at dot × 0.5 + 0.5.
    public static func rampStep(dot: Float) -> Float {
        let coordinate = dot * 0.5 + 0.5
        switch min(2, max(0, Int((coordinate * 3).rounded(.down)))) {
        case 0: return 90.0 / 255
        case 1: return 175.0 / 255
        default: return 1
        }
    }

    /// The light falling on a face facing `normal` (world space), for a white surface: what three.js multiplies
    /// the diffuse colour by, before 1/π.
    static func hemisphereIrradiance(_ normal: SIMD3<Float>) -> SIMD3<Float> {
        let weight = 0.5 * normal.y + 0.5
        return (ground + (sky - ground) * weight) * hemisphere
    }

    /// A toon prop's face. `shine` (0…1) is the prototype's flShine: emissive pulled toward white.
    public static func toon(_ base: RGB, normal: SIMD3<Float>, shine: Float = 0) -> RGB {
        let n = normal.normalized
        let irradiance = hemisphereIrradiance(n) + SIMD3(repeating: sunIntensity * rampStep(dot: n.dot(sun)))
        return finish(base.linear * irradiance / Float.pi, shine: shine)
    }

    /// A standard (physically based) face: Lambert diffuse for what isn't metal. The prototype has no environment
    /// map, so metal reflects next to nothing: a chrome hub reads black, a steel bar dark grey (its 10 % diffuse).
    public static func standard(_ base: RGB, normal: SIMD3<Float>, roughness: Float, metalness: Float, shine: Float = 0) -> RGB {
        let n = normal.normalized
        let lit = max(0, n.dot(sun))
        let diffuse = base.linear * (1 - metalness) * (hemisphereIrradiance(n) + SIMD3(repeating: sunIntensity * lit)) / Float.pi
        return finish(diffuse, shine: shine)
    }

    /// The tint for a printed face: the light on a white surface, as a colour (clamped to 1).
    public static func tint(normal: SIMD3<Float>, toon: Bool, shine: Float = 0) -> RGB {
        toon ? Self.toon(RGB(1, 1, 1), normal: normal, shine: shine)
             : standard(RGB(1, 1, 1), normal: normal, roughness: 0.5, metalness: 0, shine: shine)
    }

    static func finish(_ linear: SIMD3<Float>, shine: Float) -> RGB {
        // Shine: the emissive goes from black toward white by 0.45 k at intensity 1 + 0.3 k, added on top.
        let lit = linear + SIMD3(repeating: 0.45 * shine * (1 + 0.3 * shine))
        return RGB(linear: SIMD3(min(1, max(0, lit.x)), min(1, max(0, lit.y)), min(1, max(0, lit.z))))
    }
}

/// The physics of every drop and drag (HANDOFF 1, prototype `PHYS`).
public enum FlowPhysics {
    public static let gravity: Float = 9.81
    public static let solverIterations = 20
    public static let tolerance: Float = 0.0005
    /// Plate on the ground.
    public static let groundFriction: Float = 0.55, groundRestitution: Float = 0.2
    /// Plate on plate.
    public static let plateFriction: Float = 0.35, plateRestitution: Float = 0.12
    public static let linearDamping: Float = 0.03, angularDamping: Float = 0.06
    public static let sleepSpeed: Float = 0.06, sleepTime: Float = 0.8
    /// The hand: a spring pulling the grabbed point to the finger.
    public static let grabStiffness: Float = 260, grabDamping: Float = 0.85, grabMaxForce: Float = 140, grabAngularDamping: Float = 0.45
    /// Screen shake = trauma² × this.
    public static let shake: Float = 0.1
    public static let dustAmount: Float = 0.05, dustSize: Float = 0.2, dustLinger: Float = 0.24, dustSpread: Float = 0.05
    public static let dustRise: Float = 0.94, dustMinImpact: Float = 1.2
    public static let dustSizes: ClosedRange<Float> = 0.05...0.11, dustLives: ClosedRange<Float> = 0.9...1.7
    public static let dustCount: Float = 0.45
}
