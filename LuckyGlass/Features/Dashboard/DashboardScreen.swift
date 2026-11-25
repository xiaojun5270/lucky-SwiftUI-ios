import SwiftUI

/// A denser rhythm for the overview only; shared page/card defaults stay unchanged.
private enum DashboardLayout {
    static let cardGap: CGFloat = 12
    static let cardInset: CGFloat = 12
    static let contentGap: CGFloat = 10
}

/// `app/(tabs)/monitor.tsx` — the 总览 tab.
///
/// Two feeds run at once: the status socket publishes live frames and the reverse-proxy rule list
/// refreshes every 30 s. Both are gated on
/// `dockerActive = isFocused && appIsActive`, so a backgrounded app holds no socket and issues no
/// requests. The socket is the shared reference-counted stream, so leaving the tab drops the
/// connection but keeps the last frame on screen instead of blanking the charts.

/// Dashboard headers share one optical size without changing headers elsewhere in the app.
private struct DashboardSectionHeader<Trailing: View>: View {
    var title: String
    var symbol: String
    var iconRole: LuckyIconRole
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                heading
                Spacer(minLength: LuckyTheme.Space.s)
                trailing()
            }
            VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
                heading
                trailing()
            }
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var heading: some View {
        HStack(spacing: 10) {
            LuckyIconTile(symbol: symbol, size: 32, glyph: 16, role: iconRole)
            Text(title)
                .font(LuckyTheme.Text.cardTitle)
                .foregroundStyle(LuckyTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension DashboardSectionHeader where Trailing == EmptyView {
    init(title: String, symbol: String, iconRole: LuckyIconRole) {
        self.init(title: title, symbol: symbol, iconRole: iconRole) { EmptyView() }
    }
}

/// `webRuleText(rule, keys, fallback)`: the first key holding a string or a number, as a string.
/// Deliberately not `JSONUnwrap.pick`, which also accepts arrays and would render a list-valued
/// field as `"a, b"` where the original falls back.
private func webRuleText(_ rule: JSONValue, _ keys: [String], _ fallback: String) -> String {
    for key in keys {
        guard let value = rule[key] else { continue }
        if case .string(let text) = value { return text }
        if case .number(let number) = value { return JSONSerializer.numberString(number) }
    }
    return fallback
}

/// `webSubRules(rule)`: `ProxyList` under any of its three spellings, keeping only the object
/// elements. The first non-null spelling wins even when it is not an array, which is what `??`
/// followed by `Array.isArray` does.
private func webSubRules(_ rule: JSONValue) -> [JSONValue] {
    for key in ["ProxyList", "proxyList", "proxies"] {
        guard let value = rule[key], !value.isNull else { continue }
        return value.arrayValue?.filter(\.isRecord) ?? []
    }
    return []
}

/// `asEnabled(rule.Enable ?? rule.enable)`, spelled out as a loop: JavaScript's `??` falls through
/// on `null`, which is a value here rather than an absence, while an empty string must *not* fall
/// through — it has to reach `asEnabled` and take the fallback there.
private func webRuleFlag(_ rule: JSONValue, _ keys: [String], fallback: Bool = true) -> Bool {
    for key in keys {
        guard let value = rule[key], !value.isNull else { continue }
        return Format.asEnabled(value, fallback: fallback)
    }
    return fallback
}

/// `<Legend>`: an 8pt dot and a caption. Takes a tone rather than a colour so a dot and the line it
/// explains cannot drift apart.
private struct DashboardLegend: View {
    var label: String
    var tone: LuckyTone

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tone.tint)
                .frame(width: 8, height: 8)
            Text(label)
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textTertiary)
                .lineLimit(1)
        }
    }
}

/// Both `Pressable`s in the reverse-proxy header dim to 0.62 while held.
private struct DashboardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.62 : 1)
    }
}

/// Keeps observation of the high-frequency status store inside a small subtree. The dashboard
/// shell, reverse-proxy rules and navigation controls no longer invalidate on every socket frame.
private struct DashboardLiveReader<Content: View>: View {
    @ViewBuilder var content: (LuckyStatusStore) -> Content

