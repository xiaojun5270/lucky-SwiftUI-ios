import SwiftUI

private enum ManagementService: CaseIterable, Identifiable, Hashable {
    case webservice, docker, ddns, ssl

    var id: Self { self }

    var title: String {
        switch self {
        case .webservice: "反向代理"
        case .docker: "Docker"
        case .ddns: "动态域名"
        case .ssl: "SSL 证书"
        }
    }

    var detail: String {
        switch self {
        case .webservice: "代理与 TLS"
        case .docker: "容器与镜像"
        case .ddns: "域名解析"
        case .ssl: "证书续期"
        }
    }

    var symbol: String {
        switch self {
        case .webservice: "globe.asia.australia"
        case .docker: "shippingbox"
        case .ddns: "arrow.triangle.2.circlepath"
        case .ssl: "checkmark.shield"
        }
    }

    var iconRole: LuckyIconRole {
        switch self {
        case .webservice: .web
        case .docker: .docker
        case .ddns: .ddns
        case .ssl: .security
        }
    }

    var route: LuckyRoute {
        switch self {
        case .webservice: .webservice
        case .docker: .docker()
        case .ddns: .service(.ddns)
        case .ssl: .service(.ssl)
        }
    }

    var searchText: String {
        switch self {
        case .webservice: "反向代理 Web TLS 域名 监听"
        case .docker: "Docker 容器 镜像 网络 存储"
        case .ddns: "动态域名 DDNS 域名解析"
        case .ssl: "SSL 证书 HTTPS 续期"
        }
    }
}

/// `app/(tabs)/manage.tsx`.
///
/// The seven service entry points, grouped by direct management and tunnelling.
struct ServicesScreen: View {
    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var search = ""

    private static let managementServices = ManagementService.allCases
    private static let tunnelKinds = TunnelKind.allCases

    private var filteredManagementServices: [ManagementService] {
        Self.managementServices.filter { matches($0.searchText) }
    }

    private var filteredTunnelKinds: [TunnelKind] {
        Self.tunnelKinds.filter { kind in
            matches("内网穿透 隧道 代理 \(kind.rawValue) \(kind.title) \(kind.detail)")
        }
    }

    private var hasManagementMatches: Bool { !filteredManagementServices.isEmpty }

    private var hasResults: Bool { hasManagementMatches || !filteredTunnelKinds.isEmpty }

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.section) {
            LuckyPageHero(title: "服务", subtitle: "管理网络、容器与内网穿透")
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
            LuckyCard(padding: 0, spacing: 0) {
                ForEach(filteredManagementServices) { service in
                    if let first = filteredManagementServices.first, service != first {
                        LuckyHairline()
                            .padding(.leading, LuckyTheme.Space.cardInset + 38 + LuckyTheme.Space.m)
                    }
                    ServiceListRow(symbol: service.symbol, label: service.title,
                                   detail: service.detail, iconRole: service.iconRole) {
                        navigator.push(service.route)
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

private struct ServiceListRow: View {
    var symbol: String
    var label: String
    var detail: String
    var iconRole: LuckyIconRole
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: symbol, size: 34, glyph: 15, role: iconRole)
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LuckyTheme.textTertiary)
            }
            .padding(.horizontal, LuckyTheme.Space.cardInset)
            .padding(.vertical, LuckyTheme.Space.m)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
