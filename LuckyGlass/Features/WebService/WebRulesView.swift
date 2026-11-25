import SwiftUI

/// Server actions stay owned by WebServiceScreen; the list only arranges their controls.
struct WebRuleActions {
    var expand: (String) -> Void
    var move: (Int, Int) -> Void
    var setEnabled: (String, Bool) -> Void
    var edit: (String, Bool) -> Void
    var remove: (String, String) -> Void
    var order: (WebOrderRequest) -> Void
    var tools: (WebToolsTarget) -> Void
    var editSub: (String, String?) -> Void
    var setSubEnabled: (String, String, Bool) -> Void
    var removeSub: (String, String, String) -> Void
    var copyURL: (LuckyListItem, LuckyListItem) -> Void
}

struct WebRulesView: View {
    var items: [LuckyListItem]
    var expanded: String
    var loading: Bool
    var busy: Bool
    var refresh: @Sendable () async -> Void
    var actions: WebRuleActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var entries: [WebRuleEntry] {
        items.enumerated().map { WebRuleEntry(item: $0.element, index: $0.offset) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            WebPaneScroll(refresh: refresh) {
                if loading {
                    LuckyLoadingView(text: "正在读取 Web 服务规则")
                } else if items.isEmpty {
                    LuckyEmptyState(symbol: WebPane.rules.symbol, title: "暂无 Web 服务规则")
                        .padding(.vertical, LuckyTheme.Space.xl)
                } else {
                    ForEach(entries) { entry in
                        WebRuleCard(entry: entry, total: items.count, expanded: expanded,
                                    busy: busy, actions: actions)
                            .id(entry.id)
                    }
                }
            }
            .onChange(of: expanded) { previous, current in
                let target = current.isEmpty ? previous : current
                guard entries.contains(where: { $0.id == target }) else { return }
                // In particular, the footer's collapse action returns to the parent rule.
                if reduceMotion {
                    proxy.scrollTo(target, anchor: .top)
                } else {
                    withAnimation(LuckyTheme.Motion.reveal) { proxy.scrollTo(target, anchor: .top) }
                }
            }
        }
    }
}

/// Independent hit areas for the rule switch, child list and editor. Child cards use the full
/// page width so opening a large rule does not squeeze its addresses and controls into an inset.
private struct WebRuleCard: View {
    var entry: WebRuleEntry
    var total: Int
    var expanded: String
    var busy: Bool
    var actions: WebRuleActions

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isOpen: Bool { expanded == entry.id }
    private var subs: [WebSubRuleEntry] { entry.subRules }

    var body: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            LuckyCard(spacing: LuckyTheme.Space.l, tone: isOpen ? .brand : nil) {
                header
                primaryActions
            }
            if isOpen { expansion }
        }
    }

    private var headerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: LuckyTheme.Space.m))
            : AnyLayout(HStackLayout(spacing: LuckyTheme.Space.m))
    }

    private var header: some View {
        headerLayout {
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: LuckySymbol.network, size: 40, glyph: 19, role: .web)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name)
                        .font(LuckyTheme.Text.cardTitle)
                        .foregroundStyle(LuckyTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.listener)
                        .font(LuckyTheme.Text.caption.monospaced())
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if dynamicTypeSize.isAccessibilitySize {
                    Text("启用规则").font(LuckyTheme.Text.body)
                    Spacer(minLength: LuckyTheme.Space.s)
                }
                WebEnableSwitch(isOn: entry.enabled, disabled: busy, name: "启用规则 \(entry.name)") {
                    actions.setEnabled(entry.id, $0)
                }
                .tint(LuckyTheme.success)
                .fixedSize()
                .frame(minHeight: LuckyTheme.Space.touchTarget)
            }
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(spacing: LuckyTheme.Space.s) {
                childrenButton
                HStack(spacing: LuckyTheme.Space.s) { editButton; moreMenu }
            }
        } else {
            HStack(spacing: LuckyTheme.Space.s) { childrenButton; editButton; moreMenu }
        }
    }

    private var childrenButton: some View {
        WebRuleActionButton(title: "子规则 \(subs.count)",
                            symbol: isOpen ? "chevron.up" : "chevron.down", selected: isOpen) {
            actions.expand(entry.id)
        }
        .accessibilityLabel("\(entry.name)，\(subs.count) 条子规则")
        .accessibilityValue(isOpen ? "已展开" : "已收起")
        .accessibilityHint(isOpen ? "收起子规则列表" : "展开和管理子规则")
    }

    private var editButton: some View {
        WebRuleActionButton(title: "编辑规则", symbol: "pencil", disabled: busy) {
            actions.edit(entry.id, false)
        }
        .accessibilityLabel("编辑规则 \(entry.name)")
    }

    private var moreMenu: some View {
        Menu {
            Section("子规则管理") {
                Button("添加子规则", systemImage: LuckySymbol.add) { actions.editSub(entry.id, nil) }
                    .disabled(busy)
                Button("调整子规则顺序", systemImage: "list.number") {
                    actions.order(WebOrderRequest(key: entry.id, name: entry.name, keys: subs.map(\.id)))
                }
                .disabled(busy || subs.count < 2)
            }
            Section("规则顺序") {
                Button("上移", systemImage: "arrow.up") { actions.move(entry.index, -1) }
                    .disabled(busy || entry.index == 0)
                Button("下移", systemImage: "arrow.down") { actions.move(entry.index, 1) }
                    .disabled(busy || entry.index == total - 1)
            }
            Section("规则操作") {
                Button("复制规则", systemImage: LuckySymbol.copy) { actions.edit(entry.id, true) }
                Button("日志与工具", systemImage: "wrench.and.screwdriver") {
                    actions.tools(WebToolsTarget(ruleKey: entry.id, ruleName: entry.name))
                }
                Button("删除规则", systemImage: LuckySymbol.delete, role: .destructive) {
                    actions.remove(entry.id, entry.name)
                }
            }
        } label: {
            WebRuleActionLabel(symbol: "ellipsis", fills: false)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.45 : 1)
        .accessibilityLabel("\(entry.name) 的更多操作")
    }

    private var expansion: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            if subs.isEmpty {
                LuckyEmptyState(symbol: "point.topleft.down.to.point.bottomright.curvepath",
                                title: "暂无子规则", message: "添加子规则，配置前端与后端地址") {
                    Button("添加子规则") { actions.editSub(entry.id, nil) }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy)
                }
            } else {
                ForEach(subs) { sub in
                    WebSubRuleCard(rule: entry, entry: sub, busy: busy, actions: actions)
                }
                if subs.count > 3 {
                    WebRuleActionButton(title: "收起 \(entry.name) 的子规则", symbol: "chevron.up") {
                        actions.expand(entry.id)
                    }
                }
            }
        }
    }
}
