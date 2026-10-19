import SwiftUI

private enum GlobalLogFilter: String, Hashable {
    case all, warning, error

    var title: String {
        switch self {
        case .all: "全部"
        case .warning: "警告"
        case .error: "错误"
        }
    }

    func includes(_ line: String) -> Bool {
        switch self {
        case .all: true
        case .warning: LuckyLogSeverity.detect(line) == .warning
        case .error: LuckyLogSeverity.detect(line) == .error
        }
    }
}

/// `app/(tabs)/users.tsx` — the file is named `users` but the screen is 运行日志.
///
/// The polling contract is the delicate part: `getGlobalLogBatch(cursor)` every 3 s, but only while
/// the tab is showing *and* the app is foregrounded, and the response decides whether its lines are
/// appended or replace what is on screen. Getting that wrong either duplicates the whole buffer or
/// silently stops updating.
struct LogsScreen: View {
    private static let maxLogLines = 5000

    @Environment(\.luckyNavigator) private var navigator
    @Environment(\.scenePhase) private var phase

    @State private var lines: [String] = []
    @State private var cursor = ""
    @State private var startTime = ""
    @State private var failure = ""
    @State private var fetching = false
    @State private var loaded = false
    @State private var paused = false
    @State private var query = ""
    @State private var filter = GlobalLogFilter.all
    @State private var cleared = false
    @State private var toast: LuckyToast?

    /// `logsActive = isFocused && appIsActive`.
    private var active: Bool { navigator.selection == .logs && phase == .active }
    private var pollActive: Bool { active && !paused }

    private var visibleLines: [String] {
        let needle = query.jsTrimmed
        return lines.filter { line in
            filter.includes(line)
                && (needle.isEmpty || line.range(of: needle, options: .caseInsensitive) != nil)
        }
    }

    private var statusTone: LuckyTone {
        if !failure.isEmpty { return .danger }
        if paused { return .warning }
        return active ? .ok : .idle
    }

    private var countText: String {
        visibleLines.count == lines.count ? "\(lines.count) 条" : "\(visibleLines.count)/\(lines.count)"
    }

