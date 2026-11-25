import SwiftUI

/// Service destinations share a compact grouped list layout so all seven services stay visible at once.
struct ServicesScreen: View {
    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct Entry: Identifiable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
        var role: LuckyIconRole
        var route: LuckyRoute
    }

    private static let managementEntries: [Entry] = [
        Entry(id: "web", title: "反向代理", detail: "域名、监听与 TLS 规则",
              symbol: LuckySymbol.kind(.webservice), role: .web,
              route: .webservice),
        Entry(id: "docker", title: "Docker", detail: "容器、镜像与 Compose",
              symbol: LuckySymbol.kind(.docker), role: .docker,
              route: .docker()),
        Entry(id: "ddns", title: "动态域名", detail: "自动更新域名解析",
              symbol: LuckySymbol.kind(.ddns), role: .ddns,
              route: .service(.ddns)),
        Entry(id: "ssl", title: "SSL 证书", detail: "证书申请与自动续期",
              symbol: LuckySymbol.kind(.ssl), role: .security,
              route: .service(.ssl)),
    ]

    private var tunnels: [Entry] {
        TunnelKind.allCases.map { kind in
            Entry(id: kind.rawValue, title: kind.title, detail: kind.detail,
                  symbol: kind.symbol, role: kind.iconRole,
                  route: .tunnel(kind))
        }
    }

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.l) {
            LuckyScreenHeader(title: "服务", subtitle: "网络、容器与隧道，集中管理")

            if horizontalSizeClass == .regular, !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: LuckyTheme.Space.l) {
                    group("服务管理", detail: "网络与自动化", entries: Self.managementEntries)
                    group("内网穿透", detail: "隧道与远程连接", entries: tunnels)
                }
            } else {
                group("服务管理", detail: "网络与自动化", entries: Self.managementEntries)
                group("内网穿透", detail: "隧道与远程连接", entries: tunnels)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func group(_ title: String, detail: String, entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
            LuckySectionHeader(title: title, subtitle: detail) {
                Text("\(entries.count) 项")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
            }
            .padding(.horizontal, LuckyTheme.Space.xs)
            LuckyCard(padding: 0, spacing: 0) {
                ForEach(entries) { entry in
                    if entry.id != entries.first?.id {
                        LuckyHairline().padding(.leading, LuckyTheme.Space.l + 36 + LuckyTheme.Space.m)
                    }
                    Button {
                        LuckyHaptic.selection()
                        navigator.push(entry.route)
                    } label: {
                        HStack(spacing: LuckyTheme.Space.m) {
                            LuckyIconTile(symbol: entry.symbol, size: 36, glyph: 17, role: entry.role)
                            VStack(alignment: .leading, spacing: 3) {
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
                        .padding(.horizontal, LuckyTheme.Space.l)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(LuckyPressStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
