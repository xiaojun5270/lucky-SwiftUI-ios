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
    @Environment(\.colorScheme) private var colorScheme

    @State private var lines: [String] = []
    @State private var cachedVisibleLines: [String] = []
    @State private var warningCount = 0
    @State private var errorCount = 0
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

    private var visibleLines: [String] { cachedVisibleLines }

    private func matchesCurrentFilter(_ line: String, needle: String) -> Bool {
        filter.includes(line)
            && (needle.isEmpty || line.range(of: needle, options: .caseInsensitive) != nil)
    }

    private func recomputeSeverityCounts() {
        var warnings = 0
        var errors = 0
        for line in lines {
            switch LuckyLogSeverity.detect(line) {
            case .warning: warnings += 1
            case .error: errors += 1
            case .normal: break
            }
        }
        warningCount = warnings
        errorCount = errors
    }

    private func recomputeVisibleLines() {
        let needle = query.jsTrimmed
        if filter == .all, needle.isEmpty {
            cachedVisibleLines = lines
            return
        }
        cachedVisibleLines = lines.filter { matchesCurrentFilter($0, needle: needle) }
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
        .onChange(of: query) { recomputeVisibleLines() }
        .onChange(of: filter) { recomputeVisibleLines() }
    }

    /// `scrollable={false}`: the page does not scroll, the list inside it does.
    @ViewBuilder
    private var content: some View {
        let cardShape = RoundedRectangle(cornerRadius: LuckyTheme.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
            LuckyScreenHeader(title: "运行日志", subtitle: "实时活动与分级排查") {
                LuckyToolbarButton(symbol: LuckySymbol.refresh, label: "刷新日志", loading: fetching) {
                    Task { await poll() }
                }
            }
            LuckySearchField(text: $query, placeholder: "搜索日志")
            filterBar
            if !failure.isEmpty {
                LuckyErrorCard(message: failure) { Task { await poll() } }
            }
            VStack(spacing: 0) {
                outputHeader
                    .padding(.horizontal, LuckyTheme.Space.m)
                    .padding(.vertical, 8)
                LuckyHairline()
                output
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cardShape.fill(LuckyTheme.surface))
            .clipShape(cardShape)
            .overlay(
                cardShape.strokeBorder(
                    LuckyTheme.hairline.opacity(colorScheme == .dark ? 0.45 : 0.35),
                    lineWidth: LuckyTheme.strokeWidth
                )
            )
            .compositingGroup()
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.035),
                radius: colorScheme == .dark ? 12 : 8,
                x: 0,
                y: colorScheme == .dark ? 5 : 3
            )
            .containerShape(cardShape)
        }
        .padding(.horizontal, LuckyTheme.Space.gutter)
        .padding(.top, LuckyTheme.Space.pageTop)
        .padding(.bottom, LuckyTheme.Space.m)
        .frame(maxWidth: LuckyTheme.Layout.contentWidth, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var output: some View {
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
                         height: nil, newestFirst: true, fill: LuckyTheme.surface)
        }
    }

    private var outputHeader: some View {
        HStack(spacing: LuckyTheme.Space.s) {
            LuckyStatusDot(tone: statusTone, pulsing: pollActive && failure.isEmpty, size: 7)
            Text(paused ? "已暂停" : "实时 · 3s")
                .font(LuckyTheme.Text.captionMedium)
                .foregroundStyle(LuckyTheme.textPrimary)
                .lineLimit(1)
            Text("· \(countText)")
                .font(LuckyTheme.Text.caption)
                .foregroundStyle(LuckyTheme.textTertiary)
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                LuckyHaptic.selection()
                paused.toggle()
            } label: {
                Label(paused ? "继续" : "暂停", systemImage: paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(LuckyTheme.accent)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(LuckyTheme.accentSoft, in: .capsule)
            }
            .buttonStyle(LuckyPressStyle(pressedScale: 0.95, pressedOpacity: 0.75))
            .accessibilityLabel(paused ? "继续实时刷新" : "暂停实时刷新")
        }
    }

    private var filterBar: some View {
        HStack(spacing: LuckyTheme.Space.s) {
            Picker("日志级别", selection: $filter) {
                Text("\(GlobalLogFilter.all.title) \(lines.count)").tag(GlobalLogFilter.all)
                Text("\(GlobalLogFilter.warning.title) \(warningCount)").tag(GlobalLogFilter.warning)
                Text("\(GlobalLogFilter.error.title) \(errorCount)").tag(GlobalLogFilter.error)
            }
            .pickerStyle(.segmented)
            Menu {
                Button("复制当前日志", systemImage: LuckySymbol.copy) { copyVisibleLines() }
                    .disabled(visibleLines.isEmpty)
                Button("清空当前显示", systemImage: "trash", role: .destructive) { clearDisplay() }
                    .disabled(lines.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
                    .font(LuckyTheme.Text.cardTitle)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(LuckyTheme.surface, in: .circle)
            }
            .accessibilityLabel("日志操作")
        }
    }

    private func copyVisibleLines() {
        guard !visibleLines.isEmpty else { return }
        LuckyClipboard.copy(visibleLines.reversed().joined(separator: "\n"))
        toast = .ok("已复制 \(visibleLines.count) 条日志")
    }

    private func clearDisplay() {
        lines.removeAll(keepingCapacity: true)
        cachedVisibleLines.removeAll(keepingCapacity: true)
        warningCount = 0
        errorCount = 0
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

        let canIncrementallyAppend = batch.incremental && !restarted
            && (lines.count + batch.lines.count <= Self.maxLogLines)
        if canIncrementallyAppend {
            lines.append(contentsOf: batch.lines)
            let needle = query.jsTrimmed
            for line in batch.lines {
                switch LuckyLogSeverity.detect(line) {
                case .warning: warningCount += 1
                case .error: errorCount += 1
                case .normal: break
                }
                if filter == .all && needle.isEmpty {
                    cachedVisibleLines.append(line)
                } else if matchesCurrentFilter(line, needle: needle) {
                    cachedVisibleLines.append(line)
                }
            }
            if !lines.isEmpty { cleared = false }
            return
        }

        var next = batch.incremental && !restarted ? lines : []
        next.append(contentsOf: batch.lines)
        if next.count > Self.maxLogLines {
            next.removeFirst(next.count - Self.maxLogLines)
        }
        lines = next
        recomputeSeverityCounts()
        recomputeVisibleLines()
        if !next.isEmpty { cleared = false }
    }
}
