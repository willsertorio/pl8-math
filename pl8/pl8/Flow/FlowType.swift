import SwiftUI
import UIKit

/// The Flow's type (CHANGES-v2 §1): Helvetica Neue, five roles. Handwriting on the board and the notebook stays
/// Permanent Marker; the opening's title and the scale's message stay as the prototype draws them.
enum FlowType {
    static let medium = "HelveticaNeue-Medium"
    static let regular = "HelveticaNeue"

    /// Questions and set titles: 500 / 33, −0.035 em, line height 1.02.
    static let displaySize: CGFloat = 33
    static let displayTracking: CGFloat = -0.035 * displaySize
    static let displayLineHeight: CGFloat = 1.02 * displaySize
    static var display: Font { .custom(medium, size: displaySize) }
    static var displayUIFont: UIFont { UIFont(name: medium, size: displaySize) ?? .systemFont(ofSize: displaySize, weight: .medium) }

    /// Labels under 3D objects, menu items, bar weights, plate rows: 500 / 21, −0.02 em.
    static func label(_ size: CGFloat = 21) -> Font { .custom(medium, size: size) }
    static func labelTracking(_ size: CGFloat = 21) -> CGFloat { -0.02 * size }

    /// Cards, chips, buttons, set info: 400 / 17 (chips 16), −0.01 em.
    static func body(_ size: CGFloat = 17) -> Font { .custom(regular, size: size) }
    static func bodyTracking(_ size: CGFloat = 17) -> CGFloat { -0.01 * size }

    /// YES / NO and the cards' overlines: 500 / 12, +0.04 em, all caps.
    static var smallCaps: Font { .custom(medium, size: 12) }
    static let smallCapsTracking: CGFloat = 0.04 * 12

    /// Text drawn into the 3D (dials, the PR dial, KG / LB, the gym's box and flag): Helvetica Neue Medium.
    static func uiMedium(_ size: CGFloat) -> UIFont { UIFont(name: medium, size: size) ?? .systemFont(ofSize: size, weight: .medium) }
}
