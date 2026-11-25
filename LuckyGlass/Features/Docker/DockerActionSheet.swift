import SwiftUI

// MARK: - 单个动作

/// One row of §19's drawer: an icon, a label, and the thing they do.
///
/// The label is the identity because no drawer repeats one, and because a conditional entry —
/// §19.5's 暂停容器 — must not shift the rows below it when it appears.
struct DockerActionItem: Identifiable {
    var label: String
    var symbol: String
    var tint: Color
    var section: String = ""
    var destructive: Bool = false
    var action: () -> Void

    var id: String { label }

    init(_ label: String, _ symbol: String, _ tint: Color,
         section: String = "", destructive: Bool = false,
         _ action: @escaping () -> Void) {
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.section = section
        self.destructive = destructive
        self.action = action
    }
}

// MARK: - 动作抽屉

/// §19's `DockerActionSheet` — the drawer behind 镜像高级工具, 镜像操作 and 容器操作.
///
/// The original is a bottom-anchored `Modal` over a dimmed backdrop with its own handle and header;
/// a `.sheet` already draws both, so the plate's `maxWidth: 720` / `maxHeight: "84%"` become
/// presentation detents and the header becomes the real navigation bar.
///
/// Chrome is hand-built rather than `ServiceSheet` because the drawer has no primary verb, and
/// `luckyActionBar` would draw an empty glass bar for one — the same reason `WebToolsSheet` builds
/// its own.
struct DockerActionSheet: View {
    var title: String
    var subtitle: String = ""
    var close: () -> Void
    var items: [DockerActionItem]

    private struct GroupSection: Identifiable {
        var title: String
        var items: [DockerActionItem]
        var id: String { title }
    }

    private var groupedSections: [GroupSection] {
        var order: [String] = []
        var buckets: [String: [DockerActionItem]] = [:]
        for item in items {
            if buckets[item.section] == nil { order.append(item.section) }
            buckets[item.section, default: []].append(item)
        }
        return order.map { GroupSection(title: $0, items: buckets[$0] ?? []) }
    }

    private var hasSections: Bool {
        items.contains { !$0.section.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LuckyBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: LuckyTheme.Space.l) {
                        if hasSections {
                            ForEach(groupedSections) { group in
                                VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
                                    if !group.title.isEmpty {
                                        Text(group.title)
                                            .font(LuckyTheme.Text.captionMedium)
                                            .foregroundStyle(group.title == "危险操作" ? LuckyTheme.danger : LuckyTheme.textTertiary)
                                            .padding(.horizontal, LuckyTheme.Space.xs)
                                    }
                                    LuckyTileGrid(minimum: 145, spacing: 7) {
                                        ForEach(group.items) { item in
                                            DockerActionRow(item: item, close: close)
                                        }
                                    }
                                }
                            }
                        } else {
                            // `flexBasis: 145` with `flexGrow: 1` and `gap: 7` — a wrapping row of equal
                            // buttons, two to a line on a phone, which is what the adaptive grid draws.
                            LuckyTileGrid(minimum: 145, spacing: 7) {
                                ForEach(items) { item in
                                    DockerActionRow(item: item, close: close)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, LuckyTheme.Space.gutter)
                    .padding(.top, LuckyTheme.Space.s)
                    .padding(.bottom, LuckyTheme.Space.xl)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(title)
            .navigationSubtitle(subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .presentationDetents(detents)
    }

    /// `maxHeight: "84%"` on a plate that otherwise sizes itself to its rows. A four-entry drawer
    /// opens at half height and 容器操作's eighteen fill the sheet, which is as close as a fixed set
    /// of detents gets to that.
    private var detents: Set<PresentationDetent> {
        items.count > 6 ? [.large] : [.medium, .large]
    }
}

// MARK: - 抽屉里的一行

private struct DockerActionRow: View {
    var item: DockerActionItem
    var close: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: LuckyTheme.Radius.panel, style: .continuous)
    }

    var body: some View {
        Button {
            if item.destructive {
                LuckyHaptic.warning()
            } else {
                LuckyHaptic.light()
            }
            // `onPress={() => { close(); action(); }}` — the drawer goes away first, so a form or
            // an alert the action opens is never presented behind it.
            close()
            item.action()
        } label: {
            HStack(spacing: 9) {
                LuckyFunctionIcon(symbol: item.symbol, size: 30, glyph: 13, color: item.tint)
                Text(item.label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Destructive verbs carry explicit danger tint on label, fill and border so deletions
            // never blend into neutral maintenance actions.
            .foregroundStyle(item.destructive ? LuckyTheme.danger : LuckyTheme.textPrimary)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(shape.fill(item.destructive ? LuckyTheme.dangerSoft : LuckyTheme.surfaceRaised))
            .overlay(
                shape.strokeBorder(
                    item.destructive ? LuckyTheme.danger.opacity(0.35) : LuckyTheme.hairline,
                    lineWidth: LuckyTheme.strokeWidth
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.96, pressedOpacity: 0.72))
    }
}
