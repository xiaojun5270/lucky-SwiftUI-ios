import SwiftUI

struct SettingsScreen: View {
    @State private var session = LuckySession.shared
    @AppStorage(LuckyAppearance.storageKey) private var appearanceRaw = LuckyAppearance.system.rawValue
    @State private var busy = false
    @State private var confirming = false
    @State private var showingAccounts = false
    @State private var cacheBytes: Int64 = 0
    @State private var clearingCache = false
    @State private var confirmingClearCache = false
    @State private var toast: LuckyToast?

    private var usesHTTPS: Bool {
        URL(string: session.baseUrl)?.scheme?.lowercased() == "https"
    }

    private var appearanceBinding: Binding<LuckyAppearance> {
        Binding(
            get: { LuckyAppearance(rawValue: appearanceRaw) ?? .system },
            set: { next in
                LuckyHaptic.selection()
                appearanceRaw = next.rawValue
            }
        )
    }

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.l, maxWidth: LuckyTheme.Layout.settingsWidth) {
            LuckyScreenHeader(title: "设置", subtitle: "账户、外观、缓存与连接安全")
            account
            connection
            appearanceAndCache
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
        .luckyToast($toast)
        .task { cacheBytes = await DockerStatsCache.totalDiskCacheBytes() }
        .sheet(isPresented: $showingAccounts) {
            DashboardAccountPicker()
        }
        .alert("退出登录", isPresented: $confirming) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { leave() }
        } message: {
            Text("确定结束当前 Lucky 会话吗？")
        }
        .alert("清理本地缓存", isPresented: $confirmingClearCache) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) { clearCache() }
        } message: {
            Text("将清除本地持久化的 Docker 列表、统计、图标与 Web 规则缓存，不影响服务器数据。")
        }
    }

    private var account: some View {
        LuckyCard {
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: "person.crop.circle", size: 52, glyph: 26, role: .account)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: LuckyTheme.Space.xs) {
                        Text(session.account.isEmpty ? "管理员" : session.account)
                            .font(LuckyTheme.Text.title)
                            .foregroundStyle(LuckyTheme.textPrimary)
                            .lineLimit(1)
                        if !session.remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("(\(session.remark.trimmingCharacters(in: .whitespacesAndNewlines)))")
                                .font(LuckyTheme.Text.body)
                                .foregroundStyle(LuckyTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Text("当前登录账户 · \(session.profiles.count) 个已保存账号")
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: LuckyTheme.Space.xs)
                Button {
                    LuckyHaptic.selection()
                    showingAccounts = true
                } label: {
                    HStack(spacing: 4) {
                        Text("切换")
                        Image(systemName: "chevron.right")
                    }
                    .font(LuckyTheme.Text.captionMedium)
                    .foregroundStyle(LuckyTheme.accent)
                    .padding(.horizontal, LuckyTheme.Space.m)
                    .frame(minHeight: 36)
                    .background(LuckyTheme.accentSoft, in: .capsule)
                    .frame(minHeight: LuckyTheme.Space.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(LuckyPressStyle(pressedScale: 0.95, pressedOpacity: 0.75))
                .accessibilityLabel("切换已保存的账号")
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
                Button {
                    LuckyClipboard.copy(session.baseUrl)
                    LuckyHaptic.success()
                    toast = .ok("已复制服务器地址")
                } label: {
                    Image(systemName: LuckySymbol.copy)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LuckyTheme.accent)
                        .frame(width: LuckyTheme.Space.touchTarget, height: LuckyTheme.Space.touchTarget)
                        .background(LuckyTheme.accentSoft, in: .circle)
                }
                .buttonStyle(LuckyPressStyle(pressedScale: 0.92, pressedOpacity: 0.7))
                .accessibilityLabel("复制服务器地址")
            }
            LuckyHairline()
            LuckyRow("连接协议", usesHTTPS ? "HTTPS 加密" : "HTTP 明文",
                     mono: false, tone: usesHTTPS ? .ok : .warning)
        }
    }

    private var appearanceAndCache: some View {
        LuckySection(title: "显示与缓存", spacing: LuckyTheme.Space.m) {
            VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
                HStack(spacing: LuckyTheme.Space.s) {
                    LuckyIconTile(symbol: "circle.lefthalf.filled", size: 28, glyph: 14, role: .settings)
                    Text("外观主题")
                        .font(LuckyTheme.Text.bodyMedium)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    Spacer(minLength: 0)
                }
                Picker("外观主题", selection: appearanceBinding) {
                    ForEach(LuckyAppearance.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            LuckyHairline()
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: LuckySymbol.disk, size: 28, glyph: 14, role: .storage)
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地缓存")
                        .font(LuckyTheme.Text.bodyMedium)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    Text("Docker、图标与 Web 规则 · \(Format.bytes(Double(cacheBytes)))")
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    LuckyHaptic.warning()
                    confirmingClearCache = true
                } label: {
                    Group {
                        if clearingCache {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("清理")
                        }
                    }
                    .font(LuckyTheme.Text.captionMedium)
                    .foregroundStyle(cacheBytes > 0 ? LuckyTheme.danger : LuckyTheme.textTertiary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(
                        (cacheBytes > 0 ? LuckyTheme.dangerSoft : LuckyTheme.surfaceRaised),
                        in: .capsule
                    )
                }
                .buttonStyle(LuckyPressStyle(pressedScale: 0.94, pressedOpacity: 0.75))
                .disabled(clearingCache || cacheBytes == 0)
                .accessibilityLabel("清理本地缓存")
            }
        }
    }

    private var security: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
            LuckySection(title: "安全与隐私", spacing: LuckyTheme.Space.m) {
                securityRow("key", "系统钥匙串", detail: "凭据仅存于本机钥匙串", role: .security)
                LuckyHairline().padding(.leading, 40)
                securityRow("lock.shield", "直连通信",
                            detail: "直连 Lucky 实例，无第三方中转",
                            role: .security)
            }
            if !usesHTTPS {
                Text("当前为 HTTP 连接，公网访问建议为 Lucky 配置 HTTPS 与访问控制。")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.warning)
                    .padding(.horizontal, LuckyTheme.Space.xs)
            }
        }
    }

    private func securityRow(_ symbol: String, _ title: String, detail: String,
                             role: LuckyIconRole) -> some View {
        HStack(spacing: LuckyTheme.Space.m) {
            LuckyIconTile(symbol: symbol, size: 28, glyph: 14, role: role)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LuckyTheme.Text.captionMedium)
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
                LuckyHaptic.warning()
                confirming = true
            } label: {
                HStack(spacing: LuckyTheme.Space.m) {
                    LuckyIconTile(symbol: "rectangle.portrait.and.arrow.right", size: 32, glyph: 16, tone: .danger)
                    Text(busy ? "正在退出…" : "退出登录")
                        .font(LuckyTheme.Text.bodyMedium)
                    Spacer(minLength: 0)
                    if busy { ProgressView().tint(LuckyTheme.danger) }
                }
                .foregroundStyle(LuckyTheme.danger)
                .padding(.horizontal, LuckyTheme.Space.cardInset)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(LuckyPressStyle())
            .disabled(busy)
        }
    }

    private func clearCache() {
        guard !clearingCache else { return }
        clearingCache = true
        Task {
            await DockerStatsCache.shared.clearAllDiskCaches()
            cacheBytes = await DockerStatsCache.totalDiskCacheBytes()
            clearingCache = false
            LuckyHaptic.success()
            toast = .ok("已清理本地缓存")
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