    var body: some View {
        ZStack {
            LuckyBackdrop()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .luckyToast($toast)
        // `refetchInterval: 3000` while enabled, cancelled the moment it is not.
        .task(id: pollActive) {
            guard pollActive else { return }
            while !Task.isCancelled {
                await poll()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// `scrollable={false}`: the page does not scroll, the list inside it does.
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.l) {
            outputHeader
            LuckySearchField(text: $query, placeholder: "搜索日志")
            filterBar
            if !failure.isEmpty {
                LuckyErrorCard(message: failure) { Task { await poll() } }
            }
            if lines.isEmpty {
                if loaded, failure.isEmpty {
                    if cleared {
                        LuckyEmptyState(symbol: "trash", title: "已清空当前显示",
                                        message: "新日志到达后会继续显示") {
                            Button("重新载入历史", systemImage: "clock.arrow.circlepath") {
                                Task { await reloadHistory() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        LuckyEmptyState(symbol: "terminal", title: "暂无实时日志")
                            .frame(maxHeight: .infinity)
                    }
                } else if !loaded, failure.isEmpty {
                    LuckyLoadingView().frame(maxHeight: .infinity)
                }
            } else if visibleLines.isEmpty {
                LuckyEmptyState(symbol: "line.3.horizontal.decrease.circle",
                                title: "没有匹配的日志",
                                message: "尝试更换级别或搜索关键词")
                    .frame(maxHeight: .infinity)
            } else {
                // `[...lines].reverse()` — newest first, so the interesting line is on screen
                // without scrolling, and therefore no auto-follow.
                LuckyLogView(lines: visibleLines, query: query, follows: false,
                             height: nil, newestFirst: true)
                    .clipShape(RoundedRectangle(cornerRadius: LuckyTheme.Radius.card,
                                                style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, LuckyTheme.Space.gutter)
        .padding(.top, LuckyTheme.Space.pageTop)
        .padding(.bottom, LuckyTheme.Space.m)
    }

    private var outputHeader: some View {
        HStack(spacing: LuckyTheme.Space.s) {
            LuckyIconTile(symbol: "terminal", size: 30, glyph: 13, role: .logs)
            VStack(alignment: .leading, spacing: LuckyTheme.Space.xs) {
                HStack(spacing: 6) {
                    Text("全局输出")
                        .font(LuckyTheme.Text.cardTitle)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    LuckyStatusDot(tone: statusTone)
                }
                Text(paused ? "刷新已暂停 · \(countText)" : "每 3 秒刷新 · \(countText)")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                paused.toggle()
            } label: {
                LuckyIconTile(symbol: paused ? "play.fill" : "pause.fill", size: 30, glyph: 12,
                              tone: paused ? .ok : .idle)
                    .frame(width: LuckyTheme.Space.touchTarget, height: LuckyTheme.Space.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(paused ? "继续实时刷新" : "暂停实时刷新")
            Button {
                Task { await poll() }
            } label: {
                ZStack {
                    LuckyIconTile(symbol: LuckySymbol.refresh, size: 30, glyph: 13)
                        .opacity(fetching ? 0 : 1)
                    if fetching {
                        ProgressView().controlSize(.small).tint(LuckyTheme.accent)
                    }
                }
                .frame(width: LuckyTheme.Space.touchTarget, height: LuckyTheme.Space.touchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(fetching)
            .accessibilityLabel("刷新")
        }
    }

    private var filterBar: some View {
        HStack(spacing: LuckyTheme.Space.s) {
            LuckyGlassSegmentedControl(
                selection: $filter,
                segments: [
                    LuckySegment(.all, GlobalLogFilter.all.title),
                    LuckySegment(.warning, GlobalLogFilter.warning.title),
                    LuckySegment(.error, GlobalLogFilter.error.title),
                ],
                glass: false
            )
            LuckyGlassIconButton(symbol: LuckySymbol.copy, label: "复制当前日志") {
                copyVisibleLines()
            }
            .disabled(visibleLines.isEmpty)
            LuckyGlassIconButton(symbol: "trash", label: "清空当前显示", tone: .danger) {
                clearDisplay()
            }
            .disabled(lines.isEmpty)
        }
    }

    private func copyVisibleLines() {
        guard !visibleLines.isEmpty else { return }
        LuckyClipboard.copy(visibleLines.reversed().joined(separator: "\n"))
        toast = .ok("已复制 \(visibleLines.count) 条日志")
    }

    private func clearDisplay() {
        lines.removeAll(keepingCapacity: true)
        cleared = true
        toast = .note("已清空当前显示")
    }

    private func reloadHistory() async {
        cursor = ""
        startTime = ""
        cleared = false
        await poll()
    }

    private func poll() async {
        guard !fetching else { return }
        fetching = true
        defer { fetching = false }
        do {
            let batch = try await LuckyService.globalLogBatch(pre: cursor)
            apply(batch)
            failure = ""
            loaded = true
        } catch {
            guard !error.isCancellation else { return }
            failure = error.luckyMessage()
            loaded = true
        }
    }

    /// The `useEffect` that folds a batch into the visible buffer.
    private func apply(_ batch: LuckyLogBatch) {
        let restarted = batch.reset
            || (!batch.startTime.isEmpty && !startTime.isEmpty && batch.startTime != startTime)
        cursor = batch.cursor
        if !batch.startTime.isEmpty { startTime = batch.startTime }

        // "Nothing new" arrives as an empty incremental page; keeping the current buffer is what
        // stops the list from flickering empty every three seconds.
        if batch.incremental, !restarted, batch.lines.isEmpty { return }
        // A full page identical to what is shown is dropped too, so the rows keep their identity
        // and the user's text selection survives.
        if !batch.incremental, !restarted, lines == batch.lines { return }

        var next = batch.incremental && !restarted ? lines : []
        next.append(contentsOf: batch.lines)
        if next.count > Self.maxLogLines {
            next.removeFirst(next.count - Self.maxLogLines)
        }
        lines = next
        if !next.isEmpty { cleared = false }
    }
}
