import Foundation

/// Kilograms or pounds (SPEC 3.2).
public enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case kg
    case lb

    /// 1 kg = 2.2046226218 lb.
    public static let poundsPerKilogram = 2.2046226218

    /// Converts `value` from this unit to `unit` with full precision. Round only for display.
    public func convert(_ value: Double, to unit: WeightUnit) -> Double {
        switch (self, unit) {
        case (.kg, .lb): value * Self.poundsPerKilogram
        case (.lb, .kg): value / Self.poundsPerKilogram
        default: value
        }
    }

    /// Text for a total in this unit, shown in `unit` (usually the PR's unit).
    /// Converted totals get 1 decimal ("77.1 kg"); same-unit totals drop trailing zeros ("170 lb", "62.5 kg").
    public func display(_ value: Double, in unit: WeightUnit) -> String {
        if unit == self {
            return "\(Self.trimmed(value)) \(unit.rawValue)"
        }
        return String(format: "%.1f %@", convert(value, to: unit), unit.rawValue)
    }

    /// "170", "62.5", "1.25" — up to 2 decimals, no trailing zeros.
    public static func trimmed(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