    var body: some View {
        content(LuckyStatusStore.shared)
    }
}

/// Live resource gauges lead; process details stay secondary in a quiet footer.
private struct DashboardHostPanel: View {
    var status: LuckyLiveStatus?
    var connected: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var memory: Double {
        guard let status else { return 0 }
        return Format.percent(status.usedMem, status.totalMem)
    }

    var body: some View {
        LuckyCard(padding: 0, spacing: 0) {
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: LuckySymbol.monitor, size: 32, glyph: 16, role: .system)
                VStack(alignment: .leading, spacing: 3) {
                    Text("运行状态")
                        .font(LuckyTheme.Text.cardTitle)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    Text(connected ? "实时资源使用情况" : "等待状态流连接")
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textSecondary)
                }
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    LuckyStatusDot(tone: connected ? .ok : .warning, pulsing: connected, size: 7)
                    Text(connected ? "在线" : "连接中")
                        .font(LuckyTheme.Text.captionMedium)
                        .lineLimit(1)
                }
                .foregroundStyle(connected ? LuckyTheme.success : LuckyTheme.warning)
                .padding(.horizontal, LuckyTheme.Space.s)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(connected ? LuckyTheme.successSoft : LuckyTheme.warningSoft)
                )
            }
            .padding(DashboardLayout.cardInset)

            resourceLayout {
                LuckyLoadGauge(
                    label: "系统 CPU",
                    value: status?.usedCpu,
                    detail: status.map { "空闲 " + JSCompat.toFixed(max(0, 100 - $0.usedCpu), 1) + "%" }
                )
                if !dynamicTypeSize.isAccessibilitySize { gaugeDivider }
                LuckyLoadGauge(
                    label: "系统内存",
                    value: status == nil ? nil : memory,
                    detail: status.map { "\(Format.bytes($0.usedMem)) / \(Format.bytes($0.totalMem))" }
                )
            }
            .padding(.horizontal, LuckyTheme.Space.l)
            .padding(.vertical, LuckyTheme.Space.s)

            LuckyHairline()

            processLayout {
                metric("进程 CPU",
                       status.map { JSCompat.toFixed($0.currentProcessUsedCpu, 1) + "%" } ?? "--")
                if !dynamicTypeSize.isAccessibilitySize { metricDivider }
                metric("进程内存", status.map { Format.bytes($0.processUsedMem) } ?? "--")
                if !dynamicTypeSize.isAccessibilitySize { metricDivider }
                metric("协程数", status.map { JSONSerializer.numberString($0.goroutine) } ?? "--")
            }
            .padding(.vertical, LuckyTheme.Space.m)
        }
    }

    private var resourceLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: LuckyTheme.Space.xl))
            : AnyLayout(HStackLayout(spacing: 0))
    }

    private var processLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: LuckyTheme.Space.m))
            : AnyLayout(HStackLayout(spacing: 0))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textTertiary)
            Text(value)
                .font(LuckyTheme.Text.bodyMedium)
                .foregroundStyle(LuckyTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, LuckyTheme.Space.m)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var gaugeDivider: some View {
        Rectangle().fill(LuckyTheme.separator).frame(width: 1, height: 82)
    }

    private var metricDivider: some View {
        Rectangle().fill(LuckyTheme.separator).frame(width: 1, height: 40)
    }
}

private struct DashboardQuickLink: View {
    var title: String
    var symbol: String
    var iconRole: LuckyIconRole
    var badge: String
    var live: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            LuckyHaptic.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                LuckyIconTile(symbol: symbol, size: 40, glyph: 19, role: iconRole)
                Text(title)
                    .font(LuckyTheme.Text.captionMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LuckyTheme.textPrimary)
                Text(badge)
                    .font(.system(size: 10, weight: live ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(live ? iconRole.color : LuckyTheme.textTertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .frame(minWidth: LuckyTheme.Space.touchTarget, maxWidth: .infinity, minHeight: 64)
            .frame(maxHeight: .infinity)
            .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: LuckyTheme.Radius.row))
            .overlay(
                RoundedRectangle(cornerRadius: LuckyTheme.Radius.row)
                    .strokeBorder(LuckyTheme.hairline.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.96, pressedOpacity: 0.72))
    }
}

