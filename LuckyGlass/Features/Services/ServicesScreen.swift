import SwiftUI

/// Service destinations share a grouped list layout and searchable vocabulary.
struct ServicesScreen: View {
    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var search = ""

    private struct Entry: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
        var role: LuckyIconRole
        var keywords: String
        var route: LuckyRoute
    }

    private static let managementEntries: [Entry] = [
        Entry(id: "web", title: "反向代理", detail: "域名、监听与 TLS 规则",
              symbol: LuckySymbol.kind(.webservice), role: .web, keywords: "Web 代理 网络",
              route: .webservice),
        Entry(id: "docker", title: "Docker", detail: "容器、镜像与 Compose",
              symbol: LuckySymbol.kind(.docker), role: .docker, keywords: "存储 网络",
              route: .docker()),
        Entry(id: "ddns", title: "动态域名", detail: "自动更新域名解析",
              symbol: LuckySymbol.kind(.ddns), role: .ddns, keywords: "DDNS 自动化",
              route: .service(.ddns)),
        Entry(id: "ssl", title: "SSL 证书", detail: "证书申请与自动续期",
              symbol: LuckySymbol.kind(.ssl), role: .security, keywords: "HTTPS 安全",
              route: .service(.ssl)),
    ]

    private static let toolsEntry = Entry(
        id: "tools", title: "接口调试", detail: "浏览模块与 API 端点",
        symbol: LuckySymbol.debugger, role: .tools, keywords: "模块 开发 工具",
        route: .moduleIndex
    )

    private var management: [Entry] { Self.managementEntries.filter(matches) }

    private var tunnels: [Entry] {
        TunnelKind.allCases.map { kind in
            Entry(id: kind.rawValue, title: kind.title, detail: kind.detail,
                  symbol: kind.symbol, role: kind.iconRole, keywords: "内网穿透 隧道 代理",
                  route: .tunnel(kind))
        }.filter(matches)
    }

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.section) {
            LuckyScreenHeader(title: "服务", subtitle: "网络、容器与隧道，集中管理") {
                LuckyIconTile(symbol: "square.grid.2x2", size: 48, glyph: 21, role: .neutral)
            }
            LuckySearchField(text: $search, placeholder: "搜索服务、隧道或工具")

            if management.isEmpty, tunnels.isEmpty, !matches(Self.toolsEntry) {
                LuckyEmptyState(symbol: LuckySymbol.search, title: "没有匹配的服务",
                                message: "尝试搜索 Docker、证书或隧道名称")
            } else {
                if horizontalSizeClass == .regular, !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: LuckyTheme.Space.section) {
                        if !management.isEmpty {
                            group("服务管理", detail: "网络与自动化", entries: management)
                        }
                        if !tunnels.isEmpty {
                            group("内网穿透", detail: "隧道与远程连接", entries: tunnels)
                        }
                    }
                } else {
                    if !management.isEmpty {
                        group("服务管理", detail: "网络与自动化", entries: management)
                    }
                    if !tunnels.isEmpty {
                        group("内网穿透", detail: "隧道与远程连接", entries: tunnels)
                    }
                }
                if matches(Self.toolsEntry) {
                    group("更多工具", detail: "", entries: [Self.toolsEntry])
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func group(_ title: String, detail: String, entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            LuckySectionHeader(title: title, subtitle: detail) {
                Text("\(entries.count) 项")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
            }
            .padding(.horizontal, LuckyTheme.Space.xs)
            LuckyCard(padding: 0, spacing: 0) {
                ForEach(entries) { entry in
                    if entry.id != entries.first?.id {
                        LuckyHairline().padding(.leading, LuckyTheme.Space.cardInset + 56)
                    }
                    Button {
                        LuckyHaptic.selection()
                        navigator.push(entry.route)
                    } label: {
                        HStack(spacing: LuckyTheme.Space.l) {
                            LuckyIconTile(symbol: entry.symbol, size: 40, glyph: 19, role: entry.role)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.title)
                                    .font(LuckyTheme.Text.cardTitle)
                                    .foregroundStyle(LuckyTheme.textPrimary)
                                Text(entry.detail)
                                    .font(LuckyTheme.Text.caption)
                                    .foregroundStyle(LuckyTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(LuckyTheme.Text.captionMedium)
                                .foregroundStyle(LuckyTheme.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(LuckyTheme.Space.cardInset)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(LuckyPressStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func matches(_ entry: Entry) -> Bool {
        let needle = search.jsTrimmed
        return needle.isEmpty || "\(entry.title) \(entry.detail) \(entry.keywords) \(entry.id)"
            .range(of: needle, options: .caseInsensitive) != nil
    }
}

#if DEBUG
private struct ServicesScreenPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack { ServicesScreen() }
                .preferredColorScheme(.light).previewDisplayName("服务 · 浅色")
            NavigationStack { ServicesScreen() }
                .preferredColorScheme(.dark).previewDisplayName("服务 · 深色")
            NavigationStack { ServicesScreen() }
                .dynamicTypeSize(.accessibility2).previewDisplayName("服务 · 大字体")
        }
    }
}
#endif
