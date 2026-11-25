import SwiftUI

/// Floating action bar pinned to the bottom safe area.
///
/// Renders independent, cleanly separated floating controls (no Liquid Glass metaball fusion)
/// sharing an exact 46pt height, subtle hairline stroke and soft ambient elevation shadow.
struct LuckyGlassBar<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: spacing, content: content)
            .frame(maxWidth: LuckyTheme.Layout.contentWidth)
            .padding(.horizontal, LuckyTheme.Space.gutter)
            .padding(.top, 4)
            .padding(.bottom, LuckyTheme.Space.s)
            .frame(maxWidth: .infinity)
    }
}

/// Primary or secondary floating capsule button used in action bars and retry cards.
/// `prominent` is the screen's single primary verb — 保存, 添加证书, 创建容器 — rendered as a
/// crisp filled accent capsule; secondary buttons use an elevated card surface with a hairline ring.
struct LuckyPillButton: View {
    var title: String
    var symbol: String?
    var tone: LuckyTone = .brand
    var prominent: Bool = false
    var loading: Bool = false
    var fills: Bool = true
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            if prominent {
                LuckyHaptic.medium()
            } else {
                LuckyHaptic.light()
            }
            action()
        } label: {
            HStack(spacing: 6) {
                if loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foreground)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .font(LuckyTheme.Text.button)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, fills ? 16 : 15)
            .frame(maxWidth: fills ? .infinity : nil)
            .frame(height: 46)
            .background(Capsule(style: .continuous).fill(background))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(border, lineWidth: LuckyTheme.strokeWidth)
            )
            .shadow(
                color: shadowColor,
                radius: prominent ? 10 : 8,
                x: 0,
                y: prominent ? 4 : 3
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.97, pressedOpacity: 0.82))
        .disabled(loading)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var foreground: Color {
        if prominent { return LuckyTheme.textOnAccent }
        return tone == .brand ? LuckyTheme.textPrimary : tone.tint
    }

    private var iconColor: Color {
        if prominent { return LuckyTheme.textOnAccent }
        return tone == .brand ? LuckyTheme.accent : tone.tint
    }

    private var background: Color {
        if prominent { return tone.tint }
        return tone == .brand ? LuckyTheme.surface : tone.fill
    }

    private var border: Color {
        if prominent {
            return Color.white.opacity(colorScheme == .dark ? 0.14 : 0.22)
        }
        if tone != .brand {
            return tone.tint.opacity(0.30)
        }
        return LuckyTheme.hairline.opacity(colorScheme == .dark ? 0.65 : 0.85)
    }

    private var shadowColor: Color {
        if prominent {
            return tone.tint.opacity(colorScheme == .dark ? 0.30 : 0.24)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08)
    }
}

/// A circular 46pt floating icon button matching `LuckyPillButton` in height, surface, border and
/// elevation shadow — used for pagination and compact single-glyph bar actions.
struct LuckyGlassIconButton: View {
    var symbol: String
    var label: String
    var tone: LuckyTone = .brand
    var prominent: Bool = false
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            LuckyHaptic.light()
            action()
        } label: {
            Image(systemName: LuckySymbol.solid(symbol))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 46, height: 46)
                .background(Circle().fill(background))
                .overlay(Circle().strokeBorder(border, lineWidth: LuckyTheme.strokeWidth))
                .shadow(
                    color: prominent
                        ? tone.tint.opacity(colorScheme == .dark ? 0.30 : 0.24)
                        : Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08),
                    radius: 8,
                    x: 0,
                    y: 3
                )
                .contentShape(Circle())
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.92, pressedOpacity: 0.78))
        .opacity(isEnabled ? 1 : 0.40)
        .accessibilityLabel(label)
    }

    private var foreground: Color {
        if prominent { return LuckyTheme.textOnAccent }
        return tone == .brand ? LuckyTheme.textPrimary : tone.tint
    }

    private var background: Color {
        if prominent { return tone.tint }
        return tone == .brand ? LuckyTheme.surface : tone.fill
    }

    private var border: Color {
        if prominent {
            return Color.white.opacity(colorScheme == .dark ? 0.14 : 0.22)
        }
        return LuckyTheme.hairline.opacity(colorScheme == .dark ? 0.65 : 0.85)
    }
}

