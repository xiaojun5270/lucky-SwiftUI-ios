import SwiftUI

/// One row of the 镜像 list, pre-read. §3 builds these once per payload rather than per row because
/// `searchText` stringifies the whole record and the filter runs on every keystroke.
struct DockerImageEntry: Identifiable, Hashable, Sendable {
    var item: LuckyListItem
    var id: String
    var references: [String]
    var searchText: String
}

/// The payload and its derived index change together, only after a successful image-list read.
/// Search, selection and unrelated state updates can then reuse the expensive JSON search text.
struct DockerImageSnapshot: Sendable {
    let items: [LuckyListItem]
    let entries: [DockerImageEntry]
    let ids: Set<String>

    init(items: [LuckyListItem] = []) {
        let entries = items.enumerated().map { index, item in
            DockerImageEntry(
                item: item,
                id: DockerRecord.keyOf(item, index),
                references: DockerRecord.imageReferences(item),
                searchText: DockerRecord.searchText(item)
            )
        }
        self.items = items
        self.entries = entries
        self.ids = Set(entries.map(\.id))
    }
}

/// Caches the serialized search index for Docker lists whose payload is unchanged across view
/// updates. Container statistics refresh frequently, but they do not change the container record
/// searched by the user, so rebuilding every JSON string on those ticks only stalls scrolling.
@MainActor
final class DockerSearchIndex {
    static let shared = DockerSearchIndex()

    private struct Snapshot {
        var items: [LuckyListItem]
        var text: [String]
    }

    private var snapshots: [DockerView: Snapshot] = [:]

    private init() {}

    func filter(_ items: [LuckyListItem], in view: DockerView, matching word: String)
        -> [LuckyListItem] {
        guard !word.isEmpty else { return items }
        let snapshot: Snapshot
        if let cached = snapshots[view], cached.items == items {
            snapshot = cached
        } else {
            snapshot = Snapshot(items: items, text: items.map(DockerRecord.searchText))
            snapshots[view] = snapshot
        }
        var result: [LuckyListItem] = []
        result.reserveCapacity(items.count)
        for index in items.indices where snapshot.text[index].contains(word) {
            result.append(items[index])
        }
        return result
    }
}

// MARK: - 当前视图

extension DockerScreen {
    /// §2's `active` — the query whose loading and error state the chrome reads. 设置 has three
    /// queries and `config` is the one the original picks, which is why its 维护状态 failure needs
    /// the separate card §17.3 draws.
    var activeQuery: DockerQuery { DockerScreen.query(of: view) }

    /// The same mapping against a view that is not necessarily the current one — a load that began
    /// before a tab switch still has to file its outcome under the query it was reading.
    static func query(of view: DockerView) -> DockerQuery {
        switch view {
        case .containers: .containers
        case .images: .images
        case .compose: .compose
        case .networks: .networks
        case .volumes: .volumes
        case .tasks: .tasks
        case .logs: .logs
        case .settings: .config
        }
    }

    /// The six searchable list payloads; settings and logs render their own sources.
    var source: [LuckyListItem] {
        switch view {
        case .containers: containers
        case .images: imageSnapshot.items
        case .compose: projects
        case .networks: networks
        case .volumes: volumes
        case .tasks: tasks
        case .settings, .logs: []
        }
    }

    /// `deferredSearch.trim().toLowerCase()`. `useDeferredValue` has no SwiftUI counterpart, so the
    /// filter runs on the keystroke rather than one frame behind it.
    var searchWord: String { search.jsTrimmed.lowercased() }

    /// §3's `filtered` — a substring test against the whole record stringified, which is why the
    /// box finds a container by a label value or a mount path just as readily as by its name.
    var filtered: [LuckyListItem] {
        let word = searchWord
        return DockerSearchIndex.shared.filter(source, in: view, matching: word)
    }
}

// MARK: - 镜像

extension DockerScreen {
    /// §3's `imageEntries`, prepared when the payload changes rather than on every body read.
    var imageEntries: [DockerImageEntry] { imageSnapshot.entries }

