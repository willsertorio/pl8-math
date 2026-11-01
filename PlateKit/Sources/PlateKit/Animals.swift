import Foundation

/// "You lifted a lion." — the prototype's session-over message (reference/prototype-app-logic.js ANIMALS and
/// animalFor): the animal whose weight is nearest on a log scale.
public enum Animals {
    /// Weight in kg, and the animal with its article.
    public static let list: [(kg: Double, name: String)] = [
        (4.5, "a house cat"), (10, "a beagle"), (30, "a golden retriever"), (45, "a wolf"), (85, "a kangaroo"),
        (110, "a giant panda"), (180, "a lion"), (210, "a gorilla"), (300, "a grizzly bear"), (450, "a polar bear"),
        (550, "a horse"), (650, "a moose"), (900, "a bison"), (1200, "a giraffe"), (1800, "a hippo"), (2300, "a rhino"),
        (6000, "an elephant"), (8000, "a T. rex"), (30000, "a humpback whale"), (150000, "a blue whale"),
    ]

    public static func nearest(kg: Double) -> (kg: Double, name: String) {
        guard kg > 0 else { return (0, "a feather") }
        return list.min { abs(log(kg / $0.kg)) < abs(log(kg / $1.kg)) }!
    }

    /// A weight in the gym's unit, weighed in kilos.
    public static func nearest(_ value: Double, unit: WeightUnit) -> (kg: Double, name: String) {
        nearest(kg: unit == .lb ? value * 0.4536 : value)
    }

    public static func message(for value: Double, unit: WeightUnit) -> String {
        "You lifted \(nearest(value, unit: unit).name)."
    }
}