private struct DashboardShortcuts: View {
    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var dockerCache = DockerStatsCache.shared
    @State private var webCache = WebRulesCache.shared

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: LuckyTheme.Space.s),
              count: dynamicTypeSize >= .xxLarge ? 2 : 4)
    }

    private var hasWebLive: Bool {
        webCache.loadedPanes.contains(.rules) && !webCache.rules.isEmpty
    }

    private var webBadge: String {
        hasWebLive ? "\(webCache.enabledRuleCount) 启用" : "规则管理"
    }

    private var hasDockerLive: Bool {
        dockerCache.hasWarmData(for: .containers) && !dockerCache.prebuiltContainerRows.isEmpty
    }

    private var dockerBadge: String {
        hasDockerLive ? "\(dockerCache.runningContainerCount) 运行" : "容器管理"
    }

    var body: some View {
        LuckyCard(padding: DashboardLayout.cardInset, spacing: DashboardLayout.contentGap) {
            DashboardSectionHeader(title: "快捷入口", symbol: "square.grid.2x2", iconRole: .system) {
                Button {
                    navigator.selection = .services
                } label: {
                    HStack(spacing: 4) {
                        Text("全部服务")
                        Image(systemName: "chevron.right")
                    }
                    .font(LuckyTheme.Text.captionMedium)
                    .frame(minHeight: LuckyTheme.Space.touchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LuckyTheme.accent)
            }
            LazyVGrid(columns: columns, spacing: LuckyTheme.Space.s) {
                DashboardQuickLink(title: "反向代理", symbol: "network", iconRole: .web,
                                   badge: webBadge, live: hasWebLive) {
                    navigator.push(.webservice)
                }
                DashboardQuickLink(title: "Docker", symbol: "cube.transparent", iconRole: .docker,
                                   badge: dockerBadge, live: hasDockerLive) {
                    navigator.push(.docker())
                }
                DashboardQuickLink(title: "动态域名", symbol: "globe.asia.australia", iconRole: .ddns,
                                   badge: "域名解析") {
                    navigator.push(.service(.ddns))
                }
                DashboardQuickLink(title: "SSL 证书", symbol: "lock.shield", iconRole: .security,
                                   badge: "证书管理") {
                    navigator.push(.service(.ssl))
                }
            }
        }
    }
}

/// `<ReverseProxyOverview>` — the one non-Docker card on the dashboard: three counts, the first two
/// enabled rules, and a local eye toggle that masks listen ports.
private struct ReverseProxyCard: View {
    var rules: [LuckyListItem]
    /// `ready = Boolean(data)`. react-query keeps the last payload through a later failure, so once
    /// the list has arrived the counts stay up even while the request is failing.
    var ready: Bool
    var loading: Bool
    var failure: String
    var open: () -> Void

    /// The original's `useState(false)`: masking is for the moment someone is looking over your
    /// shoulder, so it is deliberately not persisted.
    @State private var portsMasked = false

    private var enabledRules: [JSONValue] {
        rules.filter { webRuleFlag($0, ["Enable", "enable"]) }
    }

    private var subRules: [JSONValue] { rules.flatMap { webSubRules($0) } }

    private var enabledSubRules: [JSONValue] {
        subRules.filter { webRuleFlag($0, ["Enable", "enable"]) }
    }

    private var tlsRules: [JSONValue] {
        enabledRules.filter { webRuleFlag($0, ["EnableTLS", "enableTLS", "TLS"], fallback: false) }
    }

    private var preview: [JSONValue] { Array(enabledRules.prefix(2)) }

