import SwiftUI

/// `app/(tabs)/monitor.tsx` — the 总览 tab.
///
/// Two feeds run at once: the status socket publishes live frames and the reverse-proxy rule list
/// refreshes every 30 s. Both are gated on
/// `dockerActive = isFocused && appIsActive`, so a backgrounded app holds no socket and issues no
/// requests. The socket is the shared reference-counted stream, so leaving the tab drops the
/// connection but keeps the last frame on screen instead of blanking the charts.

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

/// The dashboard identity and its primary resource readout. The host stays unframed so it anchors
/// the page; one quiet panel below carries both current values and their shared history.
private struct DashboardHostPanel: View {
    var status: LuckyLiveStatus?
    var connected: Bool
    var baseURL: String

    private var memory: Double {
        guard let status else { return 0 }
        return Format.percent(status.usedMem, status.totalMem)
    }

    private var host: String {
        guard !baseURL.isEmpty else { return "Lucky 主机" }
        return URL(string: baseURL)?.host ?? baseURL
    }

    private var systemSeries: [LuckySparkSeries] {
        let history = status?.history ?? []
        return [
            LuckySparkSeries(id: "system-cpu", values: history.map(\.systemCpuPercent),
                             tone: .brand, filled: true),
            LuckySparkSeries(id: "process-cpu", values: history.map(\.processCpuPercent),
                             tone: .danger),
            LuckySparkSeries(id: "system-memory",
                             values: history.map { Format.percent($0.usedMem, $0.totalMem) },
                             tone: .ok),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            HStack(alignment: .top, spacing: LuckyTheme.Space.m) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("总览")
                        .font(LuckyTheme.Text.hero)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    HStack(spacing: 7) {
                        LuckyStatusDot(tone: connected ? .ok : .warning)
                        Text(host)
                            .font(LuckyTheme.Text.captionMedium)
                            .foregroundStyle(LuckyTheme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
                Text(connected ? "实时" : "连接中")
                    .font(LuckyTheme.Text.captionMedium)
                    .foregroundStyle(connected ? LuckyTheme.success : LuckyTheme.warning)
                    .padding(.top, 8)
            }

            LuckyCard {
                HStack(spacing: 0) {
                    primaryMetric("CPU", status.map { JSCompat.toFixed($0.usedCpu, 1) + "%" } ?? "--",
                                  detail: "系统占用")
                    primaryDivider
                    primaryMetric("内存", status == nil ? "--" : JSCompat.toFixed(memory, 1) + "%",
                                  detail: status.map { Format.bytes($0.usedMem) } ?? "正在读取")
                }
                LuckyHairline()
                LuckyWrap(spacing: LuckyTheme.Space.m, lineSpacing: 6) {
                    DashboardLegend(label: "系统 CPU", tone: .brand)
                    DashboardLegend(label: "进程 CPU", tone: .danger)
                    DashboardLegend(label: "系统内存", tone: .ok)
                }
                LuckySparkline(series: systemSeries, height: 112, ceiling: 100)
                LuckyHairline()
                HStack(spacing: 0) {
                    metric("进程 CPU",
                           status.map { JSCompat.toFixed($0.currentProcessUsedCpu, 1) + "%" } ?? "--")
                    metricDivider
                    metric("进程内存", status.map { Format.bytes($0.processUsedMem) } ?? "--")
                    metricDivider
                    metric("协程", status.map { JSONSerializer.numberString($0.goroutine) } ?? "--")
                }
            }
        }
    }

    private func primaryMetric(_ label: String, _ value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textSecondary)
            Text(value)
                .font(LuckyTheme.Text.metric)
                .foregroundStyle(LuckyTheme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, LuckyTheme.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textTertiary)
            Text(value)
                .font(LuckyTheme.Text.captionMedium)
                .foregroundStyle(LuckyTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, LuckyTheme.Space.m)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var primaryDivider: some View {
        Rectangle().fill(LuckyTheme.separator).frame(width: 1, height: 66)
    }

    private var metricDivider: some View {
        Rectangle().fill(LuckyTheme.separator).frame(width: 1, height: 34)
    }
}

private struct DashboardRouteButton: View {
    var title: String
    var detail: String
    var symbol: String
    var iconRole: LuckyIconRole
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LuckyIconTile(symbol: symbol, size: 32, glyph: 14, role: iconRole)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(LuckyTheme.Text.captionMedium)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .lineLimit(1)
                }
                .foregroundStyle(LuckyTheme.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LuckyTheme.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        LuckyCard {
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
                    LuckyIconTile(symbol: "globe.asia.australia", size: 42, glyph: 21, role: .web)
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .frame(width: 32, height: 32)
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
        Button {
            portsMasked.toggle()
        } label: {
            Image(systemName: portsMasked ? "eye" : "eye.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(portsMasked ? LuckyTheme.accent : LuckyTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: LuckyTheme.Radius.row, style: .continuous)
                        .fill(portsMasked ? LuckyTheme.accentSoft : LuckyTheme.surfaceRaised)
                )
        }
        .buttonStyle(DashboardPressStyle())
        .accessibilityLabel(portsMasked ? "显示端口信息" : "隐藏端口信息")
        .accessibilityAddTraits(portsMasked ? [.isSelected] : [])
    }

    /// Three equal columns divided by hairlines. `--` until the first payload arrives, so an empty
    /// server and an unreached one never read the same.
    private var statsStrip: some View {
        HStack(spacing: 0) {
            statColumn("启用规则", ready ? "\(enabledRules.count)/\(rules.count)" : "--",
                       tint: LuckyTheme.accent, divided: false)
            statColumn("启用子规则", ready ? "\(enabledSubRules.count)/\(subRules.count)" : "--",
                       tint: LuckyTheme.success, divided: true)
            statColumn("TLS 监听", ready ? String(tlsRules.count) : "--",
                       tint: LuckyTheme.warning, divided: true)
        }
        .frame(minHeight: 66)
        .background(ConcentricRectangle().fill(LuckyTheme.surfaceRaised))
        .clipShape(.rect(cornerRadius: LuckyTheme.Radius.panel))
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
        return HStack(spacing: 9) {
            LuckyIconTile(symbol: tls ? "lock.fill" : "arrow.triangle.branch", size: 28,
                          glyph: 14, role: tls ? .security : .web)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(LuckyTheme.Text.captionMedium)
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(network) · \(host):\(visiblePort)")
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
        }
        .padding(10)
        .frame(minHeight: 44)
        .background(LuckyTheme.surfaceRaised,
                    in: .rect(cornerRadius: LuckyTheme.Radius.row))
        .accessibilityElement(children: .combine)
    }
}

/// The 总览 tab root.
struct DashboardScreen: View {
    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.scenePhase) private var phase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var session = LuckySession.shared

