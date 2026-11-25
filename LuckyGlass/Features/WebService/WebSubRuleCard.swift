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

    private var serviceTone: LuckyTone {
        switch entry.serviceType {
        case "反向代理": .brand
        case "文件服务": .info
        case "重定向", "URL 跳转": .warning
        case "OAuth 认证": .ok
        default: .idle
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
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(LuckyTheme.Text.cardTitle)
                        .foregroundStyle(LuckyTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.serviceType)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(serviceTone.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(serviceTone.tint.opacity(0.12), in: .capsule)
                }
                Text(entry.enabled ? "已启用" : "已停用")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(entry.enabled ? LuckyTheme.success : LuckyTheme.textTertiary)
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
                topologyNode(symbol: "globe", label: "前端入口", lines: entry.domains, fallback: "未填写前端地址", tone: .brand)
            }
            if !entry.locations.isEmpty {
                topologyNode(symbol: "server.rack", label: entry.serviceType == "反向代理" ? "后端目标" : "转发目标", lines: entry.locations, fallback: "", tone: .info)
            }
        }
        .padding(LuckyTheme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LuckyTheme.surfaceSunken, in: .rect(cornerRadius: LuckyTheme.Radius.row))
    }

    private func topologyNode(symbol: String, label: String, lines: [String], fallback: String, tone: LuckyTone) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone.tint)
                .frame(width: 20, height: 20)
                .background(tone.tint.opacity(0.12), in: .circle)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                Text(lines.isEmpty ? fallback : lines.joined(separator: "\n"))
                    .font(LuckyTheme.Text.code)
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
