import SwiftUI

/// The scroll shell all six panes of `WebServiceScreen` are built in.
///
/// The original mounts a `FlatList` for 规则 / 分组 / CGI / 日志 and puts 设置 and 工具 inside the
/// page's own `ScrollView` — a split forced by the fact that a `FlatList` cannot virtualise when it
/// is nested in a `ScrollView`. `LazyVStack` has no such conflict, so all six share one container.
/// The visible consequence is that the `SectionHeader` scrolls with the rows where the `FlatList`'s
/// stayed put; the pane picker above it is pinned instead, which keeps the six views one tap apart.
struct WebPaneScroll<Content: View>: View {
    var topPadding: CGFloat = LuckyTheme.Space.s
    var refresh: @Sendable () async -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LuckyTheme.Space.stack, content: content)
                .padding(.horizontal, LuckyTheme.Space.gutter)
                .padding(.top, topPadding)
                .padding(.bottom, LuckyTheme.Space.pageBottom)
                .frame(maxWidth: LuckyTheme.Layout.contentWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            let work = Task { await refresh() }
            await work.value
        }
    }
}

/// §7.1 `IconButton` — the compact verb chip that fills the action row of every list pane.
///
/// `ServiceActionButton` cannot stand in for it: these rows carry a *different* accessibility label
/// from their visible text (`复制完整网址` reads as 复制网址, `子规则排序` as 排序), and dropping
/// that distinction would leave the two 复制 buttons of an expanded rule indistinguishable to
/// VoiceOver. The surface is always the neutral raised one, exactly as in the original — only the
/// glyph and label colour carry meaning.
struct WebIconButton: View {
    var symbol: String
    /// `label` — what VoiceOver reads.
    var name: String
    /// `visibleLabel` — what is drawn. `nil` covers the rows where the original passes one string
    /// for both.
    var text: String?
    var tint: Color = LuckyTheme.textPrimary
    var disabled: Bool = false
    var action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: LuckyTheme.Radius.row, style: .continuous)
    }

    var body: some View {
        Button {
            LuckyHaptic.light()
            action()
        } label: {
            HStack(spacing: 4) {
                LuckyFunctionIcon(symbol: symbol, size: 24, glyph: 11, color: tint)
                Text(text ?? name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(LuckyTheme.textPrimary)
            .padding(.horizontal, LuckyTheme.Space.s)
            .frame(minWidth: 58, minHeight: LuckyTheme.Space.touchTarget)
            .background(shape.fill(LuckyTheme.surfaceRaised))
            .contentShape(shape)
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.96, pressedOpacity: 0.72))
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(name)
    }
}

/// A restrained inline command for card footers. Only the primary action is filled; secondary
/// actions use a quiet bordered surface so a row of controls keeps a clear hierarchy.
struct WebInlineActionButton: View {
    var title: String
    var symbol: String
    var tone: LuckyTone = .brand
    var prominent: Bool = false
    var expands: Bool = false
    var disabled: Bool = false
    var action: () -> Void

    private var shape: Capsule { Capsule(style: .continuous) }

    var body: some View {
        Button {
            LuckyHaptic.light()
            action()
        } label: {
            HStack(spacing: 6) {
                if prominent {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                } else {
                    LuckyIconTile(symbol: symbol, size: 22, glyph: 10,
                                  tone: tone == .brand ? nil : tone)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(prominent ? LuckyTheme.textOnAccent : LuckyTheme.textPrimary)
            .padding(.horizontal, prominent ? 14 : 10)
            .frame(maxWidth: expands ? .infinity : nil,
                   minHeight: LuckyTheme.Space.touchTarget)
            .background(shape.fill(prominent ? tone.tint : LuckyTheme.surface))
            .overlay(
                shape.strokeBorder(prominent ? Color.clear : LuckyTheme.hairline,
                                   lineWidth: LuckyTheme.strokeWidth)
            )
            .contentShape(shape)
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.96, pressedOpacity: 0.75))
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(title)
    }
}

/// Flat, equally sized rule actions. The symbol yields to the full label on narrow screens.
struct WebRuleActionLabel: View {
    var title: String?
    var symbol: String
    var selected: Bool = false
    var fills: Bool = true
    var compact: Bool = false

    private var cornerRadius: CGFloat { compact ? 9 : LuckyTheme.Radius.row }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: compact ? 4 : 6) {
                Image(systemName: symbol).accessibilityHidden(true)
                if let title { Text(title) }
            }
            .fixedSize()
            if let title { Text(title).fixedSize(horizontal: false, vertical: true) }
        }
        .font(compact ? .system(size: 11.5, weight: .semibold) : LuckyTheme.Text.label)
        .foregroundStyle(selected ? LuckyTheme.accent : LuckyTheme.textPrimary)
        .padding(.horizontal, compact ? 8 : LuckyTheme.Space.s)
        .padding(.vertical, compact ? 5 : LuckyTheme.Space.s)
        .frame(minWidth: compact ? 34 : LuckyTheme.Space.touchTarget,
               maxWidth: fills ? .infinity : nil,
               minHeight: compact ? 32 : LuckyTheme.Space.touchTarget)
        .background(selected ? LuckyTheme.accentSoft : LuckyTheme.surfaceRaised,
                    in: .rect(cornerRadius: cornerRadius))
        .contentShape(.rect(cornerRadius: cornerRadius))
    }
}

struct WebRuleActionButton: View {
    var title: String
    var symbol: String
    var selected: Bool = false
    var fills: Bool = true
    var compact: Bool = false
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            LuckyHaptic.light()
            action()
        } label: {
            WebRuleActionLabel(title: title, symbol: symbol, selected: selected,
                               fills: fills, compact: compact)
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.97, pressedOpacity: 0.75))
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

/// The switch that fronts a rule, a sub-rule or a CGI instance. `Toggle` with no label of its own,
/// so the row decides what sits beside it.
struct WebEnableSwitch: View {
    var isOn: Bool
    var disabled: Bool
    var name: String
    var change: (Bool) -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: change))
            .labelsHidden()
            .disabled(disabled)
            .accessibilityLabel(name)
    }
}
