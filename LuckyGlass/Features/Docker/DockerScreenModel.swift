import Foundation
import Observation

/// The eight Docker workspaces, in tab order.
enum DockerView: String, Hashable, CaseIterable, Identifiable, Sendable {
    case containers, images, compose, networks, volumes, tasks, settings, logs

    var id: String { rawValue }

    /// The tab labels, verbatim. `搜索${label}` is built from these, which is why `Compose`
    /// carries no Chinese name.
    var label: String {
        switch self {
        case .containers: "容器"
        case .images: "镜像"
        case .compose: "Compose"
        case .networks: "网络"
        case .volumes: "数据卷"
        case .tasks: "任务"
        case .settings: "设置"
        case .logs: "日志"
        }
    }

    /// `Container`, `Image`, `Workflow`, `Network`, `Database`, `Activity`, `Gauge`, `Settings2`,
    /// `FileText`.
    var symbol: String {
        switch self {
        case .containers: "shippingbox"
        case .images: "photo.on.rectangle.angled"
        case .compose: "flowchart"
        case .networks: LuckySymbol.network
        case .volumes: "externaldrive"
        case .tasks: "waveform.path.ecg"
        case .settings: "gearshape.2"
        case .logs: LuckySymbol.logs
        }
    }

    var iconRole: LuckyIconRole {
        switch self {
        case .containers: .docker
        case .images: .media
        case .compose, .tasks: .automation
        case .networks: .network
        case .volumes: .storage
        case .settings: .settings
        case .logs: .logs
        }
    }

    /// The `SectionHeader` title, which may be more specific than the tab label.
    var title: String {
        switch self {
        case .containers: "容器"
        case .images: "镜像列表"
        case .compose: "Compose 项目"
        case .networks: "Docker 网络"
        case .volumes: "数据卷"
        case .tasks: "后台任务"
        case .settings: "Docker 设置"
        case .logs: "Docker 日志"
        }
    }

    /// `dockerListViews` — the seven views rendered as a `FlatList` rather than a scroll view.
    static let listViews: [DockerView] = [
        .containers, .images, .compose, .networks, .volumes, .tasks, .logs,
    ]

    /// `isDockerListView(view)`.
    var isList: Bool { Self.listViews.contains(self) }

    /// `搜索${label}` — no space, and only for the six searchable lists.
    var searchPrompt: String? {
        switch self {
        case .containers, .images, .compose, .networks, .volumes, .tasks: "搜索\(label)"
        case .settings, .logs: nil
        }
    }

    /// `<EmptyState message>`; settings has no list empty state.
    var emptyMessage: String {
        switch self {
        case .containers: "暂无容器"
        case .images: "暂无镜像"
        case .compose: "暂无 Compose 项目"
        case .networks: "暂无 Docker 网络"
        case .volumes: "暂无数据卷"
        case .tasks: "暂无后台任务"
        case .logs: "暂无 Docker 日志"
        case .settings: ""
        }
    }
}

/// §2's query keys, as a value. `containerStats` covers both the cached sweep and the live one —
/// they are refetched together and invalidated together, so one case is enough.
enum DockerQuery: Hashable, Sendable {
    case containers, images, compose, networks, volumes, tasks
    case config, mirrors, maintenance, logs
    case containerStats, iconLibrary
}

// MARK: - 编辑器

