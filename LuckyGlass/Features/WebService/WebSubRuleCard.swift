import SwiftUI

/// Full-width child rows keep the domain and destination visible beside their controls.
struct WebSubRuleCard: View {
    var rule: WebRuleEntry
    var entry: WebSubRuleEntry
    var busy: Bool
    var actions: WebRuleActions

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LuckyCard(radius: 14, padding: 0, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                header
                addresses
                    .opacity(entry.enabled ? 1 : 0.65)
                actionRow
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: LuckyTheme.Space.xs))
            : AnyLayout(HStackLayout(spacing: LuckyTheme.Space.s))
    }

    private var header: some View {
        headerLayout {
            HStack(spacing: 6) {
                Text(entry.name)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(entry.enabled ? LuckyTheme.textPrimary : LuckyTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(entry.serviceType)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(serviceTone.tint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(serviceTone.tint.opacity(0.12), in: .capsule)
                    .fixedSize()
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
                .controlSize(.small)
                .fixedSize()
            }
        }
    }

    private var addresses: some View {
        VStack(alignment: .leading, spacing: 4) {
            // A lone domain already serves as the title when there is no remark.
            if !entry.remark.isEmpty || entry.domains.count != 1 {
                topologyNode(symbol: "globe", label: "前端", lines: entry.domains, fallback: "未填写前端地址", tone: .brand)
            }
            if !entry.locations.isEmpty {
                topologyNode(symbol: "server.rack", label: entry.serviceType == "反向代理" ? "后端" : "目标", lines: entry.locations, fallback: "", tone: .info)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LuckyTheme.surfaceSunken, in: .rect(cornerRadius: 9))
    }

    private func topologyNode(symbol: String, label: String, lines: [String], fallback: String, tone: LuckyTone) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tone.tint)
                .frame(width: 16, height: 16)
                .background(tone.tint.opacity(0.12), in: .circle)
                .padding(.top, 1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LuckyTheme.textTertiary)
                .fixedSize()
                .padding(.top, 1)
            Text(lines.isEmpty ? fallback : lines.joined(separator: "\n"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LuckyTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(spacing: 6) {
                editButton
                HStack(spacing: 6) { copyButton; moreMenu }
            }
        } else {
            HStack(spacing: 6) { copyButton; editButton; moreMenu }
        }
    }

    private var editButton: some View {
        WebRuleActionButton(title: "编辑", symbol: "pencil", selected: true,
                            compact: true, disabled: busy) {
            actions.editSub(rule.id, entry.id)
        }
        .accessibilityLabel("编辑子规则 \(entry.name)")
    }

    private var copyButton: some View {
        WebRuleActionButton(title: "复制网址", symbol: LuckySymbol.copy,
                            compact: true, disabled: entry.domains.isEmpty) {
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
            WebRuleActionLabel(symbol: "ellipsis", fills: false, compact: true)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.45 : 1)
        .accessibilityLabel("子规则 \(entry.name) 的更多操作")
    }
}
