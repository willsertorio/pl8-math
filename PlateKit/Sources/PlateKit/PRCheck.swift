/// "How much did you lift?" and "New PR!" (SPEC 2.3 step 6, 3.8).
public enum PRCheck {
    /// Ask after the last set of each lift, and after any "plus" set (it may go heavier).
    public static func asksWhatWasLifted(isLastOfLift: Bool, isWarmUp: Bool, pctText: String) -> Bool {
        !isWarmUp && (isLastOfLift || pctText.hasSuffix("+"))
    }

    /// What was lifted, converted to the PR's unit, when it beats the PR (or there's no PR yet). Full precision.
    public static func newPR(lifted: Double, in unit: WeightUnit, pr: Double?, prUnit: WeightUnit) -> Double? {
        let value = unit.convert(lifted, to: prUnit)
        guard value > 0, value > (pr ?? 0) + 1e-9 else { return nil }
        return value
    }
}
