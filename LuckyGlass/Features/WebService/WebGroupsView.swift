import SwiftUI

/// §13 — 分组. The sub-rule groups a proxy's `GroupKey` points at.
///
/// The shortest of the four list panes: a group carries a name, a key and — only when the module
/// honours `includeCounts` — how many sub-rules point at it. There is no enable switch, because a
/// group is a label and not a service.
struct WebGroupsView: View {
    var items: [LuckyListItem]
    var loading: Bool
    var busy: Bool
    var refresh: @Sendable () async -> Void
    var move: (Int, Int) -> Void
    /// `(clone(item), key)` — `JSONValue` is a value type, so handing the row over *is* the clone.
    var edit: (LuckyListItem, String) -> Void
    var remove: (String, String) -> Void

    var body: some View {
        WebPaneScroll(refresh: refresh) {
            if loading {
                LuckyLoadingView(text: "正在读取分组")
            } else if items.isEmpty {
                LuckyEmptyState(symbol: WebPane.groups.symbol, title: "暂无分组")
                    .padding(.vertical, LuckyTheme.Space.xl)
            } else {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    WebGroupCard(item: item, index: index, total: items.count, busy: busy,
                                 move: move, edit: edit, remove: remove)
                }
            }
        }
    }
}

// MARK: - 分组卡片

private struct WebGroupCard: View {
    var item: LuckyListItem
    var index: Int
    var total: Int
    var busy: Bool
    var move: (Int, Int) -> Void
    var edit: (LuckyListItem, String) -> Void
    var remove: (String, String) -> Void

    private var key: String { WebRecord.key(item, index) }

    /// `pick(item, ["Name", "GroupName"], key)` — the key is the fallback, since it is the only
    /// handle an unnamed group can be recognised by.
    private var name: String { WebRecord.pick(item, ["Name", "GroupName"], key) }

    /// `` `${key} · ${subRuleCount === undefined ? "接口未返回子规则数量" : `${n} 个子规则`}` ``.
    ///
    /// Only an *absent* key takes the first branch: a module that ignores `includeCounts` says so
    /// rather than printing a zero it never sent. A present null goes through `${null}` and prints
    /// the literal `null`, exactly as it does in `WebRecord.lines`.
    private var summary: String {
        guard let count = item["subRuleCount"] else { return "\(key) · 接口未返回子规则数量" }
        let text = count.isNull ? "null" : count.asDisplayString
        return "\(key) · \(text) 个子规则"
    }

    var body: some View {
        LuckyCard(spacing: LuckyTheme.Space.m) {
            header
            verbs
        }
    }
}

extension WebGroupCard {
    /// A bare glyph rather than an `IconTile`: §13 and §14 are the two rows on this screen that
    /// draw the icon without a backing plate, and the subtitle sits flush under the title with no
    /// `marginTop` of its own.
    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            LuckyIconTile(symbol: WebPane.groups.symbol, size: 32, glyph: 14,
                          role: WebPane.groups.iconRole)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(LuckyTheme.Text.cardTitle)
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .lineLimit(1)
                Text(summary)
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    /// Editing stays visible; ordering and deletion are secondary commands in the overflow menu.
    private var verbs: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            WebInlineActionButton(title: "编辑", symbol: "pencil", prominent: true) {
                edit(item, key)
            }
            Menu {
                Button {
                    move(index, -1)
                } label: {
                    Label("上移", systemImage: "arrow.up")
                }
                .disabled(busy || index == 0)
                Button {
                    move(index, 1)
                } label: {
                    Label("下移", systemImage: "arrow.down")
                }
                .disabled(busy || index == total - 1)
                Button(role: .destructive) {
                    remove(key, name)
                } label: {
                    Label("删除分组", systemImage: LuckySymbol.delete)
                }
                .disabled(busy)
            } label: {
                LuckyIconTile(symbol: "ellipsis", size: 36, glyph: 15, tone: .idle)
                    .frame(width: LuckyTheme.Space.touchTarget, height: LuckyTheme.Space.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("分组更多操作")
        }
    }
}