/// Circular 46pt overflow menu trigger paired beside a primary `LuckyPillButton` in bottom bars.
struct LuckyGlassMenuButton<MenuContent: View>: View {
    var symbol: String = "ellipsis"
    var label: String = "更多操作"
    var tone: LuckyTone = .brand
    @ViewBuilder var menu: () -> MenuContent

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Menu {
            menu()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tone == .brand ? LuckyTheme.textPrimary : tone.tint)
                .frame(width: 46, height: 46)
                .background(Circle().fill(LuckyTheme.surface))
                .overlay(
                    Circle().strokeBorder(
                        LuckyTheme.hairline.opacity(colorScheme == .dark ? 0.65 : 0.85),
                        lineWidth: LuckyTheme.strokeWidth
                    )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08),
                    radius: 8,
                    x: 0,
                    y: 3
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(label)
    }
}

/// Floating capsule readout centered between prev/next `LuckyGlassIconButton`s in log pagers.
struct LuckyPagerBadge: View {
    var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(LuckyTheme.Text.captionMedium)
            .foregroundStyle(LuckyTheme.textPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(minWidth: 92, maxWidth: .infinity)
            .frame(height: 46)
            .background(Capsule(style: .continuous).fill(LuckyTheme.surface))
            .overlay(
                Capsule(style: .continuous).strokeBorder(
                    LuckyTheme.hairline.opacity(colorScheme == .dark ? 0.65 : 0.85),
                    lineWidth: LuckyTheme.strokeWidth
                )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08),
                radius: 8,
                x: 0,
                y: 3
            )
    }
}

/// A read-only floating badge — the live-connection pill over the monitor chart, the "只读" marker
/// over a GET result, or a transient toast. Not a button, so it gets glass directly instead of a
/// button style.
struct LuckyGlassBadge: View {
    var text: String
    var symbol: String?
    var tone: LuckyTone = .idle
    var pulsing: Bool = false
    var multiline: Bool = false

    var body: some View {
        let label = HStack(alignment: multiline ? .top : .center, spacing: LuckyTheme.Space.xs) {
            if pulsing {
                LuckyStatusDot(tone: tone, pulsing: true, size: 7)
                    .padding(.top, multiline ? 4 : 0)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.top, multiline ? 2 : 0)
            }
            Text(text)
                .font(LuckyTheme.Text.captionMedium)
                .lineLimit(multiline ? 3 : 1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: multiline)
        }
        .foregroundStyle(tone.tint)
        .padding(.horizontal, LuckyTheme.Space.m)
        .padding(.vertical, multiline ? 9 : 7)

        if multiline {
            label.glassEffect(.regular, in: .rect(cornerRadius: LuckyTheme.Radius.panel))
        } else {
            label.glassEffect(.regular, in: .capsule)
        }
    }
}

/// One option of a segmented control or horizontal pill tab bar.
struct LuckySegment<Value: Hashable>: Identifiable {
    var value: Value
    var title: String
    var symbol: String?
    var badge: Int?

    var id: Value { value }

    init(_ value: Value, _ title: String, symbol: String? = nil, badge: Int? = nil) {
        self.value = value
        self.title = title
        self.symbol = symbol
        self.badge = badge
    }
}

