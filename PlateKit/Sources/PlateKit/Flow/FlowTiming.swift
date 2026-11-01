import Foundation

/// The Flow's question text (HANDOFF 1, prototype flSay): words appear one by one with no fade, at a spoken pace.
public enum FlowText {
    public struct Word: Hashable, Sendable {
        public let word: String
        /// Seconds after the question starts.
        public let at: Double
    }

    /// When each word shows, and `total`: when the sentence is done and the screen's object may come in.
    /// Per word 95 ms + 18 ms per letter; +230 ms after `, ; :`, +420 ms after `. ? ! …`; 120 ms at the end.
    public static func schedule(_ text: String) -> (words: [Word], total: Double) {
        var time = 0.0
        var words: [Word] = []
        for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            words.append(Word(word: word, at: time))
            time += 0.095 + 0.018 * Double(letters(in: word))
            if let last = word.last {
                if ",;:".contains(last) { time += 0.23 }
                if ".?!…".contains(last) { time += 0.42 }
            }
        }
        return (words, time + 0.12)
    }

    /// The prototype counts `[\w’']`: ASCII letters, digits, underscore and apostrophes.
    static func letters(in word: String) -> Int {
        word.unicodeScalars.filter { scalar in
            ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) || ("0"..."9").contains(scalar)
                || scalar == "_" || scalar == "’" || scalar == "'"
        }.count
    }
}

/// The pan between questions (HANDOFF 1, prototype flPanTo / flGo): the camera moves straight down one screen;
/// what's on screen slides up and the next screen comes up from below.
public enum FlowPan {
    public static let outDuration = 0.30
    public static let inDuration = 0.45
    /// A swipe back to the menu commits past this many points (flPanBackBind).
    public static let commitDistance = 110.0
    /// A drag must go this far up before it starts following the finger.
    public static let startDistance = 14.0
    public static let springBackDuration = 0.28

    /// Leaving: how far the old screen has moved up, in screen heights (ease-in quad).
    public static func out(_ u: Double) -> Double { u * u }

    /// Arriving: where the new screen is, in screen heights (−1 = one screen below), ease-out cubic.
    public static func into(_ u: Double) -> Double { -pow(1 - u, 3) }

    public static func commits(dragged: Double) -> Bool { dragged > commitDistance }

    /// Letting go before the threshold: back to rest with an ease-out.
    public static func springBack(from start: Double, at u: Double) -> Double { start * pow(1 - u, 3) }

    /// After committing a finger drag of `start` points: the rest of the way (prototype flPanFinish).
    public static func finish(from start: Double, height: Double, at u: Double) -> Double {
        start + (height - start) * u * (2 - u) * 0.5 + (height - start) * u * u * 0.5
    }

    public static func finishDuration(from start: Double, height: Double) -> Double {
        max(0.12, 0.3 * (1 - start / height))
    }
}

/// The prototype's easing curves.
public enum Ease {
    public static func outCubic(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3) }
    public static func outQuart(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 4) }
    public static func inOutCubic(_ x: Double) -> Double {
        let u = clamp(x)
        return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
    }
    public static func inOutQuad(_ x: Double) -> Double {
        let u = clamp(x)
        return u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2
    }
    public static func smoothstep(_ x: Double) -> Double {
        let u = clamp(x)
        return u * u * (3 - 2 * u)
    }
    /// Overshoots and settles (prototype outBack, k 1.8 by default).
    public static func outBack(_ x: Double, _ k: Double = 1.8) -> Double {
        let u = clamp(x), c = k + 1
        return 1 + c * pow(u - 1, 3) + k * pow(u - 1, 2)
    }
    /// The CSS cubic-bezier(.2,.9,.25,1) the cards use, near enough: a strong ease-out.
    public static func card(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3.6) }

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
