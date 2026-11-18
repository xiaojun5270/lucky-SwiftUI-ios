import SwiftUI
import UIKit

/// The design language for LuckyGlass.
///
/// Native grouped surfaces, generous section spacing and restrained semantic colour.
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

    static let accent = dynamic(light: 0x3267D6, dark: 0x8CB1FF)
    static let accentSoft = dynamic(light: 0xEBF1FE, dark: 0x1D2C47)
    static let success = dynamic(light: 0x13744E, dark: 0x2FC98A)
    static let successSoft = dynamic(light: 0xE4F6EE, dark: 0x15372B)
    static let warning = dynamic(light: 0x995700, dark: 0xF2A62B)
    static let warningSoft = dynamic(light: 0xFFF1D7, dark: 0x3D2D14)
    static let danger = dynamic(light: 0xB82D48, dark: 0xFF6F85)
    static let dangerSoft = dynamic(light: 0xFFE8EC, dark: 0x43212A)
    static let info = dynamic(light: 0x006A86, dark: 0x35BDD5)
    static let infoSoft = dynamic(light: 0xE0F5F8, dark: 0x15343B)
    static let idle = dynamic(light: 0x536071, dark: 0x8E9AAA)
    static let idleSoft = dynamic(light: 0xE9EDF2, dark: 0x29313B)

    // MARK: - Backdrop and surfaces

    static let canvasTop = dynamic(light: 0xF5F6F9, dark: 0x101114)

    /// Content-layer card fill. Nearly opaque — cards live *under* the glass chrome and must never
    /// be glass themselves.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1B1D22)
    /// A second level for rows nested inside a card.
    static let surfaceRaised = dynamic(light: 0xF5F6F9, dark: 0x25282F)
    /// Code, JSON and log backgrounds.
    static let surfaceSunken = dynamic(light: 0xF2F4F8, dark: 0x14161B)
    static let hairline = dynamic(light: 0xDFE3EB, dark: 0x363A44)
    static let separator = dynamic(light: 0xECEEF3, dark: 0x2C3038)
    static let surfaceHighlight = dynamic(light: 0xFFFFFF, dark: 0x26303D)

    static let textPrimary = dynamic(light: 0x151A23, dark: 0xF4F6F8)
    static let textSecondary = dynamic(light: 0x4F5A69, dark: 0xADB7C5)
    static let textTertiary = dynamic(light: 0x626E80, dark: 0x919CAB)
    /// Text on top of a filled accent surface.
    static let textOnAccent = dynamic(light: 0xFFFFFF, dark: 0x10213F)

    // MARK: - Radii

    /// Corner radii, outermost first. Concentric corners require the inner radius to be the outer
    /// radius minus the padding between them, which `ConcentricRectangle` derives from the
    /// container shape — these constants are the *outer* values.
    enum Radius {
        static let hero: CGFloat = 28
        static let card: CGFloat = 24
        static let panel: CGFloat = 18
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
        static let cardInset: CGFloat = 20
        /// Distinguish space between sections from space inside a card.
        static let section: CGFloat = 24
        static let pageTop: CGFloat = 20
        /// Additional breathing room inside the system's tab/action-bar safe area.
        static let pageBottom: CGFloat = 32
        static let touchTarget: CGFloat = 44
    }

    enum Layout {
        static let contentWidth: CGFloat = 1120
        static let formWidth: CGFloat = 520
        static let settingsWidth: CGFloat = 720
    }

    // MARK: - Typography

    /// A compact system face keeps dense labels quiet; code and paths retain a monospaced face.
    /// Numerics and display sizes use `.rounded` so digits feel warmer and less mechanical at
    /// large scale — the difference is most obvious in metric tiles and the page hero.
    enum Text {
        static let hero = Font.system(.largeTitle, design: .default).weight(.bold)
        static let title = Font.system(.title2, design: .default).weight(.bold)
        static let sectionTitle = Font.system(.subheadline).weight(.semibold)
        static let cardTitle = Font.system(.headline)
        static let body = Font.system(.subheadline)
        static let bodyMedium = Font.system(.subheadline).weight(.medium)
        static let caption = Font.system(.caption)
        static let captionMedium = Font.system(.caption).weight(.semibold)
        static let label = Font.system(.footnote).weight(.medium)
        /// The big number in a metric tile — `.rounded` so the numeral feels at home beside the
        /// icon tile rather than technical. `.monospacedDigit()` is still applied at the call site.
        static let metric = Font.system(.title, design: .rounded).weight(.semibold)
        static let metricSmall = Font.system(.title3, design: .rounded).weight(.semibold)
        /// JSON, logs and paths. Monospaced digits alone are not enough — these need fixed advance.
        static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let codeSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
        static let button = Font.system(.subheadline).weight(.semibold)
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
