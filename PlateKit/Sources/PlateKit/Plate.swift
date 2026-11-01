import Foundation

/// One plate size and how it looks (SPEC 3.1).
public struct Plate: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case bumper
        case change
    }

    public let size: Double
    public let unit: WeightUnit
    public let colorHex: String
    /// Metres.
    public let diameter: Double
    /// Metres.
    public let thickness: Double
    public let kind: Kind

    /// Every plate size of `unit`, heaviest first.
    public static func catalog(_ unit: WeightUnit) -> [Plate] {
        switch unit {
        case .kg: kilogramPlates
        case .lb: poundPlates
        }
    }

    /// The plate of this size and unit, or nil if no such plate exists.
    public static func find(_ size: Double, _ unit: WeightUnit) -> Plate? {
        catalog(unit).first { $0.size == size }
    }
}

private enum PlateColor {
    static let red = "#D3262E"
    static let blue = "#1E5BC6"
    static let yellow = "#F3C318"
    static let green = "#2E8A4B"
    static let white = "#F2F2EE"
    static let iron = "#26282C"
}

private let kilogramPlates: [Plate] = [
    Plate(size: 25, unit: .kg, colorHex: PlateColor.red, diameter: 0.450, thickness: 0.056, kind: .bumper),
    Plate(size: 20, unit: .kg, colorHex: PlateColor.blue, diameter: 0.450, thickness: 0.046, kind: .bumper),
    Plate(size: 15, unit: .kg, colorHex: PlateColor.yellow, diameter: 0.450, thickness: 0.036, kind: .bumper),
    Plate(size: 10, unit: .kg, colorHex: PlateColor.green, diameter: 0.450, thickness: 0.027, kind: .bumper),
    Plate(size: 5, unit: .kg, colorHex: PlateColor.white, diameter: 0.230, thickness: 0.024, kind: .change),
    Plate(size: 2.5, unit: .kg, colorHex: PlateColor.red, diameter: 0.190, thickness: 0.019, kind: .change),
    Plate(size: 2, unit: .kg, colorHex: PlateColor.blue, diameter: 0.175, thickness: 0.017, kind: .change),
    Plate(size: 1.5, unit: .kg, colorHex: PlateColor.yellow, diameter: 0.160, thickness: 0.015, kind: .change),
    Plate(size: 1, unit: .kg, colorHex: PlateColor.green, diameter: 0.150, thickness: 0.013, kind: .change),
    Plate(size: 0.5, unit: .kg, colorHex: PlateColor.white, diameter: 0.135, thickness: 0.011, kind: .change),
]

private let poundPlates: [Plate] = [
    Plate(size: 55, unit: .lb, colorHex: PlateColor.red, diameter: 0.450, thickness: 0.058, kind: .bumper),
    Plate(size: 45, unit: .lb, colorHex: PlateColor.blue, diameter: 0.450, thickness: 0.050, kind: .bumper),
    Plate(size: 35, unit: .lb, colorHex: PlateColor.yellow, diameter: 0.450, thickness: 0.040, kind: .bumper),
    Plate(size: 25, unit: .lb, colorHex: PlateColor.green, diameter: 0.450, thickness: 0.030, kind: .bumper),
    Plate(size: 15, unit: .lb, colorHex: PlateColor.white, diameter: 0.300, thickness: 0.026, kind: .change),
    Plate(size: 10, unit: .lb, colorHex: PlateColor.iron, diameter: 0.250, thickness: 0.024, kind: .change),
    Plate(size: 5, unit: .lb, colorHex: PlateColor.iron, diameter: 0.205, thickness: 0.020, kind: .change),
    Plate(size: 2.5, unit: .lb, colorHex: PlateColor.iron, diameter: 0.165, thickness: 0.016, kind: .change),
]

/// Bar weights a gym can pick (SPEC 3.1). Collars are ignored.
public enum Bar {
    public static func weights(_ unit: WeightUnit) -> [Double] {
        switch unit {
        case .kg: [20, 15, 10]
        case .lb: [45, 35, 15]
        }
    }

    /// "20 Olympic · 15 Women's Olympic · 10 Technique" (SPEC 2.2). Pound bars have no names.
    public static func name(_ weight: Double, _ unit: WeightUnit) -> String? {
        guard unit == .kg else { return nil }
        return [20: "Olympic", 15: "Women's Olympic", 10: "Technique"][weight]
    }
}

/// What the plate math needs to know about a gym: its unit, which plate sizes it has, and its bar.
public struct GymSetup: Hashable, Sendable {
    public let unit: WeightUnit
    /// Heaviest first, no duplicates. A gym stores which sizes it has, not how many.
    public let plateSizes: [Double]
    public let barWeight: Double

    /// Longest gym name: it has to fit on the flag.
    public static let maxNameLength = 8

    /// Gym names are uppercase, up to 8 characters (SPEC 2.2).
    public static func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces).uppercased()
        return String(trimmed.prefix(maxNameLength)).trimmingCharacters(in: .whitespaces)
    }

    /// Defaults: every plate size of the unit and the unit's heaviest bar.
    public init(unit: WeightUnit, plateSizes: [Double]? = nil, barWeight: Double? = nil) {
        self.unit = unit
        let sizes = plateSizes ?? Plate.catalog(unit).map(\.size)
        self.plateSizes = Array(Set(sizes)).sorted(by: >)
        self.barWeight = barWeight ?? Bar.weights(unit)[0]
    }
}