    private var subtitle: String {
        if !failure.isEmpty { return "规则状态暂时无法读取" }
        if loading, !ready { return "正在同步规则状态" }
        return "域名、监听、后端与 TLS 规则"
    }

    var body: some View {
        LuckyCard(padding: DashboardLayout.cardInset, spacing: DashboardLayout.contentGap) {
            header
            statsStrip
            if !preview.isEmpty {
                VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
                    ForEach(preview.indices, id: \.self) { index in
                        previewRow(index, preview[index])
                    }
                }
            } else if ready, failure.isEmpty {
                Text("暂无启用中的反向代理规则")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var header: some View {
        HStack(spacing: LuckyTheme.Space.s) {
            Button(action: open) {
                HStack(spacing: 10) {
                    LuckyIconTile(symbol: "network", size: 32, glyph: 16, role: .web)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("反向代理")
                            .font(LuckyTheme.Text.cardTitle)
                            .foregroundStyle(LuckyTheme.textPrimary)
                        Text(subtitle)
                            .font(LuckyTheme.Text.caption)
                            .foregroundStyle(LuckyTheme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: LuckyTheme.Space.xs)
                    Image(systemName: "chevron.right")
                        .font(LuckyTheme.Text.captionMedium)
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .frame(width: 24, height: 44)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(DashboardPressStyle())
            .accessibilityLabel("打开反向代理规则")
            maskToggle
        }
    }

    private var maskToggle: some View {
        LuckyToolbarButton(
            symbol: portsMasked ? "eye" : "eye.slash",
            label: portsMasked ? "显示端口信息" : "隐藏端口信息",
            tone: portsMasked ? .brand : .idle
        ) {
            portsMasked.toggle()
        }
        .accessibilityAddTraits(portsMasked ? [.isSelected] : [])
    }

    /// Three equal columns divided by hairlines. `--` until the first payload arrives, so an empty
    /// server and an unreached one never read the same.
    private var statsStrip: some View {
        HStack(spacing: 0) {
            statColumn("启用规则", ready ? "\(enabledRules.count)/\(rules.count)" : "--",
                       tint: LuckyTheme.accent, divided: false)
            statColumn("启用子规则", ready ? "\(enabledSubRules.count)/\(subRules.count)" : "--",
                       tint: LuckyTheme.textPrimary, divided: true)
            statColumn("TLS 监听", ready ? String(tlsRules.count) : "--",
                       tint: LuckyTheme.textPrimary, divided: true)
        }
        .frame(minHeight: 56)
        .background(ConcentricRectangle().fill(LuckyTheme.surfaceRaised))
        .clipShape(ConcentricRectangle())
    }

    private func statColumn(_ label: String, _ value: String, tint: Color,
                            divided: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(LuckyTheme.Text.metricSmall)
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
            Text(label)
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, LuckyTheme.Space.s)
        .frame(maxWidth: .infinity, minHeight: 42)
        .overlay(alignment: .leading) {
            if divided {
                Rectangle()
                    .fill(LuckyTheme.hairline)
                    .frame(width: LuckyTheme.strokeWidth)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    /// One preview row: `${network} · ${host}:${visiblePort}` under the rule's name, with its
    /// sub-rule count on the right. A TLS listener is amber and carries a lock instead of a route.
    private func previewRow(_ index: Int, _ rule: JSONValue) -> some View {
        let name = webRuleText(rule, ["RuleName", "Name"], "规则 \(index + 1)")
        let network = webRuleText(rule, ["Network"], "tcp")
        let listen = webRuleText(rule, ["ListenIP"], "*")
        let host = listen.isEmpty ? "*" : listen
        let port = webRuleText(rule, ["ListenPort"], "--")
        let visiblePort = portsMasked && port != "--" ? "••••" : port
        let tls = webRuleFlag(rule, ["EnableTLS", "enableTLS", "TLS"], fallback: false)
        return Button {
            LuckyHaptic.light()
            open()
        } label: {
            HStack(spacing: 9) {
                LuckyIconTile(symbol: tls ? "lock.fill" : "arrow.triangle.branch", size: 28,
                              glyph: 14, role: tls ? .security : .web)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(LuckyTheme.Text.captionMedium)
                        .foregroundStyle(LuckyTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("\(network.uppercased()) · \(host):\(visiblePort)")
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(webSubRules(rule).count) 个子规则")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .frame(minHeight: 44)
            .background(LuckyTheme.surfaceRaised,
                        in: .rect(cornerRadius: LuckyTheme.Radius.row))
            .contentShape(RoundedRectangle(cornerRadius: LuckyTheme.Radius.row, style: .continuous))
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.985, pressedOpacity: 0.72))
        .accessibilityElement(children: .combine)
    }
}

/// Never show URL user-info, query strings or access paths in account chrome.
private func accountServerName(_ baseUrl: String) -> String {
    guard let url = URL(string: baseUrl), let host = url.host else { return "Lucky 服务器" }
    return host + (url.port.map { ":\($0)" } ?? "")
}

struct DashboardAccountPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session = LuckySession.shared
    @State private var showingAddAccount = false
    @State private var switchingID: String?
    @State private var editingProfile: LuckyAccountProfile?
    @State private var remarkDraft = ""
    @State private var deletingProfile: LuckyAccountProfile?

    private var switching: Bool { switchingID != nil }

    var body: some View {
        NavigationStack {
            List {
                Section("已保存的账号") {
                    ForEach(session.profiles) { profile in
                        accountRow(profile)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deletingProfile = profile
                                } label: {
                                    Label("删除", systemImage: LuckySymbol.delete)
                                }
                                Button {
                                    remarkDraft = profile.remark
                                    editingProfile = profile
                                } label: {
                                    Label("备注", systemImage: "pencil")
                                }
                                .tint(LuckyTheme.accent)
                            }
                            .contextMenu {
                                Button {
                                    remarkDraft = profile.remark
                                    editingProfile = profile
                                } label: {
                                    Label("修改备注", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deletingProfile = profile
                                } label: {
                                    Label("删除账号", systemImage: LuckySymbol.delete)
                                }
                            }
                    }
                }
                Section {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Label("添加账号", systemImage: "plus.circle")
                            .frame(minHeight: LuckyTheme.Space.touchTarget)
                    }
                    .accessibilityIdentifier("accounts.add")
                }
            }
            .disabled(switching)
            .navigationTitle("切换账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .disabled(switching)
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                NavigationStack {
                    LoginScreen(addAccount: true)
                }
            }
            .alert("修改备注", isPresented: editingBinding, presenting: editingProfile) { target in
                TextField("输入备注（留空清除）", text: $remarkDraft)
                Button("取消", role: .cancel) { editingProfile = nil }
                Button("保存") {
                    session.updateRemark(remarkDraft, for: target.id)
                    editingProfile = nil
                }
            } message: { target in
                Text("\(target.account) · \(accountServerName(target.baseUrl))")
            }
            .alert("删除已保存账号", isPresented: deletingBinding, presenting: deletingProfile) { target in
                Button("取消", role: .cancel) { deletingProfile = nil }
                Button("删除", role: .destructive) {
                    let targetID = target.id
                    deletingProfile = nil
                    Task { @MainActor in
                        await session.removeProfile(id: targetID)
                        if session.profiles.isEmpty { dismiss() }
                    }
                }
            } message: { target in
                Text("确定从设备钥匙串移除“\(target.displayName)”吗？")
            }
        }
        .interactiveDismissDisabled(switching)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var editingBinding: Binding<Bool> {
        Binding(get: { editingProfile != nil }, set: { if !$0 { editingProfile = nil } })
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deletingProfile != nil }, set: { if !$0 { deletingProfile = nil } })
    }

    private func accountRow(_ profile: LuckyAccountProfile) -> some View {
        let isCurrent = profile.id == session.activeProfileID
        let isSwitching = switchingID == profile.id
        return Button {
            guard !switching else { return }
            guard !isCurrent else { dismiss(); return }
            LuckyHaptic.selection()
            switchingID = profile.id
            Task { @MainActor in
                await session.switchTo(profileID: profile.id)
                switchingID = nil
                dismiss()
            }
        } label: {
            HStack(spacing: LuckyTheme.Space.m) {
                LuckyIconTile(symbol: "person.crop.circle", size: 34, glyph: 16,
                              role: isCurrent ? .docker : .account)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.displayName)
                        .font(LuckyTheme.Text.bodyMedium)
                        .foregroundStyle(LuckyTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(profile.account)
                        Text("·")
                        Text(accountServerName(profile.baseUrl))
                    }
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .lineLimit(1)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: LuckyTheme.Space.s)
                if isSwitching {
                    ProgressView().controlSize(.small)
                } else if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LuckyTheme.accent)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: LuckyTheme.Space.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? "当前账号" : "")
        .accessibilityHint(isCurrent ? "" : "切换到此账号")
        .accessibilityIdentifier("accounts.profile.\(profile.id)")
    }
}

/// The 总览 tab root.
struct DashboardScreen: View {
    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.scenePhase) private var phase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var session = LuckySession.shared
    @State private var showingAccounts = false