    @State private var rules: [LuckyListItem] = []
    @State private var rulesReady = false
    @State private var rulesFailure = ""
    @State private var rulesFetching = false

    private var live: LuckyStatusStore { .shared }

    /// `dockerActive = isFocused && appIsActive`.
    private var active: Bool { navigator.selection == .dashboard && phase == .active }

    var body: some View {
        LuckyPage(spacing: LuckyTheme.Space.section, refresh: { await refreshAll() }) {
            DashboardLiveReader { statusStore in
                DashboardHostPanel(status: statusStore.data, connected: statusStore.connected,
                                   baseURL: session.baseUrl)
                if !statusStore.error.isEmpty, statusStore.data == nil {
                    LuckyErrorCard(message: statusStore.error)
                }
            }

            VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
                LuckySectionHeader(title: "快捷入口")
                LuckyCard(padding: 0, spacing: 0) {
                    HStack(spacing: 0) {
                        DashboardRouteButton(title: "Docker", detail: "容器与镜像",
                                             symbol: LuckySymbol.docker, iconRole: .docker) {
                            navigator.push(.docker())
                        }
                        Rectangle().fill(LuckyTheme.separator).frame(width: 1, height: 42)
                        DashboardRouteButton(title: "内网穿透", detail: "隧道与代理",
                                             symbol: "point.3.connected.trianglepath.dotted",
                                             iconRole: .tunnels) {
                            navigator.reset(to: .services)
                        }
                    }
                }
            }

            ReverseProxyCard(rules: rules, ready: rulesReady, loading: rulesFetching,
                             failure: rulesFailure) {
                navigator.push(.webservice)
            }
            DashboardLiveReader { statusStore in
                if let status = statusStore.data {
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: LuckyTheme.Space.section) {
                            networkPanel(status)
                            serverPanel(status)
                        }
                    } else {
                        networkPanel(status)
                        serverPanel(status)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: active) { await holdStatus() }
        .task(id: active) { await pollRules() }
    }

    /// 网络趋势 — in and out share one scale (`LuckySparkline` takes its ceiling from the largest
    /// sample across every series), so the two speeds stay comparable.
    private func networkPanel(_ status: LuckyLiveStatus) -> some View {
        let inSpeed = Format.bytes(status.lastNetInSpeed, speed: true)
        let outSpeed = Format.bytes(status.lastNetOutSpeed, speed: true)
        return LuckyCard {
            LuckySectionHeader(title: "网络趋势", symbol: LuckySymbol.network, iconRole: .network)
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
        LuckyCard {
            LuckySectionHeader(title: "服务器信息", symbol: LuckySymbol.disk, iconRole: .server)
            LuckyHairline()
            LuckyTileGrid(minimum: 135, spacing: LuckyTheme.Space.s) {
                serverFact("进程启动", status.runTime.isEmpty ? "--" : status.runTime)
                serverFact("查询时间", status.queryTime.isEmpty ? "--" : status.queryTime)
                serverFact("打开句柄", JSONSerializer.numberString(status.handleCount))
                serverFact("GC 次数", JSONSerializer.numberString(status.numGc))
                serverFact("堆内存", Format.bytes(status.heapInuse))
            }
        }
    }

    private func serverFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LuckyTheme.textTertiary)
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
    /// count sub-rules and the lite endpoint omits them.
    private func loadRules() async {
        guard !rulesFetching else { return }
        rulesFetching = true
        defer { rulesFetching = false }
        do {
            rules = try await WebService.rules().items
            rulesReady = true
            rulesFailure = ""
        } catch {
            guard !error.isCancellation else { return }
            rulesFailure = error.luckyMessage()
        }
    }
}
