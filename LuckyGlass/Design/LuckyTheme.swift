import SwiftUI
import UIKit

/// The design language for LuckyGlass.
///
/// The app uses a crisp operations-console aesthetic: neutral canvases, compact surfaces and
/// saturated semantic colours. Colour is concentrated in controls and icon plates, which keeps
/// dense status screens easy to scan in both appearances.
///
/// Everything here is a token. Screens must not hard-code colours, radii or durations — a value
/// that appears twice belongs in this file.
enum LuckyTheme {
    // MARK: - Palette

    /// Light/dark pairs without an asset catalog. `UIColor`'s dynamic provider is resolved per
    /// trait collection, so a single `Color` adapts to appearance, Increase Contrast and vibrancy.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }

    static let accent = dynamic(light: 0x1769E0, dark: 0x4D92F7)
    static let accentSoft = dynamic(light: 0xE7F0FF, dark: 0x172A46)
    static let success = dynamic(light: 0x16865A, dark: 0x2FC98A)
    static let successSoft = dynamic(light: 0xE4F6EE, dark: 0x15372B)
    static let warning = dynamic(light: 0xC06A00, dark: 0xF2A62B)
    static let warningSoft = dynamic(light: 0xFFF1D7, dark: 0x3D2D14)
    static let danger = dynamic(light: 0xD33C58, dark: 0xFF6F85)
    static let dangerSoft = dynamic(light: 0xFFE8EC, dark: 0x43212A)
    static let info = dynamic(light: 0x007E9E, dark: 0x35BDD5)
    static let infoSoft = dynamic(light: 0xE0F5F8, dark: 0x15343B)
    static let idle = dynamic(light: 0x536071, dark: 0x8E9AAA)
    static let idleSoft = dynamic(light: 0xE9EDF2, dark: 0x29313B)

    // MARK: - Backdrop and surfaces

    static let canvasTop = dynamic(light: 0xF3F5F8, dark: 0x0D1117)

    /// Content-layer card fill. Nearly opaque — cards live *under* the glass chrome and must never
    /// be glass themselves.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x171C24)
    /// A second level for rows nested inside a card.
    static let surfaceRaised = dynamic(light: 0xF1F4F8, dark: 0x202731)
    /// Code, JSON and log backgrounds.
    static let surfaceSunken = dynamic(light: 0xE9EDF3, dark: 0x0B1016)
    static let hairline = dynamic(light: 0xD9DEE7, dark: 0x303947)
    static let separator = dynamic(light: 0xE7EAF0, dark: 0x29313C)
    static let surfaceHighlight = dynamic(light: 0xFFFFFF, dark: 0x26303D)

    static let textPrimary = dynamic(light: 0x151A23, dark: 0xF4F6F8)
    static let textSecondary = dynamic(light: 0x4F5A69, dark: 0xADB7C5)
    static let textTertiary = dynamic(light: 0x788393, dark: 0x778393)
    /// Text on top of a filled accent surface.
    static let textOnAccent = Color.white

    // MARK: - Radii

    /// Corner radii, outermost first. Concentric corners require the inner radius to be the outer
    /// radius minus the padding between them, which `ConcentricRectangle` derives from the
    /// container shape — these constants are the *outer* values.
    enum Radius {
        static let hero: CGFloat = 28
        static let card: CGFloat = 20
        static let panel: CGFloat = 16
        static let row: CGFloat = 14
        static let chip: CGFloat = 10
        static let field: CGFloat = 14
        /// Floor passed to `.concentric(minimum:)` so a nested corner never collapses to a square.
        static let concentricFloor: CGFloat = 8
    }

    // MARK: - Spacing

    enum Space {
        static let hair: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Page side margin. Also the spacing handed to `GlassEffectContainer`, which uses it to
        /// decide how close two glass shapes must be before their fields merge.
        static let gutter: CGFloat = 20
        /// Vertical rhythm between repeated records in a scroll view.
        static let stack: CGFloat = 16
        /// Inner padding of a card, and therefore the concentric inset of anything drawn inside
        /// one.
        static let cardInset: CGFloat = 16
        /// Distinguish space between sections from space inside a card.
        static let section: CGFloat = 20
        static let pageTop: CGFloat = 12
        /// Additional breathing room inside the system's tab/action-bar safe area.
        static let pageBottom: CGFloat = 32
        static let touchTarget: CGFloat = 44
    }

    // MARK: - Typography

    /// A compact system face keeps dense labels quiet; code and paths retain a monospaced face.
    /// Numerics and display sizes use `.rounded` so digits feel warmer and less mechanical at
    /// large scale — the difference is most obvious in metric tiles and the page hero.
    enum Text {
        static let hero = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 21, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 13, weight: .bold, design: .default)
        static let cardTitle = Font.system(size: 16, weight: .semibold, design: .default)
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 12, weight: .semibold, design: .default)
        static let label = Font.system(size: 13, weight: .medium, design: .default)
        /// The big number in a metric tile — `.rounded` so the numeral feels at home beside the
        /// icon tile rather than technical. `.monospacedDigit()` is still applied at the call site.
        static let metric = Font.system(size: 26, weight: .bold, design: .rounded)
        static let metricSmall = Font.system(size: 19, weight: .bold, design: .rounded)
        /// JSON, logs and paths. Monospaced digits alone are not enough — these need fixed advance.
        static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let codeSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
        static let button = Font.system(size: 15, weight: .semibold, design: .rounded)
    }

    // MARK: - Motion

    /// Glass morphing (`glassEffectID`) only interpolates inside `withAnimation`, so these are the
    /// durations the whole app shares. Anything faster than `.snap` reads as a glitch on a shape
    /// that is also refracting its backdrop.
    enum Motion {
        /// Selection changes, chips, toggles.
        static let snap = Animation.snappy(duration: 0.26, extraBounce: 0.02)
        /// Glass shapes merging or splitting.
        static let morph = Animation.smooth(duration: 0.38)
        /// Cards appearing after a load.
        static let reveal = Animation.smooth(duration: 0.3)
        /// The status pulse on a live dot.
        static let pulse = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
    }

    /// Hairline width. `1 / displayScale` would be crisper but reads as a hard line against glass,
    /// so the port uses a full point at low opacity instead.
    static let strokeWidth: CGFloat = 1
}

extension UIColor {
    /// `0xRRGGBB` → opaque colour, in the sRGB (device) space so the hex matches the design values.
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