    @State private var rules: [LuckyListItem] = []
    @State private var rulesReady = false
    @State private var rulesFailure = ""
    @State private var rulesFetching = false

    init() {
        let cache = WebRulesCache.shared
        cache.activate(credentials: LuckySession.shared.credentials)
        _rules = State(initialValue: cache.rules)
        _rulesReady = State(initialValue: cache.loadedPanes.contains(.rules) || !cache.rules.isEmpty)
    }

    private var live: LuckyStatusStore { .shared }

    /// `dockerActive = isFocused && appIsActive`.
    private var active: Bool { navigator.selection == .dashboard && phase == .active }

    var body: some View {
        LuckyPage(spacing: DashboardLayout.cardGap, refresh: { await refreshAll() }) {
            LuckyScreenHeader(title: "总览", subtitle: accountDisplayName,
                              subtitleAction: { showingAccounts = true }) {
                Button {
                    LuckyHaptic.light()
                    navigator.selection = .settings
                } label: {
                    LuckyMark(size: 38)
                        .frame(width: 52, height: 52)
                        .background(LuckyTheme.surface, in: .circle)
                        .overlay(
                            Circle()
                                .strokeBorder(LuckyTheme.hairline.opacity(0.4), lineWidth: LuckyTheme.strokeWidth)
                        )
                }
                .buttonStyle(LuckyPressStyle(pressedScale: 0.92, pressedOpacity: 0.75))
                .accessibilityLabel("账户与设置")
            }
            DashboardLiveReader { statusStore in
                DashboardHostPanel(status: statusStore.data, connected: statusStore.connected)
                if !statusStore.error.isEmpty, statusStore.data == nil {
                    LuckyErrorCard(message: statusStore.error)
                }
            }

            DashboardShortcuts()

            ReverseProxyCard(rules: rules, ready: rulesReady, loading: rulesFetching,
                             failure: rulesFailure) {
                navigator.push(.webservice)
            }
            DashboardLiveReader { statusStore in
                if let status = statusStore.data {
                    if horizontalSizeClass == .regular, !dynamicTypeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: DashboardLayout.cardGap) {
                            systemPanel(status)
                            networkPanel(status)
                        }
                    } else {
                        systemPanel(status)
                        networkPanel(status)
                    }
                    serverPanel(status)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: active) { await holdStatus() }
        .sheet(isPresented: $showingAccounts) {
            DashboardAccountPicker()
        }
        .task(id: active) { await pollRules() }
    }