/// A view switcher whose selection indicator is a single glass shape that *travels* between
/// segments.
///
/// Exactly one glass shape exists inside the container — the selected segment owns it via
/// `glassEffectID`, and the unselected segments are plain text. That is what makes the indicator
/// morph instead of fading, and it keeps the "no glass thicket" rule intact.
///
/// Use this for up to four options and pin it (`safeAreaBar`, or a header outside the scroll view);
/// for longer lists use `LuckyGlassMenuPicker`. Set `glass: false` when the control must live
/// inside scrolling content, which falls back to a tinted capsule.
struct LuckyGlassSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    var segments: [LuckySegment<Value>]
    var tone: LuckyTone = .brand
    var glass: Bool = true

    @Namespace private var indicator

    var body: some View {
        Group {
            if glass {
                GlassEffectContainer(spacing: LuckyTheme.Space.m) {
                    track
                }
            } else {
                track
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var track: some View {
        HStack(spacing: LuckyTheme.Space.xs) {
            ForEach(segments) { segment in
                segmentButton(segment)
            }
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(LuckyTheme.surfaceRaised))
    }

    @ViewBuilder
    private func segmentButton(_ segment: LuckySegment<Value>) -> some View {
        let selected = segment.value == selection
        Button {
            withAnimation(LuckyTheme.Motion.morph) { selection = segment.value }
        } label: {
            HStack(spacing: LuckyTheme.Space.xs) {
                if let symbol = segment.symbol {
                    if selected, glass {
                        LuckyIconTile(symbol: symbol, size: 20, glyph: 9,
                                      tone: tone == .brand ? nil : tone)
                    } else {
                        Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                    }
                }
                Text(segment.title).font(LuckyTheme.Text.captionMedium).lineLimit(1)
            }
            .foregroundStyle(selected ? tone.tint : LuckyTheme.textSecondary)
            .padding(.horizontal, LuckyTheme.Space.m)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
            .background {
                if selected {
                    if glass {
                        Capsule(style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular.tint(tone.tint.opacity(0.18)), in: .capsule)
                            .glassEffectID("indicator", in: indicator)
                    } else {
                        Capsule(style: .continuous)
                            .fill(LuckyTheme.surface)
                            .matchedGeometryEffect(id: "indicator", in: indicator)
                    }
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/// The same job as `LuckyGlassSegmentedControl` when there are too many options to sit side by side
/// — Docker's six views, a module list, a log source. A glass button that opens a system menu.
struct LuckyGlassMenuPicker<Value: Hashable>: View {
    var title: String
    @Binding var selection: Value
    var segments: [LuckySegment<Value>]
    var iconRole: LuckyIconRole? = nil

    private var current: LuckySegment<Value>? {
        segments.first { $0.value == selection }
    }

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(segments) { segment in
                    if let symbol = segment.symbol {
                        Label(segment.title, systemImage: symbol).tag(segment.value)
                    } else {
                        Text(segment.title).tag(segment.value)
                    }
                }
            }
        } label: {
            HStack(spacing: LuckyTheme.Space.xs) {
                if let symbol = current?.symbol {
                    LuckyIconTile(symbol: symbol, size: 20, glyph: 9, role: iconRole)
                }
                Text(current?.title ?? title).font(LuckyTheme.Text.captionMedium).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(LuckyTheme.textPrimary)
            .padding(.horizontal, LuckyTheme.Space.m)
            .padding(.vertical, 8)
            .frame(minHeight: LuckyTheme.Space.touchTarget)
            // Glass goes on the label rather than through `buttonStyle`: a `Menu` does not reliably
            // forward a button style to its label on iOS, and the shape here must be exact.
            .glassEffect(.regular, in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A horizontally scrollable one-tap pill bar for multi-pane workspaces such as Docker and Web 服务.
/// Lives in the pinned header above scrolling content, using solid filled surfaces instead of glass
/// so pills remain crisp and scroll at 120Hz without offscreen glass refraction passes.
struct LuckyHorizontalTabBar<Value: Hashable>: View {
    @Binding var selection: Value
    var segments: [LuckySegment<Value>]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LuckyTheme.Space.s) {
                    ForEach(segments) { segment in
                        pill(segment)
                            .id(segment.value)
                    }
                }
                .padding(.horizontal, LuckyTheme.Space.gutter)
                .padding(.vertical, 2)
            }
            .onChange(of: selection) {
                withAnimation(LuckyTheme.Motion.snap) {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }

    private func pill(_ segment: LuckySegment<Value>) -> some View {
        let selected = segment.value == selection
        return Button {
            guard !selected else { return }
            LuckyHaptic.selection()
            withAnimation(LuckyTheme.Motion.snap) { selection = segment.value }
        } label: {
            HStack(spacing: 5) {
                if let symbol = segment.symbol {
                    Image(systemName: LuckySymbol.solid(symbol))
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(segment.title)
                    .font(LuckyTheme.Text.captionMedium)
                    .lineLimit(1)
                if let badge = segment.badge {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected
                                      ? LuckyTheme.textOnAccent.opacity(0.22)
                                      : LuckyTheme.surfaceRaised)
                        )
                }
            }
            .foregroundStyle(selected ? LuckyTheme.textOnAccent : LuckyTheme.textSecondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? LuckyTheme.accent : LuckyTheme.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        selected
                            ? Color.clear
                            : LuckyTheme.hairline.opacity(colorScheme == .dark ? 0.45 : 0.4),
                        lineWidth: LuckyTheme.strokeWidth
                    )
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.95, pressedOpacity: 0.75))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
