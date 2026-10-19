import SwiftUI

/// `app/(tabs)/settings.tsx`.
struct SettingsScreen: View {
    @State private var session = LuckySession.shared
    @State private var busy = false
    @State private var confirming = false

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.section) {
            connection
            security
            LuckyCard {
                LuckySectionHeader(title: "当前会话", subtitle: "本机凭据与登录状态",
                                   symbol: "person.crop.circle", iconRole: .account)
                LuckyHairline()
                logout
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // `Alert.alert('退出登录', '确定结束当前 Lucky 会话吗？', …)` — a decision, so it stays an
        // alert rather than becoming a toast.
        .alert("退出登录", isPresented: $confirming) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { leave() }
        } message: {
            Text("确定结束当前 Lucky 会话吗？")
        }
    }

    private var connection: some View {
        LuckyCard {
            LuckySectionHeader(title: "服务器", subtitle: "当前管理目标", symbol: "server.rack",
                               iconRole: .server)
            LuckyHairline()
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: "server.rack", size: 48, glyph: 22, role: .server)
                VStack(alignment: .leading, spacing: LuckyTheme.Space.xs) {
                    Text(session.account.isEmpty ? "管理员" : session.account)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LuckyTheme.textPrimary)
                }
                Spacer(minLength: LuckyTheme.Space.s)
                LuckyChip(text: "已连接", tone: .ok, symbol: "checkmark")
            }
            Text(session.baseUrl)
                .font(LuckyTheme.Text.codeSmall)
                .foregroundStyle(LuckyTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack(spacing: 0) {
                connectionFact("person.fill", "账号", "已保存", .account)
                Rectangle().fill(LuckyTheme.separator).frame(width: 1, height: 34)
                connectionFact("key.fill", "凭据", "安全存储", .security)
            }
            .padding(.vertical, LuckyTheme.Space.m)
            .background(LuckyTheme.surfaceRaised,
                        in: .rect(cornerRadius: LuckyTheme.Radius.row))
        }
    }

    private func connectionFact(_ symbol: String, _ label: String, _ value: String,
                                _ iconRole: LuckyIconRole) -> some View {
        HStack(spacing: 8) {
            LuckyIconTile(symbol: symbol, size: 28, glyph: 12, role: iconRole)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LuckyTheme.textTertiary)
                Text(value).font(LuckyTheme.Text.captionMedium)
                    .foregroundStyle(LuckyTheme.textPrimary)
            }
        }
        .padding(.horizontal, LuckyTheme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var security: some View {
        LuckyCard {
            LuckySectionHeader(title: "安全", subtitle: "连接与存储策略",
                               symbol: "checkmark.shield", iconRole: .security)
            LuckyHairline()
            HStack(alignment: .top, spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: "lock.shield.fill", size: 40, glyph: 18, role: .security)
                VStack(alignment: .leading, spacing: 5) {
                    Text("连接安全")
                        .font(LuckyTheme.Text.cardTitle)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    Text("公网访问时应在 Lucky 前配置 HTTPS 与访问控制。")
                        .font(LuckyTheme.Text.body)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LuckyInset {
                LuckyRow("管理 Token", "仅保存在设备安全存储", tone: .ok)
            }
        }
    }

    private var logout: some View {
        let shape = RoundedRectangle(cornerRadius: LuckyTheme.Radius.row, style: .continuous)
        return Button {
            confirming = true
        } label: {
            HStack(spacing: LuckyTheme.Space.s) {
                LuckyIconTile(symbol: "rectangle.portrait.and.arrow.right", size: 28,
                              glyph: 13, tone: .danger)
                Text(busy ? "正在退出" : "退出登录")
                    .font(LuckyTheme.Text.button)
            }
            .foregroundStyle(LuckyTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(shape.fill(LuckyTheme.surface))
            .overlay(shape.strokeBorder(LuckyTheme.danger, lineWidth: LuckyTheme.strokeWidth))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    /// `leave()`: tell the server, then drop the local session whatever the server said — a failed
    /// `/api/logout` must not trap the user in a session they asked to end. The root view swaps to
    /// the login screen as soon as the token clears, which is `router.replace('/login')`.
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