    private var accountDisplayName: String {
        let remark = session.remark.trimmingCharacters(in: .whitespacesAndNewlines)
        return remark.isEmpty ? accountServerName(session.baseUrl) : remark
    }

    /// 系统资源 — `TrendChart maxValue={100}` over the socket's 90-sample history. The original
    /// draws bare polylines; area-filling the primary line is the one visual liberty taken here.
    private func systemPanel(_ status: LuckyLiveStatus) -> some View {
        LuckyCard(padding: DashboardLayout.cardInset, spacing: DashboardLayout.contentGap) {
            DashboardSectionHeader(title: "系统资源", symbol: LuckySymbol.cpu, iconRole: .system) {
                LuckyChip(text: "\(status.history.count) 个采样", tone: .idle)
            }
            LuckyHairline()
            LuckyWrap(spacing: LuckyTheme.Space.m, lineSpacing: 6) {
                DashboardLegend(label: "系统 CPU", tone: .brand)
                DashboardLegend(label: "进程 CPU", tone: .danger)
                DashboardLegend(label: "系统内存", tone: .ok)
            }
            LuckySparkline(series: systemSeries(status.history), height: 128, ceiling: 100)
        }
    }

    /// Memory is charted as a percentage of the total reported in the same sample, not of the
    /// latest total — a host that grows its RAM mid-history keeps a truthful curve either way.
    private func systemSeries(_ history: [LuckyStatusSample]) -> [LuckySparkSeries] {
        [
            LuckySparkSeries(id: "system-cpu", values: history.map(\.systemCpuPercent),
                             tone: .brand, filled: true),
            LuckySparkSeries(id: "process-cpu", values: history.map(\.processCpuPercent),
                             tone: .danger),
            LuckySparkSeries(id: "system-memory",
                             values: history.map { Format.percent($0.usedMem, $0.totalMem) },
                             tone: .ok),
        ]
    }