    /// The same word, matched against the entry's own cached text rather than re-stringified.
    var visibleImageEntries: [DockerImageEntry] {
        let word = searchWord
        guard !word.isEmpty else { return imageEntries }
        return imageEntries.filter { $0.searchText.contains(word) }
    }

    var imageIdSet: Set<String> { imageSnapshot.ids }

    /// `selectedImageIds.filter(id => imageIdSet.has(id))` — the pruning effect keeps the array in
    /// step with the payload, but a selection made against a list that has since been refetched is
    /// filtered here too, so a stale id can never reach a delete.
    var validSelectedImageIds: [String] {
        let ids = imageIdSet
        return selectedImageIds.filter { ids.contains($0) }
    }

    var selectedImageSet: Set<String> { Set(validSelectedImageIds) }

    var visibleImageIds: [String] { visibleImageEntries.map(\.id) }

    /// `length > 0 && every(...)` — an empty visible list is *not* "all selected", which is what
    /// keeps the 全选 label from reading 取消全选 over an empty search result.
    var allVisibleImagesSelected: Bool {
        let selected = selectedImageSet
        let visible = visibleImageIds
        return !visible.isEmpty && visible.allSatisfy { selected.contains($0) }
    }

    /// `mutation.isPending || unusedImageScanChecking` — what dims the checkboxes.
    var imageSelectionBusy: Bool { pending || unusedScanChecking }

    /// The selection busy flag plus the upgrade check, which leaves the checkboxes alone but stops
    /// every button in the header.
    var imageActionBusy: Bool { imageSelectionBusy || imageUpgradeChecking }
}

// MARK: - 容器统计

/// The three answers §25 needs, produced by one walk of the statistics payload instead of four.
struct DockerStatsDigest {
    var rows: [DockerStatRow] = []
    /// §25.1's map — every row under both its key and its name.
    var byKey: [String: DockerStatRow] = [:]
    /// §2's gate on the expensive per-container sweep.
    var liveNeeded = false
}

/// Memoizes that walk.
///
/// `DockerStats.rows` descends seven levels and re-parses every byte string it meets. The four
/// properties that used to front it each rebuilt the others: asking for the rows evaluated the
/// gate, the gate counted the cached rows, and the merged payload evaluated the gate a second
/// time — six to eight full walks for a single body pass, and a body pass happens on every
/// keystroke in the search field.
///
/// The inputs are values, so the memo compares them with `==`. That is a structural walk too, but
/// it allocates nothing, parses no strings and stops at the first difference, so it costs a
/// fraction of what it replaces. When a body pass changed something unrelated — the search text, a
/// sheet, the busy flag — the comparison succeeds and the derivation is skipped outright.
///
/// Shared rather than per-screen, as `DockerIconLoader` is: only one Docker screen is ever on
/// screen, and a digest left behind by a dismissed one is discarded by the first key comparison.
@MainActor
final class DockerStatsMemo {
    static let shared = DockerStatsMemo()

    /// Everything the digest reads. If none of it moved, the answer did not either.
    struct Inputs: Equatable {
        var containers: [LuckyListItem]
        var stats: JSONValue?
        var live: JSONValue?
        var progressive: JSONValue?
        var active: Bool
        var failed: Bool
        var succeeded: Bool
    }

    private var inputs: Inputs?
    private var digest = DockerStatsDigest()

    private init() {}

    func cached(for inputs: Inputs) -> DockerStatsDigest? {
        inputs == self.inputs ? digest : nil
    }

    func store(_ digest: DockerStatsDigest, for inputs: Inputs) {
        self.digest = digest
        self.inputs = inputs
    }
}

extension DockerScreen {
    var statsContainerItems: [LuckyListItem] { containers }

    /// The one entry point. `liveStatsNeeded`, `containerStatRows` and `containerStatsByKey` are
    /// all views onto this, so the six places that ask share a single derivation.
    var containerStatsDigest: DockerStatsDigest {
        let inputs = DockerStatsMemo.Inputs(
            containers: containers,
            stats: stats,
            live: liveStats,
            progressive: progressiveStats,
            active: statsActive,
            failed: statsFailed,
            succeeded: statsSucceeded
        )
        let memo = DockerStatsMemo.shared
        if let hit = memo.cached(for: inputs) { return hit }
        let digest = Self.statsDigest(inputs)
        memo.store(digest, for: inputs)
        return digest
    }

