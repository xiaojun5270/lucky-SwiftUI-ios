import SwiftUI

/// §5's four row-level sub-components, plus the scroll every non-list view sits in.

// MARK: - 容器图标

/// §5.1's `ContainerArtwork`. The library serves its artwork from an endpoint that wants the admin
/// token, and `AsyncImage` cannot set a header, so the fetch is a `URLSession` call of its own.
///
/// An icon whose path is already a URL (`http:`, `data:`, `file:`) came from the container's own
/// labels rather than the library, and must be fetched *without* the token attached.
@MainActor
final class DockerIconLoader {
    static let shared = DockerIconLoader()

    /// `cachePolicy="memory-disk"` — the memory half. A container list re-renders on every
    /// five-second stats tick, so an uncached loader would re-fetch the whole grid each time.
    private var cache: [String: Image] = [:]
    /// The paths already known to fail, so `failed` never retries in a loop.
    private var failures: Set<String> = []
    private var running: Set<String> = []

    private init() {}

    func cached(_ icon: String) -> Image? { cache[icon] }

    func failed(_ icon: String) -> Bool { failures.contains(icon) }

    /// Quietly warms disk-cached or remote icons in background batches so opening Docker draws
    /// container artwork on the very first frame without icon flicker.
    func prewarm(_ icons: [String]) async {
        let unique = Array(Set(icons.filter { !$0.isEmpty })).prefix(24)
        for icon in unique {
            guard !Task.isCancelled else { return }
            guard cache[icon] == nil, !failures.contains(icon) else { continue }
            await load(icon)
        }
    }

    private static func iconCacheURL(for icon: String) -> URL? {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in icon.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return root
            .appendingPathComponent("LuckyDockerIcons", isDirectory: true)
            .appendingPathComponent("\(String(hash, radix: 16)).img")
    }

    /// Resolves the icon path from disk cache first, then fetches once and persists to disk.
    /// Concurrent callers for the same path collapse into the first request.
    func load(_ icon: String) async {
        guard !icon.isEmpty, cache[icon] == nil, !failures.contains(icon),
              !running.contains(icon) else { return }
        running.insert(icon)
        defer { running.remove(icon) }

        let diskURL = Self.iconCacheURL(for: icon)
        if let diskURL {
            let diskHit = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let data = try? Data(contentsOf: diskURL) else { return nil }
                return UIImage(data: data)
            }.value
            if let diskHit {
                cache[icon] = Image(uiImage: diskHit)
                return
            }
        }

        guard let request = await Self.request(for: icon) else {
            failures.insert(icon)
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard status < 400 else {
                failures.insert(icon)
                return
            }
            let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let image = UIImage(data: data) else { return nil }
                if let diskURL {
                    let folder = diskURL.deletingLastPathComponent()
                    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try? data.write(to: diskURL, options: .atomic)
                }
                return image
            }.value
            guard let image = decoded else {
                failures.insert(icon)
                return
            }
            cache[icon] = Image(uiImage: image)
        } catch {
            // `onError={() => setFailed(true)}` — the glyph stands in and nothing is reported.
            failures.insert(icon)
        }
    }

    /// `${baseUrl}/api/iconlib/icon?path=…` with the admin token, or the icon's own URL bare.
    private static func request(for icon: String) async -> URLRequest? {
        if DockerRecord.isExternalIcon(icon) {
            guard let url = URL(string: icon) else { return nil }
            return URLRequest(url: url)
        }
        let credentials = await LuckyClient.shared.snapshot
        let base = credentials.baseUrl.jsTrimmed.withoutTrailingSlashes
        guard !base.isEmpty else { return nil }
        let query = JSCompat.encodeURIComponent(icon)
        guard let url = URL(string: "\(base)/api/iconlib/icon?path=\(query)") else { return nil }
        var request = URLRequest(url: url)
        if !credentials.token.isEmpty {
            request.setValue(credentials.token, forHTTPHeaderField: "Lucky-Admin-Token")
        }
        return request
    }
}

/// Memoizes `DockerRecord.containerIcon`, which scores a container against every entry in the
/// icon library.
///
/// That scan is `O(library × terms)` of lowercasing and substring work, and it used to sit behind
/// a computed property inside `ContainerArtwork` — so a thirty-container list against a
/// four-hundred-icon library ran tens of thousands of `contains` calls on every body evaluation,
/// and a body evaluation happens on every five-second stats tick. The answer depends only on the
/// container record and the library, neither of which changes between those ticks.
@MainActor
final class DockerIconIndex {
    static let shared = DockerIconIndex()