/// Every `editor.type` the screen can open — §24.5's forty-three titles, keyed by the string the
/// original stores in `editor.type`.
///
/// Seven of these never reach the mutation: `containerFileDownload`, `imageFilesystemView`,
/// `composeDiscover`, `composeReadFile` and `composeBackupDownload` are intercepted by §19.2's save
/// handler and turn into a detail or a download, while `composeConfig` and `composeDockerfile` are
/// rewritten to their `-save` counterparts. `mutation` is where that mapping lives.
enum DockerEditorKind: String, Hashable, Sendable {
    case containerCreate = "container-create"
    case containerEdit = "container-edit"
    case containerUpgrade = "container-upgrade"
    case containerRename = "container-rename"
    case containerCopy = "container-copy"
    case containerCommit = "container-commit"
    case containerLabelSet = "container-label-set"
    case containerGroupSet = "container-group-set"
    case containerVersionSwitch = "container-version-switch"
    case containerFiles = "container-files"
    case containerFileDownload = "container-file-download"
    case containerFileUpload = "container-file-upload"
    case imagePull = "image-pull"
    case imageBuild = "image-build"
    case imageBuildGit = "image-build-git"
    case imageBuildZip = "image-build-zip"
    case imageImport = "image-import"
    case imageLoad = "image-load"
    case imageTag = "image-tag"
    case imagePush = "image-push"
    case imageFilesystemView = "image-filesystem-view"
    case composeDiscover = "compose-discover"
    case composeConfig = "compose-config"
    case composeDockerfile = "compose-dockerfile"
    case composeReadFile = "compose-read-file"
    case composeBackupDownload = "compose-backup-download"
    case composeBackupRestore = "compose-backup-restore"
    case composeBackupRemove = "compose-backup-remove"
    case composeBackupUpload = "compose-backup-upload"
    case composeRestore = "compose-restore"
    case networkCreate = "network-create"
    case volumeCreate = "volume-create"
    case volumeRestore = "volume-restore"
    case volumeBackupRemove = "volume-backup-remove"
    case volumeBackupUpload = "volume-backup-upload"
    case volumeImport = "volume-import"
    case configSave = "config-save"
    case groupCreate = "group-create"
    case groupUpdate = "group-update"
    case groupRemove = "group-remove"
    case mirrorAdd = "mirror-add"
    case mirrorRemove = "mirror-remove"
    case prune
}

extension DockerEditorKind {
    /// The mutation `type` a save produces, or `nil` when §19.2 handles the form itself.
    var mutation: DockerActionType? {
        switch self {
        case .containerFileDownload, .imageFilesystemView, .composeDiscover,
             .composeReadFile, .composeBackupDownload:
            return nil
        // The two rewrites: the form is `compose-config`, the mutation is `compose-config-save`.
        case .composeConfig: return .composeConfigSave
        case .composeDockerfile: return .composeDockerfileSave
        default: return DockerActionType(rawValue: rawValue)
        }
    }

    /// `mirror-remove` moves `value.mirror` into `key` and sends no `value` at all.
    var sendsFieldAsKey: String? { self == .mirrorRemove ? "mirror" : nil }
}

/// `EditorState` — the form `DockerFormEditor` is currently showing.
struct DockerEditorRequest: Identifiable, Hashable {
    var kind: DockerEditorKind
    var title: String
    var value: JSONValue
    var key: String?

    /// `key={`${editor.type}-${editor.key ?? "new"}`}`, which `.sheet(item:)` reuses as identity.
    var id: String { "\(kind.rawValue)-\(key ?? "new")" }

    init(_ kind: DockerEditorKind, title: String, value: JSONValue, key: String? = nil) {
        self.kind = kind
        self.title = title
        self.value = value
        self.key = key
    }
}

// MARK: - 详情浮层

/// `DetailState` — the read-only viewer that shows an inspect result, a scan report, or the receipt
/// of a download. `loading`, `value` and `error` are mutually exclusive in practice but not in the
/// type, exactly as in the original: a download sets `loading` **and** `status` together.
///
/// The title is the identity. Every flow that writes here writes two or three times under one
/// title — 正在下载 then the receipt, 正在检测 3/8 then the report — and `.sheet(item:)` re-presents
/// when the id changes, so a `UUID` would tear the sheet down and rebuild it on each of those.
struct DockerDetail: Identifiable, Hashable {
    var title: String
    var loading = false
    var status: String?
    var value: JSONValue?
    var error: String?

    var id: String { title }

    init(_ title: String, loading: Bool = false, status: String? = nil,
         value: JSONValue? = nil, error: String? = nil) {
        self.title = title
        self.loading = loading
        self.status = status
        self.value = value
        self.error = error
    }
}

// MARK: - 操作菜单

/// `containerMenu` — `name` is the daemon's raw name and may keep a leading `/`.
struct DockerContainerMenu: Identifiable, Hashable {
    var key: String
    var name: String
    var running: Bool
    var paused: Bool

    var id: String { key }

    /// `name.replace(/^\/+/, "")` — what the two payloads and the export filename use.
    var bareName: String {
        var trimmed = Substring(name)
        while trimmed.first == "/" { trimmed = trimmed.dropFirst() }
        return String(trimmed)
    }
}

/// `imageMenu`.
struct DockerImageMenu: Identifiable, Hashable {
    var key: String
    var name: String

    var id: String { key }

    /// `name !== "<none>" ? name.split(",")[0] : key` — the reference a delete is keyed by.
    var deleteKey: String {
        guard name != "<none>" else { return key }
        return name.components(separatedBy: ",").first ?? key
    }
}

