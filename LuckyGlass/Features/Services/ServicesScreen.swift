import SwiftUI

/// `app/(tabs)/manage.tsx`.
///
/// The seven service entry points, grouped by direct management and tunnelling.
struct ServicesScreen: View {
    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var search = ""

    private static let tunnelKinds = TunnelKind.allCases

    private var filteredTunnelKinds: [TunnelKind] {
        Self.tunnelKinds.filter { kind in
            matches("内网穿透 隧道 代理 \(kind.rawValue) \(kind.title) \(kind.detail)")
        }
    }

    private var hasManagementMatches: Bool {
        matches("反向代理 Web TLS 域名 监听")
            || matches("Docker 容器 镜像 网络 存储")
            || matches("动态域名 DDNS 域名解析")
            || matches("SSL 证书 HTTPS 续期")
    }

    private var hasResults: Bool { hasManagementMatches || !filteredTunnelKinds.isEmpty }

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.section) {
            LuckySearchField(text: $search, placeholder: "搜索服务")

            if !hasResults {
                LuckyEmptyState(symbol: LuckySymbol.search, title: "没有匹配的服务",
                                message: "尝试搜索 Docker、证书或隧道名称")
            } else if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: LuckyTheme.Space.section) {
                    if hasManagementMatches { managementSection }
                    if !filteredTunnelKinds.isEmpty { tunnelSection }
                }
            } else {
                if hasManagementMatches { managementSection }
                if !filteredTunnelKinds.isEmpty { tunnelSection }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            LuckySectionHeader(title: "服务管理", subtitle: "网络、容器与自动化",
                               symbol: "square.grid.2x2.fill", iconRole: .neutral)
            LuckyTileGrid(minimum: 145, spacing: LuckyTheme.Space.m) {
                if matches("反向代理 Web TLS 域名 监听") {
                    ServiceCompactTile(symbol: "globe.asia.australia", label: "反向代理",
                                       detail: "代理与 TLS",
                                       iconRole: LuckyServiceKind.webservice.iconRole) {
                        navigator.push(.webservice)
                    }
                }
                if matches("Docker 容器 镜像 网络 存储") {
                    ServiceCompactTile(symbol: "shippingbox", label: "Docker",
                                       detail: "容器与镜像",
                                       iconRole: LuckyServiceKind.docker.iconRole) {
                        navigator.push(.docker())
                    }
                }
                if matches("动态域名 DDNS 域名解析") {
                    ServiceCompactTile(symbol: "arrow.triangle.2.circlepath", label: "动态域名",
                                       detail: "域名解析",
                                       iconRole: LuckyServiceKind.ddns.iconRole) {
                        navigator.push(.service(.ddns))
                    }
                }
                if matches("SSL 证书 HTTPS 续期") {
                    ServiceCompactTile(symbol: "checkmark.shield", label: "SSL 证书",
                                       detail: "证书续期",
                                       iconRole: LuckyServiceKind.ssl.iconRole) {
                        navigator.push(.service(.ssl))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var tunnelSection: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            LuckySectionHeader(title: "内网穿透", subtitle: "隧道与代理",
                               symbol: "point.3.connected.trianglepath.dotted", iconRole: .tunnels)
            LuckyCard(padding: 0, spacing: 0) {
                ForEach(filteredTunnelKinds) { kind in
                    if let first = filteredTunnelKinds.first, kind != first {
                        LuckyHairline()
                            .padding(.leading, LuckyTheme.Space.cardInset + 38 + LuckyTheme.Space.m)
                    }
                    ServiceListRow(symbol: kind.symbol, label: kind.title, detail: kind.detail,
                                   iconRole: kind.iconRole) {
                        navigator.push(.tunnel(kind))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func matches(_ haystack: String) -> Bool {
        let needle = search.jsTrimmed
        return needle.isEmpty || haystack.range(of: needle, options: .caseInsensitive) != nil
    }
}

private struct ServiceCompactTile: View {
    var symbol: String
    var label: String
    var detail: String
    var iconRole: LuckyIconRole
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
                HStack {
                    LuckyIconTile(symbol: symbol, size: 40, glyph: 18, role: iconRole)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: LuckyTheme.Space.xs) {
                    Text(label)
                        .font(LuckyTheme.Text.cardTitle)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    Text(detail)
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        }
        .buttonStyle(LuckyCardButtonStyle(radius: LuckyTheme.Radius.card))
    }
}

private struct ServiceListRow: View {
    var symbol: String
    var label: String
    var detail: String
    var iconRole: LuckyIconRole
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: symbol, size: 38, glyph: 17, role: iconRole)
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).font(LuckyTheme.Text.cardTitle)
                    Text(detail)
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .lineLimit(1)
                }
                .foregroundStyle(LuckyTheme.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LuckyTheme.textTertiary)
            }
            .padding(.horizontal, LuckyTheme.Space.cardInset)
            .padding(.vertical, LuckyTheme.Space.m)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
