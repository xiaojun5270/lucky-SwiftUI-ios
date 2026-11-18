import SwiftUI

/// Full-width child rows keep the domain and destination visible beside their controls.
struct WebSubRuleCard: View {
    var rule: WebRuleEntry
    var entry: WebSubRuleEntry
    var busy: Bool
    var actions: WebRuleActions

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LuckyCard(radius: LuckyTheme.Radius.panel, padding: LuckyTheme.Space.l,
                  spacing: LuckyTheme.Space.m) {
            header
            addresses
            actionRow
        }
    }

    private var headerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: LuckyTheme.Space.s))
            : AnyLayout(HStackLayout(spacing: LuckyTheme.Space.m))
    }

    private var header: some View {
        headerLayout {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .font(LuckyTheme.Text.cardTitle)
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(entry.serviceType) · \(entry.enabled ? "已启用" : "已停用")")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if dynamicTypeSize.isAccessibilitySize {
                    Text("启用子规则").font(LuckyTheme.Text.body)
                    Spacer(minLength: LuckyTheme.Space.s)
                }
                WebEnableSwitch(isOn: entry.enabled, disabled: busy, name: "启用子规则 \(entry.name)") {
                    actions.setSubEnabled(rule.id, entry.id, $0)
                }
                .tint(LuckyTheme.success)
                .fixedSize()
                .frame(minHeight: LuckyTheme.Space.touchTarget)
            }
        }
    }

    private var addresses: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
            // A lone domain already serves as the title when there is no remark.
            if !entry.remark.isEmpty || entry.domains.count != 1 {
                addressRow("前端", lines: entry.domains, fallback: "未填写前端地址")
            }
            if !entry.locations.isEmpty {
                addressRow(entry.serviceType == "反向代理" ? "后端" : "目标", lines: entry.locations)
            }
        }
    }

    private func addressRow(_ title: String, lines: [String], fallback: String = "") -> some View {
        addressLayout {
            Text(title)
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textTertiary)
                .fixedSize()
            Text(lines.isEmpty ? fallback : lines.joined(separator: "\n"))
                .font(LuckyTheme.Text.caption.monospaced())
                .foregroundStyle(LuckyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addressLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: LuckyTheme.Space.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: LuckyTheme.Space.s))
    }

    @ViewBuilder
    private var actionRow: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(spacing: LuckyTheme.Space.s) {
                editButton
                HStack(spacing: LuckyTheme.Space.s) { copyButton; moreMenu }
            }
        } else {
            HStack(spacing: LuckyTheme.Space.s) { copyButton; editButton; moreMenu }
        }
    }

    private var editButton: some View {
        WebRuleActionButton(title: "编辑", symbol: "pencil", selected: true, disabled: busy) {
            actions.editSub(rule.id, entry.id)
        }
        .accessibilityLabel("编辑子规则 \(entry.name)")
    }

    private var copyButton: some View {
        WebRuleActionButton(title: "复制网址", symbol: LuckySymbol.copy,
                            disabled: entry.domains.isEmpty) {
            actions.copyURL(rule.item, entry.item)
        }
        .accessibilityLabel("复制 \(entry.name) 的完整网址")
    }

    private var moreMenu: some View {
        Menu {
            Button("日志与工具", systemImage: "wrench.and.screwdriver") {
                actions.tools(WebToolsTarget(ruleKey: rule.id, ruleName: rule.name,
                                             subKey: entry.id, subName: entry.name,
                                             fileService: entry.fileService))
            }
            Button("删除子规则", systemImage: LuckySymbol.delete, role: .destructive) {
                actions.removeSub(rule.id, entry.id, entry.name)
            }
        } label: {
            WebRuleActionLabel(symbol: "ellipsis", fills: false)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.45 : 1)
        .accessibilityLabel("子规则 \(entry.name) 的更多操作")
    }
}