/// `{ completed, total }` — the batch counters the image flows and the delete button print.
struct DockerProgress: Hashable, Sendable {
    var completed = 0
    var total = 0
}

// MARK: - Compose 创建

/// `composeProgress` — the running commentary of a `compose-create`, rebuilt from every task poll.
struct DockerComposeProgress: Hashable, Sendable {
    var taskId: String
    var status = ""
    var message: String
    /// `undefined` when the payload carried no finite number, which is what hides the bar.
    var progress: Double?

    /// The literal message, for the two states that have no task payload yet.
    init(taskId: String = "", message: String) {
        self.taskId = taskId
        self.message = message
        self.progress = nil
    }

    /// `composeTaskProgress(payload, taskId)`.
    init(_ payload: JSONValue, taskId: String) {
        self.taskId = taskId
        status = (DockerRecord.deepScalar(payload, ["status", "state"])?.asDisplayString ?? "")
            .jsTrimmed
        let text = (DockerRecord.deepScalar(payload, ["message", "output", "error"])?
            .asDisplayString ?? "").jsTrimmed
        if !text.isEmpty {
            message = text
        } else if !status.isEmpty {
            message = "任务状态：\(status)"
        } else {
            message = "正在创建 Compose 项目"
        }
        // `Number(undefined)` is NaN, so a payload missing all three keys leaves the bar off.
        let raw = DockerComposeProgress.jsNumber(
            DockerRecord.deepScalar(payload, ["progress", "percent", "percentage"])
        )
        progress = raw.isFinite ? min(100, max(0, raw)) : nil
    }

    /// `Number(value)` over the three scalar cases `deepScalar` can return.
    private static func jsNumber(_ value: JSONValue?) -> Double {
        switch value {
        case .number(let number): return number
        case .string(let text): return JSCompat.number(text)
        case .bool(let flag): return flag ? 1 : 0
        default: return .nan
        }
    }
}

/// `composeCreate` — the five fields of §19.3's creator, which is its own modal rather than one of
/// `DockerFormEditor`'s generated forms.
struct DockerComposeCreateValue: Hashable, Sendable {
    var projectName = ""
    var workingDirectory = ""
    var configFileName = "compose.yaml"
    var composeContent = DockerComposeCreateValue.template
    var build = false

    /// `defaultComposeTemplate` — verbatim, trailing newline included.
    static let template = """
        services:
          app:
            image: nginx:alpine
            container_name: lucky-compose-app
            restart: unless-stopped
            ports:
              - "8080:80"

        """

    /// One megabyte, the ceiling both the file import and the submit check enforce.
    static let contentLimit = 1024 * 1024

    /// `/\\.ya?ml$/i` — the only two extensions the daemon will write.
    static func isYAMLName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered.hasSuffix(".yml") || lowered.hasSuffix(".yaml")
    }

    /// The outcome of `submit()`: either the normalised value, or the message to show.
    enum Validation {
        case ok(DockerComposeCreateValue)
        case failed(String)
    }

    /// `submit()` — the creator's own validation, whose copy differs from the mutation's even where
    /// the check is the same.
    func validated() -> Validation {
        var next = self
        next.projectName = projectName.jsTrimmed
        next.workingDirectory = workingDirectory.jsTrimmed
        next.configFileName = configFileName.jsTrimmed
        if next.workingDirectory.isEmpty { return .failed("请输入工作目录") }
        if next.configFileName.isEmpty { return .failed("请输入配置文件名") }
        if next.configFileName.contains("/") || next.configFileName.contains("\\")
            || !Self.isYAMLName(next.configFileName) {
            return .failed("配置文件名必须是 .yml 或 .yaml 文件名，不能包含路径")
        }
        let trimmedContent = composeContent.jsTrimmed
        if trimmedContent.isEmpty { return .failed("请输入 Compose YAML 内容") }
        if trimmedContent.count > Self.contentLimit { return .failed("Compose 内容不能超过 1 MB") }
        // The content itself is sent untrimmed — only the three names are normalised.
        return .ok(next)
    }

    /// The `value` the mutation reads, with the form's own names mapped onto the daemon's.
    var payload: JSONValue {
        .object([
            ("project_name", .string(projectName)),
            ("working_dir", .string(workingDirectory)),
            ("config_file_name", .string(configFileName)),
            ("compose_content", .string(composeContent)),
            ("build", .bool(build)),
        ])
    }
}