    private var items: [LuckyListItem] = []
    private var library: [JSONValue] = []
    private var cachedRows: [DockerContainerRow] = []

    private init() {}

    /// Builds container rows off the main actor so entering the Docker screen never runs
    /// `O(containers × icons)` icon-library matching on `@MainActor`.
    nonisolated static func buildRows(items: [LuckyListItem], icons: [JSONValue]) -> [DockerContainerRow] {
        var seen = Set<String>()
        seen.reserveCapacity(items.count)
        return items.enumerated().map { index, item in
            var row = DockerContainerRow(item, index)
            let base = row.identity
            var suffix = 1
            while !seen.insert(row.identity).inserted {
                row.identity = "\(base)#\(suffix)"
                suffix += 1
            }
            row.icon = DockerRecord.containerIcon(item, icons)
            return row
        }
    }

    func seed(items: [LuckyListItem], icons: [JSONValue], rows: [DockerContainerRow]) {
        self.items = items
        self.library = icons
        self.cachedRows = rows
    }

    /// Resolves every row as one memoized unit. Statistics change every refresh cycle; containers
    /// and the icon catalogue usually do not. Exact value comparison makes a stats-only render an
    /// immediate cache hit while still invalidating correctly if a label or catalogue entry changes.
    func rows(items: [LuckyListItem], icons: [JSONValue]) -> [DockerContainerRow] {
        if items == self.items, icons == library { return cachedRows }
        let rows = Self.buildRows(items: items, icons: icons)
        self.items = items
        library = icons
        cachedRows = rows
        return rows
    }
}

/// §5.1. Compact container artwork tile in the containers list.
struct ContainerArtwork: View {
    /// The library path, already resolved. Resolution is a scan of the whole library, so it happens
    /// once per row in `DockerContainersView` rather than once per body evaluation in here.
    var icon: String
    var running: Bool
    var size: CGFloat = 28

    @State private var image: Image?
    /// The path `image` was actually loaded for. Without it `resolve` cleared the image on every
    /// run — including the runs where the path had not moved — so each stats tick flashed the
    /// fallback glyph and forced a second render pass through the whole list.
    @State private var loaded: String?

    private var radius: CGFloat { max(7, (size * 0.25).rounded()) }
    private var inset: CGFloat { size <= 32 ? 3 : 6 }

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size - inset, height: size - inset)
            } else {
                LuckyFunctionIcon(
                    symbol: LuckySymbol.docker,
                    size: size,
                    glyph: (size * 0.48).rounded(),
                    color: running ? LuckyIconRole.docker.color : LuckyTheme.idle
                )
            }
        }
        .frame(width: size, height: size)
        .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: radius))
        .clipShape(.rect(cornerRadius: radius))
        // `failed` resets whenever the URI changes, which the id does for us.
        .task(id: icon) { await resolve(icon) }
        .accessibilityHidden(true)
    }

    private func resolve(_ path: String) async {
        // A row scrolled off and back on re-runs the task with the same path; so does a re-appear
        // after a tick. Neither needs to touch the image it is already showing.
        guard loaded != path else { return }
        if let hit = DockerIconLoader.shared.cached(path) {
            image = hit
            loaded = path
            return
        }
        image = nil
        loaded = nil
        guard !path.isEmpty else { return }
        await DockerIconLoader.shared.load(path)
        // A second row may have finished the fetch while this one waited.
        guard path == icon else { return }
        image = DockerIconLoader.shared.cached(path)
        loaded = image == nil ? nil : path
    }
}

// MARK: - 统计网格

