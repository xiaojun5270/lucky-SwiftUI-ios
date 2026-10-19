import SwiftUI

/// Content-layer surfaces: compact work panels that scroll under the system chrome.
///
/// None of these use `glassEffect`. Two of Apple's stated pitfalls are stacking glass on glass and
/// putting glass inside scrolling content, and every screen in this port is a scroll view under a
/// glass tab bar and a glass toolbar — so the content layer is opaque by construction, and glass is
/// reserved for the floating pieces in `LuckyGlassControls.swift`.
struct LuckyCard<Content: View>: View {
    var radius: CGFloat = LuckyTheme.Radius.card
    var padding: CGFloat = LuckyTheme.Space.cardInset
    var spacing: CGFloat = LuckyTheme.Space.m
    /// When set, the card's border carries the tone instead of the neutral hairline. Used for the
    /// "危险操作" confirmation card and for failed-request results.
    var tone: LuckyTone?
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing, content: content)
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(LuckyTheme.surface))
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    tone?.tint.opacity(0.42) ?? LuckyTheme.hairline,
                    lineWidth: LuckyTheme.strokeWidth
                )
            )
            .overlay(
                shape.inset(by: 1)
                    .stroke(LuckyTheme.surfaceHighlight.opacity(0.55), lineWidth: 0.5)
            )
            // Lets anything inside ask for `ConcentricRectangle()` and get the right inner radius.
            .containerShape(shape)
    }
}

/// Turns a whole `LuckyCard` into a button. The original tiles and rows are `Pressable`s that dim
/// to 0.72 and scale to 0.985 while held; `.plain` keeps SwiftUI from tinting the label, and the
/// press feedback is applied here so every tappable card in the app behaves identically.
struct LuckyCardButtonStyle: ButtonStyle {
    var radius: CGFloat = LuckyTheme.Radius.card
    var padding: CGFloat = LuckyTheme.Space.cardInset
    var tone: LuckyTone?

    func makeBody(configuration: Configuration) -> some View {
        LuckyCard(radius: radius, padding: padding, tone: tone) {
            configuration.label
        }
        .opacity(configuration.isPressed ? 0.72 : 1)
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
        .animation(LuckyTheme.Motion.snap, value: configuration.isPressed)
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// A nested surface inside a card — a log line, a port mapping, a JSON field. Its corners are
/// derived from the card's, so the inset never looks like a sticker.
struct LuckyInset<Content: View>: View {
    var padding: CGFloat = LuckyTheme.Space.m
    var spacing: CGFloat = LuckyTheme.Space.s
    var fill: Color = LuckyTheme.surfaceRaised
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing, content: content)
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ConcentricRectangle().fill(fill))
    }
}

/// A group heading. Sits outside the card, in the page margin, so the card itself stays a clean
/// plate.
struct LuckySectionHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var symbol: String?
    var iconRole: LuckyIconRole? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let symbol {
                LuckyIconTile(symbol: symbol, size: 28, glyph: 12, role: iconRole)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .textCase(nil)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .lineLimit(2)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: LuckyTheme.Space.s)
            trailing()
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension LuckySectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, symbol: String? = nil,
         iconRole: LuckyIconRole? = nil) {
        self.init(title: title, subtitle: subtitle, symbol: symbol, iconRole: iconRole) { EmptyView() }
    }
}

/// Header plus card, which is how almost every screen is laid out.
struct LuckySection<Content: View>: View {
    var title: String
    var subtitle: String?
    var symbol: String?
    var iconRole: LuckyIconRole? = nil
    var padding: CGFloat = LuckyTheme.Space.cardInset
    var spacing: CGFloat = LuckyTheme.Space.m
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            LuckySectionHeader(title: title, subtitle: subtitle, symbol: symbol, iconRole: iconRole)
            LuckyCard(padding: padding, spacing: spacing, content: content)
        }
    }
}

/// A label/value line. `value` is monospaced when it holds an address, a port or a byte count,
/// which is most of what Lucky reports — hence the `mono` flag rather than a separate view.
struct LuckyRow<Trailing: View>: View {
    var label: String
    var value: String?
    var mono: Bool = false
    var tone: LuckyTone?
    var lineLimit: Int? = 2
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: LuckyTheme.Space.m) {
            Text(label)
                .font(LuckyTheme.Text.label)
                .foregroundStyle(LuckyTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: LuckyTheme.Space.s)
            if let value, !value.isEmpty {
                Text(value)
                    .font(mono ? LuckyTheme.Text.code : LuckyTheme.Text.bodyMedium)
                    .foregroundStyle(tone?.tint ?? LuckyTheme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(lineLimit)
                    .textSelection(.enabled)
            }
            trailing()
        }
    }
}

extension LuckyRow where Trailing == EmptyView {
    init(_ label: String, _ value: String?, mono: Bool = false, tone: LuckyTone? = nil,
         lineLimit: Int? = 2) {
        self.init(label: label, value: value, mono: mono, tone: tone, lineLimit: lineLimit) {
            EmptyView()
        }
    }
}

/// The separator between rows inside a card. Full-width lines make a card look like a table, so
/// this one is inset and very low contrast.
struct LuckyHairline: View {
    var body: some View {
        Rectangle()
            .fill(LuckyTheme.separator)
            .frame(height: LuckyTheme.strokeWidth)
            .accessibilityHidden(true)
    }
}

/// JSON, YAML, compose files and log tails. Sunken rather than raised: the response body is
/// evidence, not a control, and it should read as a well in the card.
struct LuckyCodeBlock: View {
    var text: String
    /// `nil` grows with the content; the debugger caps it and lets the user expand.
    var maxHeight: CGFloat? = 260
    var small: Bool = false

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(text.isEmpty ? "—" : text)
                .font(small ? LuckyTheme.Text.codeSmall : LuckyTheme.Text.code)
                .foregroundStyle(LuckyTheme.textPrimary)
                .textSelection(.enabled)
                .padding(LuckyTheme.Space.m)
                .frame(minWidth: 0, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: maxHeight)
        .background(ConcentricRectangle().fill(LuckyTheme.surfaceSunken))
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// One number in the dashboard grid. `value` is pre-formatted — every byte and percent in the app
/// goes through `Format`, so this view never does arithmetic.
struct LuckyMetricTile: View {
    var label: String
    var value: String
    var caption: String?
    var symbol: String
    var tone: LuckyTone = .brand
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
            HStack(spacing: LuckyTheme.Space.xs) {
                LuckyIconTile(symbol: symbol, size: 24, glyph: 11, tone: tone)
                Text(label)
                    .font(LuckyTheme.Text.captionMedium)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(compact ? LuckyTheme.Text.metricSmall : LuckyTheme.Text.metric)
                .foregroundStyle(LuckyTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .monospacedDigit()
                .contentTransition(.numericText())
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LuckyTheme.Space.m)
        .background {
            // A 3 pt tone-colored strip on the leading edge gives each tile an at-a-glance colour
            // identity without overpowering the value. The ZStack is clipped to ConcentricRectangle
            // so the strip inherits the tile's concentric corner radius.
            ZStack(alignment: .leading) {
                ConcentricRectangle().fill(LuckyTheme.surfaceRaised)
                Rectangle()
                    .fill(tone.tint.opacity(0.72))
                    .frame(width: 3)
            }
            .clipShape(ConcentricRectangle())
        }
    }
}