private struct DockerPersistedSnapshot: Codable, Sendable {
    var containersJSON: String
    var iconsJSON: String
    var imagesJSON: String
    var composeJSON: String
    var networksJSON: String
    var volumesJSON: String
    var statsByKey: [String: DockerStatRow]
    var savedAt: TimeInterval
}

private struct DockerHydratedPayload: Sendable {
    var containers: [LuckyListItem]
    var icons: [JSONValue]
    var containerRows: [DockerContainerRow]
    var imageSnapshot: DockerImageSnapshot
    var projects: [LuckyListItem]
    var networks: [LuckyListItem]
    var volumes: [LuckyListItem]
    var statsByKey: [String: DockerStatRow]
    var savedAt: Date
}

private final class DockerThrottleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var lastFlush: Date = .distantPast

    func shouldFlush(minInterval: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        guard now.timeIntervalSince(lastFlush) >= minInterval else { return false }
        lastFlush = now
        return true
    }
}

/// Account-scoped persistent cache and background warmup engine for Docker containers & telemetry.
/// Hydrates cached data from disk off the main actor on launch and refreshes stats quietly in the
/// background so entering Docker never flashes `--` or stalls scrolling.
@MainActor
@Observable
final class DockerStatsCache {
    static let shared = DockerStatsCache()

    var stats: JSONValue?
    var liveStats: JSONValue?
    var containers: [LuckyListItem] = []
    var icons: [JSONValue] = []
    var imageSnapshot = DockerImageSnapshot()
    var projects: [LuckyListItem] = []
    var networks: [LuckyListItem] = []
    var volumes: [LuckyListItem] = []
    private(set) var prebuiltContainerRows: [DockerContainerRow] = []
    private(set) var statsByKey: [String: DockerStatRow] = [:]
    private(set) var loadedQueries: Set<DockerQuery> = []
    private(set) var statsSucceeded = false
    private(set) var statsFailed = false
    private(set) var liveStatsFailure = ""
    private(set) var dataRevision: UInt64 = 0
    private(set) var statsRevision: UInt64 = 0

    private var activeAccountKey = ""
    private var activeGeneration: UInt64 = 0
    private var hydratedAccountKey = ""
    private var lastUpdated: [DockerQuery: Date] = [:]
    private var statsRefreshInFlight = false
    private var containersRefreshInFlight = false
    private var liveSweepTask: Task<Void, Never>?
    private var diskSaveTask: Task<Void, Never>?

    private init() {}

    // MARK: - Account Scope & Freshness

    static func accountKey(baseUrl: String, account: String) -> String {
        let normalized = "\(baseUrl.jsTrimmed.withoutTrailingSlashes)|\(account)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in normalized.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    private static func cacheFileURL(for key: String) -> URL? {
        guard !key.isEmpty else { return nil }
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return root
            .appendingPathComponent("LuckyDockerCache", isDirectory: true)
            .appendingPathComponent("\(key).json")
    }

    func activate(credentials: LuckyCredentials) {
        let key = Self.accountKey(baseUrl: credentials.baseUrl, account: credentials.account)
        guard key != activeAccountKey || credentials.generation != activeGeneration else { return }
        diskSaveTask?.cancel()
        diskSaveTask = nil
        liveSweepTask?.cancel()
        liveSweepTask = nil
        activeAccountKey = key
        activeGeneration = credentials.generation
        hydratedAccountKey = ""
        resetMemory()
    }

    func isFresh(_ query: DockerQuery, maxAge: TimeInterval = 25) -> Bool {
        guard let stamp = lastUpdated[query] else { return false }
        return Date().timeIntervalSince(stamp) < maxAge
    }

    func hasWarmData(for view: DockerView) -> Bool {
        switch view {
        case .containers: return !containers.isEmpty || loadedQueries.contains(.containers)
        case .images: return !imageSnapshot.items.isEmpty || loadedQueries.contains(.images)
        case .compose: return !projects.isEmpty || loadedQueries.contains(.compose)
        case .networks: return !networks.isEmpty || loadedQueries.contains(.networks)
        case .volumes: return !volumes.isEmpty || loadedQueries.contains(.volumes)
        case .tasks, .settings, .logs: return false
        }
    }

    var runningContainerCount: Int {
        prebuiltContainerRows.reduce(into: 0) { if $1.running { $0 += 1 } }
    }