/// Six equal cells always fill complete rows. At the default text size, each column pairs a
/// resource: CPU/memory, download/upload, and disk reads/writes.
struct ContainerStatsGrid: View, Equatable {
    var stats: DockerStatRow?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static func == (lhs: ContainerStatsGrid, rhs: ContainerStatsGrid) -> Bool {
        lhs.stats == rhs.stats
    }

    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize { return 1 }
        return dynamicTypeSize >= .xxLarge ? 2 : 3
    }

    private var metrics: [Metric] {
        let cpu = Metric("CPU", LuckySymbol.cpu, LuckyTheme.accent, self.cpu)
        let memory = Metric("内存", LuckySymbol.memory, LuckyTheme.success, self.memory)
        let download = Metric("下载", LuckySymbol.download, LuckyTheme.info,
                              bytes(\.networkRx, \.hasNetworkRx))
        let upload = Metric("上传", LuckySymbol.upload, LuckyTheme.warning,
                            bytes(\.networkTx, \.hasNetworkTx))
        let read = Metric("读取", "tray.and.arrow.down.fill", LuckyTheme.textSecondary,
                          bytes(\.blockRead, \.hasBlockRead))
        let write = Metric("写入", "tray.and.arrow.up.fill", LuckyTheme.textSecondary,
                           bytes(\.blockWrite, \.hasBlockWrite))
        return columnCount == 3
            ? [cpu, download, read, memory, upload, write]
            : [cpu, memory, download, upload, read, write]
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LuckyTheme.Space.xs),
                                 count: columnCount), spacing: 3) {
            ForEach(metrics) { cell($0) }
        }
    }

    /// One label-and-value pair.
    private struct Metric: Identifiable {
        var label: String
        var symbol: String
        var tint: Color
        var value: String
        var id: String { label }

        init(_ label: String, _ symbol: String, _ tint: Color, _ value: String) {
            self.label = label
            self.symbol = symbol
            self.tint = tint
            self.value = value
        }
    }

    /// Compact single-line micro-tile (~50% tighter than the original stacked metric box).
    private func cell(_ metric: Metric) -> some View {
        HStack(spacing: 3) {
            Image(systemName: LuckySymbol.solid(metric.symbol))
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(metric.tint)
                .accessibilityHidden(true)
            Text(metric.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(LuckyTheme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(metric.value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(LuckyTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: 7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.label) \(metric.value)")
    }

    /// `hasCpu ? cpu.toFixed(1)+"%" : "--"`
    private var cpu: String {
        guard let stats, stats.hasCpu else { return "--" }
        return JSCompat.toFixed(stats.cpu, 1) + "%"
    }

    /// The percentage when the daemon reported one, the absolute figure when it only reported
    /// bytes, and a dash when it reported neither.
    private var memory: String {
        guard let stats else { return "--" }
        if stats.hasMemoryPercent { return JSCompat.toFixed(stats.memoryPercent, 1) + "%" }
        if stats.hasMemory { return DockerRecord.compactBytes(stats.memory, true) }
        return "--"
    }

    /// `compactDockerBytes(value ?? 0, hasX === true)` — a missing metric prints `--`, a present
    /// zero prints `0 B`, which is the whole point of carrying the `has` flags alongside.
    private func bytes(_ value: KeyPath<DockerStatRow, Double>,
                       _ present: KeyPath<DockerStatRow, Bool>) -> String {
        guard let stats else { return "--" }
        return DockerRecord.compactBytes(stats[keyPath: value], stats[keyPath: present])
    }
}

// MARK: - 行内按钮

/// §5.3's `IconButton` — the bordered verb button every Docker row is built from. Not glass: these
/// live inside the scroll, where glass may not go.
struct DockerIconButton: View {
    var symbol: String
    var label: String
    var tint: Color
    var disabled: Bool = false
    /// `fluid` — a button that shares the row's width rather than hugging its label.
    var fluid: Bool = false
    /// `compact` — tighter icon/padding for 4-button rows so two-character labels never clip.
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            LuckyHaptic.light()
            action()
        } label: {
            HStack(spacing: compact ? 3 : 4) {
                LuckyFunctionIcon(symbol: symbol, size: compact ? 15 : 18,
                                  glyph: compact ? 10 : 11, color: tint)
                Text(label)
                    .font(.system(size: 10.5, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(compact ? 0.8 : 1)
            }
            .foregroundStyle(LuckyTheme.textPrimary)
            .padding(.horizontal, compact ? 5 : 8)
            .frame(minWidth: compact ? 0 : 54, minHeight: 32)
            .frame(maxWidth: fluid ? .infinity : nil)
            .background(LuckyTheme.surfaceRaised,
                        in: .rect(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(LuckyTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.97, pressedOpacity: 0.75))
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel(label)
    }
}

/// §5.4's `ContainerCommandButton` — compact equal-width verb bar matching the shrunk container card.
struct ContainerCommandButton: View {
    var symbol: String
    var label: String
    var tint: Color
    var disabled: Bool = false
    var action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            LuckyHaptic.light()
            action()
        } label: {
            HStack(spacing: 3) {
                LuckyFunctionIcon(symbol: symbol, size: 15, glyph: 9, color: tint)
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(LuckyTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 38 : 28)
            .background(LuckyTheme.surfaceRaised,
                        in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LuckyTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(LuckyPressStyle(pressedScale: 0.97, pressedOpacity: 0.75))
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
        .accessibilityLabel(label)
    }
}

// MARK: - 面板滚动

/// The scroll used by settings and full-payload log views. List views use `DockerListPane` below.
struct DockerPaneScroll<Content: View>: View {
    var spacing: CGFloat = LuckyTheme.Space.l
    var topPadding: CGFloat = LuckyTheme.Space.s
    /// `<Page refreshing onRefresh>` — the scrollable page has pull to refresh just as the lists
    /// do, so 设置 and 日志's Mode A both get it here.
    var refresh: @Sendable () async -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(.horizontal, LuckyTheme.Space.gutter)
            .padding(.top, topPadding)
            .padding(.bottom, LuckyTheme.Space.pageBottom)
            .frame(maxWidth: LuckyTheme.Layout.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            // Run inside an unstructured task so early pull-release never cancels the request
            // mid-flight and UIRefreshControl springs back smoothly at 120Hz.
            let work = Task { await refresh() }
            await work.value
        }
    }
}

/// §6's shared `FlatList` config, as the one shape all six list views and 日志 share: a header that
/// scrolls with the rows, consistent spacing inside the system safe area, and pull to
/// refresh. `initialNumToRender` / `windowSize` have no counterpart — `LazyVStack` decides for
/// itself how far ahead to build — and the tab bar, the search box and the error cards have moved
/// out of `ListHeaderComponent` into the pinned chrome, because glass may not scroll.
///
/// The empty and loading branches replace the rows and not the header: §10 through §15 all draw
/// their `SectionHeader` first and their `EmptyState` under it, and `flexGrow: data.length ? 0 : 1`
/// is what centres the latter in the space left over.
struct DockerListPane<Header: View, Rows: View>: View {
    var count: Int
    var loading: Bool
    /// `<EmptyState message>` — `DockerView.emptyMessage`.
    var empty: String
    var symbol: String
    /// The original renders nothing at all while the first page is in flight; a spinner with the
    /// view's own sentence reads better and costs nothing (§25.15).
    var loadingText: String
    /// 12 px in the original. 日志 passes 0 — it has no separator.
    var spacing: CGFloat = LuckyTheme.Space.stack
    var topPadding: CGFloat = LuckyTheme.Space.s
    var refresh: @Sendable () async -> Void
    @ViewBuilder var header: () -> Header
    @ViewBuilder var rows: () -> Rows

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing) {
                header()
                if loading {
                    LuckyLoadingView(text: loadingText)
                } else if count == 0 {
                    LuckyEmptyState(symbol: symbol, title: empty)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LuckyTheme.Space.xl)
                } else {
                    rows()
                }
            }
            .padding(.horizontal, LuckyTheme.Space.gutter)
            .padding(.top, topPadding)
            .padding(.bottom, LuckyTheme.Space.pageBottom)
            .frame(maxWidth: LuckyTheme.Layout.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .scrollIndicators(.hidden)
        // `keyboardShouldPersistTaps="handled"` is RN's default-fighting flag; the iOS equivalent
        // is letting a drag dismiss the search keyboard rather than swallowing the first tap.
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            // Run inside an unstructured task so early pull-release never cancels the request
            // mid-flight and UIRefreshControl springs back smoothly at 120Hz.
            let work = Task { await refresh() }
            await work.value
        }
    }
}

/// The `N 项` count every list header carries in its `meta` slot.
struct DockerCountChip: View {
    var count: Int

    var body: some View {
        Text("\(count) 项")
            .font(LuckyTheme.Text.caption)
            .foregroundStyle(LuckyTheme.textSecondary)
            .monospacedDigit()
    }
}