    /// 网络趋势 — in and out share one scale (`LuckySparkline` takes its ceiling from the largest
    /// sample across every series), so the two speeds stay comparable.
    private func networkPanel(_ status: LuckyLiveStatus) -> some View {
        let inSpeed = Format.bytes(status.lastNetInSpeed, speed: true)
        let outSpeed = Format.bytes(status.lastNetOutSpeed, speed: true)
        return LuckyCard(padding: DashboardLayout.cardInset, spacing: DashboardLayout.contentGap) {
            DashboardSectionHeader(title: "网络趋势", symbol: LuckySymbol.network, iconRole: .network)
            LuckyHairline()
            LuckyWrap(spacing: LuckyTheme.Space.m, lineSpacing: 6) {
                DashboardLegend(label: "下载 \(inSpeed)", tone: .info)
                DashboardLegend(label: "上传 \(outSpeed)", tone: .warning)
            }
            LuckySparkline(series: networkSeries(status.history), height: 128)
            HStack(spacing: 10) {
                totalColumn("接收总量", Format.bytes(status.netIn),
                            symbol: LuckySymbol.download, tone: .info)
                totalColumn("发送总量", Format.bytes(status.netOut),
                            symbol: LuckySymbol.upload, tone: .warning)
            }
        }
    }

    private func networkSeries(_ history: [LuckyStatusSample]) -> [LuckySparkSeries] {
        [
            LuckySparkSeries(id: "net-in", values: history.map(\.netInSpeed),
                             tone: .info, filled: true),
            LuckySparkSeries(id: "net-out", values: history.map(\.netOutSpeed), tone: .warning),
        ]
    }