    private nonisolated static func diskCacheBytesSync() -> Int64 {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return 0
        }
        let folders = ["LuckyDockerCache", "LuckyDockerIcons", "LuckyWebCache"]
        var total: Int64 = 0
        let fm = FileManager.default
        for name in folders {
            let dir = root.appendingPathComponent(name, isDirectory: true)
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    /// Total disk usage across persistent Docker, icon and Web rule caches.
    static func totalDiskCacheBytes() async -> Int64 {
        await Task.detached(priority: .utility) {
            Self.diskCacheBytesSync()
        }.value
    }

    /// Clears persistent Docker, icon and Web rule caches on disk and resets in-memory snapshots.
    func clearAllDiskCaches() async {
        clear()
        WebRulesCache.shared.clear()
        ServiceSummaryCache.shared.clear()
        await Task.detached(priority: .utility) {
            guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return
            }
            let fm = FileManager.default
            for name in ["LuckyDockerCache", "LuckyDockerIcons", "LuckyWebCache"] {
                let dir = root.appendingPathComponent(name, isDirectory: true)
                try? fm.removeItem(at: dir)
            }
        }.value
    }

    func clear() {
        diskSaveTask?.cancel()
        diskSaveTask = nil
        liveSweepTask?.cancel()
        liveSweepTask = nil
        hydratedAccountKey = ""
        resetMemory()
    }

    private func resetMemory() {
        stats = nil
        liveStats = nil
        containers = []
        icons = []
        imageSnapshot = DockerImageSnapshot()
        projects = []
        networks = []
        volumes = []
        prebuiltContainerRows = []
        statsByKey = [:]
        loadedQueries = []
        lastUpdated = [:]
        statsSucceeded = false
        statsFailed = false
        liveStatsFailure = ""
        statsRefreshInFlight = false
        containersRefreshInFlight = false
        DockerIconIndex.shared.seed(items: [], icons: [], rows: [])
        dataRevision &+= 1
        statsRevision &+= 1
    }

    // MARK: - Disk Persistence

    func hydrateFromDiskIfNeeded(credentials: LuckyCredentials) async {
        guard !credentials.baseUrl.isEmpty else { return }
        activate(credentials: credentials)
        let key = activeAccountKey
        let generation = activeGeneration
        guard hydratedAccountKey != key, let url = Self.cacheFileURL(for: key) else { return }
        hydratedAccountKey = key

        let payload: DockerHydratedPayload? = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let snapshot = try? JSONDecoder().decode(DockerPersistedSnapshot.self, from: data) else {
                return nil
            }
            let containers = JSONParser.tryParse(snapshot.containersJSON)?.arrayValue ?? []
            let icons = JSONParser.tryParse(snapshot.iconsJSON)?.arrayValue ?? []
            let images = JSONParser.tryParse(snapshot.imagesJSON)?.arrayValue ?? []
            let projects = JSONParser.tryParse(snapshot.composeJSON)?.arrayValue ?? []
            let networks = JSONParser.tryParse(snapshot.networksJSON)?.arrayValue ?? []
            let volumes = JSONParser.tryParse(snapshot.volumesJSON)?.arrayValue ?? []
            return DockerHydratedPayload(
                containers: containers,
                icons: icons,
                containerRows: DockerIconIndex.buildRows(items: containers, icons: icons),
                imageSnapshot: DockerImageSnapshot(items: images),
                projects: projects,
                networks: networks,
                volumes: volumes,
                statsByKey: snapshot.statsByKey,
                savedAt: Date(timeIntervalSince1970: snapshot.savedAt)
            )
        }.value

        guard generation == activeGeneration, key == activeAccountKey, let payload else { return }
        var dataChanged = false
        if containers.isEmpty, !payload.containers.isEmpty {
            containers = payload.containers
            loadedQueries.insert(.containers)
            dataChanged = true
        }
        if icons.isEmpty, !payload.icons.isEmpty {
            icons = payload.icons
            loadedQueries.insert(.iconLibrary)
            dataChanged = true
        }
        if !payload.containerRows.isEmpty, containers == payload.containers, icons == payload.icons {
            prebuiltContainerRows = payload.containerRows
            DockerIconIndex.shared.seed(items: payload.containers, icons: payload.icons, rows: payload.containerRows)
            let paths = payload.containerRows.map(\.icon)
            Task { await DockerIconLoader.shared.prewarm(paths) }
        }
        if imageSnapshot.items.isEmpty, !payload.imageSnapshot.items.isEmpty {
            imageSnapshot = payload.imageSnapshot
            loadedQueries.insert(.images)
            dataChanged = true
        }
        if projects.isEmpty, !payload.projects.isEmpty {
            projects = payload.projects
            loadedQueries.insert(.compose)
            dataChanged = true
        }
        if networks.isEmpty, !payload.networks.isEmpty {
            networks = payload.networks
            loadedQueries.insert(.networks)
            dataChanged = true
        }
        if volumes.isEmpty, !payload.volumes.isEmpty {
            volumes = payload.volumes
            loadedQueries.insert(.volumes)
            dataChanged = true
        }
        if dataChanged { dataRevision &+= 1 }