    /// `dockerStatRows(containerStats.data, …)` — the five-second cached sweep — then §2's gate,
    /// then, only when the gate opens, the same walk with the live sweep's results merged in.
    private static func statsDigest(_ inputs: DockerStatsMemo.Inputs) -> DockerStatsDigest {
        let items = inputs.containers
        let cached = DockerStats.rows(inputs.stats, containers: items)
        // §25.2 — `paused` counts as running, so a paused container still expects a stats row and
        // its absence still triggers the live sweep.
        let expected = items.reduce(into: 0) { total, item in
            let state = DockerStats.containerState(item)
            if state == .running || state == .paused { total += 1 }
        }
        // §2: the cheap bulk endpoint either failed, or succeeded while reporting fewer rows than
        // there are containers expected to have one.
        var liveNeeded = false
        if inputs.active {
            liveNeeded = inputs.failed || (inputs.succeeded && expected > cached.count)
        }
        // The cached rows are reused verbatim when the live sweep is not needed — walking the
        // merged payload would give the same answer for twice the work, and that memo split is the
        // original's whole reason for existing.
        var rows = cached
        if liveNeeded {
            // The live branch carries the partials the sweep streams while it is still running.
            let payloads = [inputs.stats, inputs.live, inputs.progressive].compactMap { $0 }
            rows = DockerStats.rows(.array(payloads), containers: items)
        }
        // §25.1 — every row is inserted **twice**, under its key and under its name, because the
        // container list and the statistics endpoint rarely agree on which of the two they print. A
        // row whose key and name collide with another's wins the later write, exactly as `Map` does.
        var byKey: [String: DockerStatRow] = [:]
        byKey.reserveCapacity(rows.count * 2)
        for row in rows {
            byKey[row.key] = row
            byKey[row.name] = row
        }
        return DockerStatsDigest(rows: rows, byKey: byKey, liveNeeded: liveNeeded)
    }

    var liveStatsNeeded: Bool { false }

    var containerStatRows: [DockerStatRow] { Array(statsByKey.values) }

    var containerStatsByKey: [String: DockerStatRow] { statsByKey }
}

// MARK: - 轮询门控

extension DockerScreen {
    /// `isScreenFocused` is `.task`'s own cancellation — a popped screen tears its tasks down — so
    /// only the scene phase is left to test.
    var statsActive: Bool { view == .containers && phase == .active }

    var logsActive: Bool { view == .logs && phase == .active }

    /// `.task(id:)` restarts a loop when its id changes and cancels it when the view goes away.
    /// A `String` rather than the flag itself so the three ids read alike.
    var statsTaskID: String { "\(statsActive)" }

    var liveStatsTaskID: String { "\(liveStatsNeeded)" }

    /// Paging the daemon log restarts the fifteen-second refetch, as changing the query key does.
    var logsTaskID: String { "\(logsActive)|\(logPage)" }
}

// MARK: - 页面状态

extension DockerScreen {
    /// `getDockerLogs(200, page)` — a full page is exactly this many lines, which is how §18's
    /// pager knows it has reached the end without a total.
    static let logPageSize = 200

    /// `lines(logs.data)` — docker's own flattener, not `LuckyLog.lines`.
    var logLines: [String] { DockerRecord.lines(logPayload) }

    /// `active.isFetching || (view === "settings" && maintenance.isFetching)` — 设置 refreshes three
    /// endpoints and the toolbar button must stay disabled until the slowest of them lands.
    var pageRefreshing: Bool { fetching || (view == .settings && maintenanceFetching) }

    /// `mutation.isPending`.
    var pending: Bool { running != nil }

    /// `active.isLoading` — fetching, and nothing cached to draw underneath.
    var loading: Bool { fetching && !loaded.contains(activeQuery) }

    /// `.alert(isPresented:)` wants a `Bool`; the request itself is the state.
    var confirming: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { shown in
            if !shown { confirmation = nil }
        })
    }
}