    private func totalColumn(_ label: String, _ value: String, symbol: String,
                             tone: LuckyTone) -> some View {
        HStack(spacing: 7) {
            LuckyIconTile(symbol: symbol, size: 28, glyph: 13, tone: tone)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .lineLimit(1)
                Text(value)
                    .font(LuckyTheme.Text.captionMedium)
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Operational details not already promoted into the live resource summary. `String(value)`
    /// on a JavaScript number is `JSONSerializer.numberString`, which is why these stay `Double`s
    /// instead of being rounded to `Int` for display.
    private func serverPanel(_ status: LuckyLiveStatus) -> some View {
        let metricsLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: LuckyTheme.Space.s))
            : AnyLayout(HStackLayout(spacing: LuckyTheme.Space.s))
        return LuckyCard(padding: DashboardLayout.cardInset, spacing: DashboardLayout.contentGap) {
            DashboardSectionHeader(title: "服务器信息", symbol: LuckySymbol.disk, iconRole: .server)
            LuckyHairline()
            metricsLayout {
                serverFact("打开句柄", JSONSerializer.numberString(status.handleCount))
                serverFact("GC 次数", JSONSerializer.numberString(status.numGc))
                serverFact("堆内存", Format.bytes(status.heapInuse))
            }
            VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
                LuckyRow("进程启动", status.runTime.isEmpty ? "--" : status.runTime, mono: true, lineLimit: 1)
                LuckyHairline()
                LuckyRow("查询时间", status.queryTime.isEmpty ? "--" : status.queryTime, mono: true, lineLimit: 1)
            }
            .padding(LuckyTheme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LuckyTheme.surfaceRaised,
                        in: .rect(cornerRadius: LuckyTheme.Radius.row))
        }
    }

    private func serverFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LuckyTheme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(LuckyTheme.Text.captionMedium)
                .foregroundStyle(LuckyTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(LuckyTheme.Space.m)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(LuckyTheme.surfaceRaised,
                    in: .rect(cornerRadius: LuckyTheme.Radius.row))
        .accessibilityElement(children: .combine)
    }

    private func refreshAll() async {
        await loadRules()
    }

    /// The socket lives exactly as long as the tab is showing and the app is foregrounded. The
    /// sleep loop is only a parking spot — `retain()` happens on entry and `release()` in the
    /// `defer` when `.task(id: active)` cancels this on the way out.
    private func holdStatus() async {
        guard active else { return }
        live.retain()
        defer { live.release() }
        while !Task.isCancelled { try? await Task.sleep(for: .seconds(60)) }
    }

    /// `staleTime: 15_000, refetchInterval: 30_000`.
    private func pollRules() async {
        guard active else { return }
        while !Task.isCancelled {
            await loadRules()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    /// `getWebServiceRules(false)` — the full list, not the lite one, because the preview rows
    /// count sub-rules and the lite endpoint omits them. Hydrates from disk cache first so cold
    /// launch never flashes `--`, then persists refreshed rules for WebServiceScreen to reuse.
    private func loadRules() async {
        let cache = WebRulesCache.shared
        await cache.hydrateFromDiskIfNeeded(credentials: session.credentials)
        if !rulesReady, cache.loadedPanes.contains(.rules) || !cache.rules.isEmpty {
            rules = cache.rules
            rulesReady = true
        }
        guard !rulesFetching else { return }
        rulesFetching = true
        defer { rulesFetching = false }
        do {
            let fetched = try await WebService.rules().items
            rules = fetched
            rulesReady = true
            rulesFailure = ""
            cache.store(.rules, items: fetched)
        } catch {
            guard !error.isCancellation else { return }
            rulesFailure = error.luckyMessage()
        }
    }
}

#if DEBUG
/// Uses the production cards with local sample data; opening Canvas does not connect to a server.
private struct DashboardScreenPreviews: PreviewProvider {
    private static let sample = LuckyLiveStatus(
        totalMem: 8_589_934_592, usedMem: 3_350_074_490, usedCpu: 12.4,
        currentProcessUsedCpu: 1.8, goroutine: 42, processUsedMem: 83_886_080
    )

    private static var overview: some View {
        NavigationStack {
            LuckyPage(spacing: DashboardLayout.cardGap) {
                LuckyScreenHeader(title: "总览", subtitle: "lucky.local") {
                    LuckyMark(size: 46)
                }
                DashboardHostPanel(status: sample, connected: true)
                DashboardShortcuts()
                ReverseProxyCard(rules: [], ready: true, loading: false, failure: "", open: {})
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    static var previews: some View {
        Group {
            overview.preferredColorScheme(.light).previewDisplayName("总览 · 浅色")
            overview.preferredColorScheme(.dark).previewDisplayName("总览 · 深色")
            overview.dynamicTypeSize(.accessibility2).previewDisplayName("总览 · 大字体")
        }
    }
}
#endif