        if statsByKey.isEmpty, !payload.statsByKey.isEmpty {
            statsByKey = payload.statsByKey
            statsSucceeded = true
            statsRevision &+= 1
        }
    }

    private func schedulePersist() {
        let key = activeAccountKey
        guard !key.isEmpty, let url = Self.cacheFileURL(for: key) else { return }
        let containersCopy = containers
        let iconsCopy = icons
        let imagesCopy = imageSnapshot.items
        let projectsCopy = projects
        let networksCopy = networks
        let volumesCopy = volumes
        let statsCopy = statsByKey

        diskSaveTask?.cancel()
        diskSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) {
                let snapshot = DockerPersistedSnapshot(
                    containersJSON: JSONSerializer.stringify(.array(containersCopy)),
                    iconsJSON: JSONSerializer.stringify(.array(iconsCopy)),
                    imagesJSON: JSONSerializer.stringify(.array(imagesCopy)),
                    composeJSON: JSONSerializer.stringify(.array(projectsCopy)),
                    networksJSON: JSONSerializer.stringify(.array(networksCopy)),
                    volumesJSON: JSONSerializer.stringify(.array(volumesCopy)),
                    statsByKey: statsCopy,
                    savedAt: Date().timeIntervalSince1970
                )
                guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
                let folder = url.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? encoded.write(to: url, options: .atomic)
            }.value
        }
    }

    // MARK: - Background Warmup & Off-Main-Thread Parsing

    /// Runs while the authenticated app is foregrounded (`LuckyRoot`), keeping Docker lists and
    /// container stats warm in memory and persisted on disk so opening Docker is instant.
    func runBackgroundWarmup(credentials: LuckyCredentials) async {
        guard !credentials.baseUrl.isEmpty, !credentials.token.isEmpty else { return }
        activate(credentials: credentials)
        let generation = activeGeneration

        await hydrateFromDiskIfNeeded(credentials: credentials)

        var cycle = 0
        while !Task.isCancelled, generation == activeGeneration {
            await refreshContainersAndStatsQuietly(generation: generation)
            if cycle % 3 == 0 {
                await refreshSecondaryListsQuietly(generation: generation)
            }
            cycle += 1
            try? await Task.sleep(for: .seconds(20))
        }
    }

    private func refreshContainersAndStatsQuietly(generation: UInt64) async {
        guard !Task.isCancelled, generation == activeGeneration else { return }
        _ = try? await refreshContainers(force: true, generation: generation)
        guard !Task.isCancelled, generation == activeGeneration else { return }
        await refreshStats(force: true, generation: generation)
    }

    private func refreshSecondaryListsQuietly(generation: UInt64) async {
        guard !Task.isCancelled, generation == activeGeneration else { return }
        async let imagesFetch = try? DockerService.images().items
        async let composeFetch = try? DockerService.composeProjects().items
        async let networksFetch = try? DockerService.networks().items
        async let volumesFetch = try? DockerService.volumes().items

        let (fetchedImages, fetchedCompose, fetchedNetworks, fetchedVolumes) = await (
            imagesFetch, composeFetch, networksFetch, volumesFetch
        )
        guard !Task.isCancelled, generation == activeGeneration else { return }

        var changed = false
        if let fetchedImages {
            let snapshot = await Task.detached(priority: .utility) {
                DockerImageSnapshot(items: fetchedImages)
            }.value
            guard generation == activeGeneration else { return }
            if snapshot.items != imageSnapshot.items || !loadedQueries.contains(.images) {
                imageSnapshot = snapshot
                changed = true
            }
            loadedQueries.insert(.images)
            lastUpdated[.images] = Date()
        }
        if let fetchedCompose {
            if fetchedCompose != projects || !loadedQueries.contains(.compose) {
                projects = fetchedCompose
                changed = true
            }
            loadedQueries.insert(.compose)
            lastUpdated[.compose] = Date()
        }
        if let fetchedNetworks {
            if fetchedNetworks != networks || !loadedQueries.contains(.networks) {
                networks = fetchedNetworks
                changed = true
            }
            loadedQueries.insert(.networks)
            lastUpdated[.networks] = Date()
        }
        if let fetchedVolumes {
            if fetchedVolumes != volumes || !loadedQueries.contains(.volumes) {
                volumes = fetchedVolumes
                changed = true
            }
            loadedQueries.insert(.volumes)
            lastUpdated[.volumes] = Date()
        }
        if changed {
            dataRevision &+= 1
            schedulePersist()
        }
    }

    @discardableResult
    func refreshContainers(force: Bool = false, generation: UInt64? = nil) async throws -> [LuckyListItem] {
        let expectedGen = generation ?? activeGeneration
        if !force, !containers.isEmpty, isFresh(.containers) {
            return containers
        }
        if containersRefreshInFlight {
            return containers
        }
        containersRefreshInFlight = true
        defer { containersRefreshInFlight = false }

        let wantsIcons = !loadedQueries.contains(.iconLibrary) || icons.isEmpty
        let previousContainers = containers
        let previousRows = prebuiltContainerRows
        let wasLoaded = loadedQueries.contains(.containers)

        let items = try await DockerService.containers().items
        guard expectedGen == activeGeneration else { return containers }

        var latestIcons = icons
        var iconsChanged = false
        if wantsIcons, let library = try? await IconLibService.icons(), expectedGen == activeGeneration {
            latestIcons = library
            iconsChanged = true
        }

        // Diff raw JSON payloads & compute container rows off the main actor so pull-to-refresh
        // never runs O(N) deep JSONValue equality or icon-library scanning on @MainActor.
        let computed = await Task.detached(priority: .utility) { () -> (rows: [DockerContainerRow], containersChanged: Bool) in
            let rows = DockerIconIndex.buildRows(items: items, icons: latestIcons)
            let changed = !wasLoaded || rows != previousRows || items != previousContainers
            return (rows, changed)
        }.value
        guard expectedGen == activeGeneration else { return containers }

        loadedQueries.insert(.containers)
        lastUpdated[.containers] = Date()
        if iconsChanged {
            icons = latestIcons
            loadedQueries.insert(.iconLibrary)
            lastUpdated[.iconLibrary] = Date()
        }
        if computed.containersChanged || iconsChanged {
            containers = items
            prebuiltContainerRows = computed.rows
            DockerIconIndex.shared.seed(items: items, icons: latestIcons, rows: computed.rows)
            dataRevision &+= 1
            let iconPaths = computed.rows.map(\.icon)
            Task { await DockerIconLoader.shared.prewarm(iconPaths) }
            schedulePersist()
        } else if prebuiltContainerRows.isEmpty, !computed.rows.isEmpty {
            prebuiltContainerRows = computed.rows
            DockerIconIndex.shared.seed(items: items, icons: latestIcons, rows: computed.rows)
        }
        return containers
    }

    func storeImages(_ snapshot: DockerImageSnapshot) {
        lastUpdated[.images] = Date()
        loadedQueries.insert(.images)
        imageSnapshot = snapshot
        dataRevision &+= 1
        schedulePersist()
    }

    func storeList(_ target: DockerView, items: [LuckyListItem]) {
        let query = DockerScreen.query(of: target)
        lastUpdated[query] = Date()
        loadedQueries.insert(query)
        switch target {
        case .images:
            imageSnapshot = DockerImageSnapshot(items: items)
        case .compose:
            projects = items
        case .networks:
            networks = items
        case .volumes:
            volumes = items
        default:
            return
        }
        dataRevision &+= 1
        schedulePersist()
    }

    func refreshStats(
        force: Bool = false,
        generation: UInt64? = nil,
        awaitLiveFallback: Bool = true
    ) async {
        let expectedGen = generation ?? activeGeneration
        if !force, !statsByKey.isEmpty, isFresh(.containerStats, maxAge: 10) {
            return
        }
        guard !statsRefreshInFlight else { return }
        statsRefreshInFlight = true
        defer { statsRefreshInFlight = false }

        let snapshotContainers = containers
        var payloads: [JSONValue] = []
        var bulkFailed = false

        do {
            let fetched = try await DockerService.allContainerStats()
            guard !Task.isCancelled, expectedGen == activeGeneration else { return }
            stats = fetched
            statsSucceeded = true
            statsFailed = false
            payloads.append(fetched)
        } catch {
            guard !error.isCancellation, !Task.isCancelled, expectedGen == activeGeneration else { return }
            statsSucceeded = false
            statsFailed = true
            bulkFailed = true
        }

        var liveNeeded = bulkFailed
        if !payloads.isEmpty {
            let parsed = await Self.parseStatsOffMain(payloads: payloads, containers: snapshotContainers)
            guard !Task.isCancelled, expectedGen == activeGeneration else { return }
            applyMergedStats(parsed.byKey, containers: snapshotContainers)
            liveNeeded = parsed.liveNeeded
        }

        if liveNeeded, !snapshotContainers.isEmpty {
            let bulkSnapshot = stats
            if awaitLiveFallback {
                await runLiveStatsSweep(
                    containers: snapshotContainers,
                    bulkPayload: bulkSnapshot,
                    generation: expectedGen
                )
            } else {
                // Pull-to-refresh must release UIRefreshControl smoothly instead of pinning it
                // open for seconds during a 38-container fallback sweep.
                scheduleBackgroundLiveSweep(
                    containers: snapshotContainers,
                    bulkPayload: bulkSnapshot,
                    generation: expectedGen
                )
            }
        }
        lastUpdated[.containerStats] = Date()
    }

    private func scheduleBackgroundLiveSweep(
        containers items: [LuckyListItem],
        bulkPayload: JSONValue?,
        generation expectedGen: UInt64
    ) {
        guard liveSweepTask == nil else { return }
        liveSweepTask = Task { [weak self] in
            defer { self?.liveSweepTask = nil }
            await self?.runLiveStatsSweep(
                containers: items,
                bulkPayload: bulkPayload,
                generation: expectedGen
            )
        }
    }

    private func runLiveStatsSweep(
        containers items: [LuckyListItem],
        bulkPayload: JSONValue?,
        generation expectedGen: UInt64
    ) async {
        let throttle = DockerThrottleBox()
        do {
            let fetched = try await DockerService.refreshContainerStats(items: items) { partial in
                guard throttle.shouldFlush(minInterval: 2.0) else { return }
                let payloads = [bulkPayload, partial].compactMap { $0 }
                Task.detached(priority: .utility) {
                    let parsed = Self.parseStatsSync(payloads: payloads, containers: items)
                    await MainActor.run {
                        let cache = DockerStatsCache.shared
                        guard cache.activeGeneration == expectedGen else { return }
                        cache.applyMergedStats(parsed.byKey, containers: items, persist: false)
                    }
                }
            }
            guard !Task.isCancelled, expectedGen == activeGeneration else { return }
            liveStats = fetched
            liveStatsFailure = ""
            let finalPayloads = [bulkPayload, fetched].compactMap { $0 }
            let parsed = await Self.parseStatsOffMain(payloads: finalPayloads, containers: items)
            guard !Task.isCancelled, expectedGen == activeGeneration else { return }
            applyMergedStats(parsed.byKey, containers: items, persist: true)
        } catch {
            guard !error.isCancellation, !Task.isCancelled, expectedGen == activeGeneration else { return }
            liveStatsFailure = error.luckyMessage()
        }
    }

    private func applyMergedStats(
        _ incoming: [String: DockerStatRow],
        containers: [LuckyListItem],
        persist: Bool = true
    ) {
        guard !incoming.isEmpty else { return }
        var merged = statsByKey
        for (key, row) in incoming {
            merged[key] = row
        }
        if merged != statsByKey {
            statsByKey = merged
            statsRevision &+= 1
            if persist { schedulePersist() }
        }
    }

    private nonisolated static func parseStatsSync(
        payloads: [JSONValue],
        containers: [LuckyListItem]
    ) -> (rows: [DockerStatRow], byKey: [String: DockerStatRow], liveNeeded: Bool) {
        let source: JSONValue = payloads.count == 1 ? payloads[0] : .array(payloads)
        let rows = DockerStats.rows(source, containers: containers)
        let expected = containers.reduce(into: 0) { total, item in
            let state = DockerStats.containerState(item)
            if state == .running || state == .paused { total += 1 }
        }
        var byKey: [String: DockerStatRow] = [:]
        byKey.reserveCapacity(rows.count * 2)
        for row in rows {
            byKey[row.key] = row
            byKey[row.name] = row
        }
        return (rows, byKey, expected > rows.count)
    }

    private static func parseStatsOffMain(
        payloads: [JSONValue],
        containers: [LuckyListItem]
    ) async -> (rows: [DockerStatRow], byKey: [String: DockerStatRow], liveNeeded: Bool) {
        await Task.detached(priority: .utility) {
            Self.parseStatsSync(payloads: payloads, containers: containers)
        }.value
    }
}
