import SwiftUI

struct SettingsScreen: View {
    @State private var session = LuckySession.shared
    @State private var busy = false
    @State private var confirming = false

    private var usesHTTPS: Bool {
        URL(string: session.baseUrl)?.scheme?.lowercased() == "https"
    }

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.section, maxWidth: LuckyTheme.Layout.settingsWidth) {
            LuckyScreenHeader(title: "设置", subtitle: "账户、服务器与连接安全")
            account
            connection
            security
            sessionActions
            VStack(spacing: LuckyTheme.Space.xs) {
                Text("LuckyGlass · Lucky 的原生管理客户端")
                Text(LuckyAppVersion.displayString)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }
            .font(LuckyTheme.Text.caption)
            .foregroundStyle(LuckyTheme.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LuckyTheme.Space.s)
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("退出登录", isPresented: $confirming) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { leave() }
        } message: {
            Text("确定结束当前 Lucky 会话吗？")
        }
    }

    private var account: some View {
        LuckyCard {
            HStack(spacing: LuckyTheme.Space.l) {
                LuckyIconTile(symbol: "person.crop.circle", size: 56, glyph: 28, role: .account)
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.account.isEmpty ? "管理员" : session.account)
                        .font(LuckyTheme.Text.title)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    Text("当前登录账户")
                        .font(LuckyTheme.Text.body)
                        .foregroundStyle(LuckyTheme.textSecondary)
                }
                Spacer(minLength: 0)
                LuckyChip(text: "管理员", tone: .idle)
            }
        }
    }

    private var connection: some View {
        LuckySection(title: "服务器") {
            HStack(alignment: .top, spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: "server.rack", size: 40, glyph: 19, role: .server)
                VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
                    Text(URL(string: session.baseUrl)?.host ?? "Lucky 服务器")
                        .font(LuckyTheme.Text.cardTitle)
                        .foregroundStyle(LuckyTheme.textPrimary)
                        .textSelection(.enabled)
                    Text(session.baseUrl)
                        .font(LuckyTheme.Text.code)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            LuckyHairline()
            LuckyRow("连接协议", usesHTTPS ? "HTTPS" : "HTTP", mono: true)
        }
    }

    private var security: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            LuckySection(title: "安全与隐私", spacing: LuckyTheme.Space.l) {
                securityRow("key", "登录凭据", detail: "保存在设备钥匙串", role: .security)
                LuckyHairline().padding(.leading, 52)
                securityRow(usesHTTPS ? "lock.shield" : "network", "服务器连接",
                            detail: usesHTTPS ? "HTTPS 加密传输" : "HTTP 连接",
                            role: usesHTTPS ? .security : .network)
            }
            if !usesHTTPS {
                Text("公网访问建议为 Lucky 配置 HTTPS 与访问控制。")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .padding(.horizontal, LuckyTheme.Space.xs)
            }
        }
    }

    private func securityRow(_ symbol: String, _ title: String, detail: String,
                             role: LuckyIconRole) -> some View {
        HStack(spacing: LuckyTheme.Space.m) {
            LuckyIconTile(symbol: symbol, size: 36, glyph: 17, role: role)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(LuckyTheme.Text.bodyMedium)
                    .foregroundStyle(LuckyTheme.textPrimary)
                Text(detail)
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var sessionActions: some View {
        LuckySection(title: "当前会话", padding: 0) {
            Button(role: .destructive) {
                confirming = true
            } label: {
                HStack(spacing: LuckyTheme.Space.m) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(LuckyTheme.Text.bodyMedium)
                        .frame(width: 36)
                    Text(busy ? "正在退出…" : "退出登录")
                        .font(LuckyTheme.Text.bodyMedium)
                    Spacer(minLength: 0)
                    if busy { ProgressView().tint(LuckyTheme.danger) }
                }
                .foregroundStyle(LuckyTheme.danger)
                .padding(LuckyTheme.Space.cardInset)
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }

    private func leave() {
        guard !busy else { return }
        busy = true
        Task {
            do { _ = try await LuckyService.logout() } catch {}
            await session.end()
            busy = false
        }
    }
}

#if DEBUG
private struct SettingsScreenPreviews: PreviewProvider {
    static var previews: some View {
        NavigationStack { SettingsScreen() }
    }
}
#endif
