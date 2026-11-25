import SwiftUI

/// Docker queries owned by view-scoped `.task` loops.
///
/// react-query's `enabled` flag becomes the `.task(id:)` that owns the loop: cancelling the task
/// cancels the request and the sleep with it, which is what `enabled: false` does to a mounted
/// query. `staleTime` has no counterpart — re-entering a view always refetches, which is a visible
/// divergence on a fast tab bounce and a harmless one.
extension DockerScreen {
    /// Syncs cached lists & icons hydrated or warmed in the background into view state.
    /// Guarded by O(1) revision checks so unchanged refreshes never cascade `@State` rebuilds.
    func syncListsFromCache(force: Bool = false) {
        let cache = DockerStatsCache.shared
        guard force || syncedDataRevision != cache.dataRevision else { return }
        syncedDataRevision = cache.dataRevision
        if !cache.containers.isEmpty || cache.loadedQueries.contains(.containers) {
            containers = cache.containers
        }
        if !cache.icons.isEmpty {
            icons = cache.icons
        }
        if !cache.imageSnapshot.items.isEmpty || cache.loadedQueries.contains(.images) {
            imageSnapshot = cache.imageSnapshot
        }
        if !cache.projects.isEmpty || cache.loadedQueries.contains(.compose) {
            projects = cache.projects
        }
        if !cache.networks.isEmpty || cache.loadedQueries.contains(.networks) {
            networks = cache.networks
        }
        if !cache.volumes.isEmpty || cache.loadedQueries.contains(.volumes) {
            volumes = cache.volumes
        }
        if !cache.loadedQueries.isSubset(of: loaded) {
            loaded.formUnion(cache.loadedQueries)
        }
    }

    /// Syncs off-main-thread pre-parsed telemetry without stalling scrolling.
    func syncStatsFromCache(force: Bool = false) {
        let cache = DockerStatsCache.shared
        guard force || syncedStatsRevision != cache.statsRevision else { return }
        syncedStatsRevision = cache.statsRevision
        if !cache.statsByKey.isEmpty, statsByKey != cache.statsByKey {
            statsByKey = cache.statsByKey
        }
        let succeeded = cache.statsSucceeded || !cache.statsByKey.isEmpty
        if statsSucceeded != succeeded { statsSucceeded = succeeded }
        if statsFailed != cache.statsFailed { statsFailed = cache.statsFailed }
        if liveStatsFailure != cache.liveStatsFailure { liveStatsFailure = cache.liveStatsFailure }
    }

    /// Entry-time load: serves disk-hydrated & background-warmed cache immediately with zero
    /// network storm on page entry. Only fetches when a view has no warm cache yet.
    func loadView() async {
        let cache = DockerStatsCache.shared
        await cache.hydrateFromDiskIfNeeded(credentials: LuckySession.shared.credentials)
        syncListsFromCache()
        syncStatsFromCache()

        switch view {
        case .logs: return
        case .containers:
            // Background warmup keeps containers & stats fresh — never stall entry when cached.
            if !cache.hasWarmData(for: .containers) {
                await loadContainers(force: true)
            }
            if statsByKey.isEmpty {
                await loadStats(force: false, awaitLiveFallback: false)
            }
        case .settings:
            await loadSettings()
        default:
            let query = DockerScreen.query(of: view)
            if !cache.hasWarmData(for: view) || !cache.isFresh(query, maxAge: 45) {
                await loadList(view, force: !cache.hasWarmData(for: view))
            }
        }
    }

    /// The five plain list views.
    ///
    /// There is deliberately no `guard !fetching` prologue: `.task(id: view)` starts the next
    /// view's load before the cancelled one has returned, and a guard would drop it. The flag is
    /// instead cleared only by the load still standing on the view it started on.
    private func loadList(_ target: DockerView, force: Bool = true) async {
        let key = DockerScreen.query(of: target)
        let hasCached = DockerStatsCache.shared.hasWarmData(for: target)
        if !hasCached || force { fetching = !hasCached }
        defer { if view == target { fetching = false } }
        do {
            switch target {
            case .images:
                let items = try await DockerService.images().items
                let snapshot = await Task.detached(priority: .utility) {
                    DockerImageSnapshot(items: items)
                }.value
                imageSnapshot = snapshot
                DockerStatsCache.shared.storeImages(snapshot)
            case .compose:
                let items = try await DockerService.composeProjects().items
                projects = items
                DockerStatsCache.shared.storeList(.compose, items: items)
            case .networks:
                let items = try await DockerService.networks().items
                networks = items
                DockerStatsCache.shared.storeList(.networks, items: items)
            case .volumes:
                let items = try await DockerService.volumes().items
                volumes = items
                DockerStatsCache.shared.storeList(.volumes, items: items)
            case .tasks:
                tasks = try await DockerService.tasks().items
            default: return
            }
            queryFailures[key] = ""
            loaded.insert(key)
        } catch {
            // A cancelled read is a view switch, not a failure; react-query drops those too.
            guard !error.isCancellation else { return }
            queryFailures[key] = error.luckyMessage()
        }
    }

    /// Refreshes containers & icons via `DockerStatsCache.shared` so results persist to disk.
    /// `quiet: true` during pull-to-refresh avoids toggling toolbar `fetching` while UIRefreshControl animates.
    private func loadContainers(force: Bool = false, quiet: Bool = false) async {
        let hasCached = !containers.isEmpty
        if !quiet && !hasCached { fetching = true }
        defer { if !quiet && view == .containers && fetching { fetching = false } }
        do {
            _ = try await DockerStatsCache.shared.refreshContainers(force: force)
            syncListsFromCache()
            if !(queryFailures[.containers] ?? "").isEmpty {
                queryFailures[.containers] = ""
            }
            if !loaded.contains(.containers) {
                loaded.insert(.containers)
            }
        } catch {
            guard !error.isCancellation else { return }
            queryFailures[.containers] = error.luckyMessage()
        }
    }

    /// 设置's three queries. They start together, as react-query mounts them together; the awaits
    /// are ordered because each writes its own slot. `config` is `active`, so it owns `fetching`
    /// and the header's error card; `maintenance` has its own spinner (§17.4's 正在刷新 meta) and
    /// its own card (§17.3); `mirrors` surfaces neither, so a failure leaves the last list showing.
    private func loadSettings() async {
        async let configRead = DockerService.config()
        async let mirrorRead = DockerService.registryMirrors()
        async let maintenanceRead = DockerService.maintenanceStatus()
        fetching = true
        maintenanceFetching = true
        do {
            config = try await configRead
            queryFailures[.config] = ""
            loaded.insert(.config)
        } catch {
            if !error.isCancellation { queryFailures[.config] = error.luckyMessage() }
        }
        if view == .settings { fetching = false }
        if let list = try? await mirrorRead {
            mirrors = list
            loaded.insert(.mirrors)
        }
        do {
            maintenance = try await maintenanceRead
            queryFailures[.maintenance] = ""
            loaded.insert(.maintenance)
        } catch {
            if !error.isCancellation { queryFailures[.maintenance] = error.luckyMessage() }
        }
        if view == .settings { maintenanceFetching = false }
    }
}

// MARK: - 日志轮询

extension DockerScreen {
    /// `logs`: `refetchInterval: 15000`, and unlike the tunnel and webservice logs every page polls
    /// — the query key carries `dockerLogPage`, so paging is a new query and not a new argument.
    func pollLogs() async {
        guard logsActive else { return }
        await loadLogs()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            await loadLogs()
        }
    }

    private func loadLogs() async {
        fetching = true
        defer { if view == .logs { fetching = false } }
        do {
            logPayload = try await DockerService.logs(
                pageSize: DockerScreen.logPageSize, page: logPage
            )
            queryFailures[.logs] = ""
            loaded.insert(.logs)
        } catch {
            guard !error.isCancellation else { return }
            queryFailures[.logs] = error.luckyMessage()
        }
    }
}

// MARK: - 容器统计

extension DockerScreen {
    /// Container stats are refreshed off the main actor through `DockerStatsCache.shared`, so
    /// manual refreshes and mutations stay single-flight, merged and persisted to disk.
    private func loadStats(force: Bool = true, awaitLiveFallback: Bool = false) async {
        let showLoading = statsByKey.isEmpty && !statsFailed
        if showLoading { statsLoading = true }
        defer { if statsLoading { statsLoading = false } }
        await DockerStatsCache.shared.refreshStats(force: force, awaitLiveFallback: awaitLiveFallback)
        syncStatsFromCache()
    }
}

// MARK: - 刷新与失效

extension DockerScreen {
    /// The toolbar button and pull-to-refresh. On 容器, containers and bulk stats fetch in parallel
    /// without blocking UIRefreshControl on slow per-container fallback sweeps.
    func refresh(fromPull: Bool = false) async {
        if view == .containers, statsActive {
            async let listTask: Void = loadContainers(force: true, quiet: fromPull)
            async let statsTask: Void = loadStats(force: true, awaitLiveFallback: false)
            _ = await (listTask, statsTask)
            return
        }
        await reloadActive(force: true)
        guard statsActive else { return }
        await refreshStats()
    }

    /// Reload the current workspace. 日志 normally owns an interval, but manual refresh reads now.
    private func reloadActive(force: Bool = true) async {
        switch view {
        case .logs: await loadLogs()
        case .containers: await loadContainers(force: force)
        case .settings: await loadSettings()
        default: await loadList(view, force: force)
        }
    }

    /// Forces a background off-main-thread stats sweep and merges results into cache.
    func refreshStats() async {
        await loadStats(force: true, awaitLiveFallback: false)
    }

    /// §26's cascade. react-query refetches the mounted queries and marks the rest stale; every
    /// view here reloads on entry anyway, so marking an off-screen one stale is a no-op and the
    /// sweep reduces to "reload whatever is showing". The view keeps its old rows while that runs,
    /// which is what makes this a refetch and not a reload.
    ///
    /// 设置 is the one view whose `active` query is not the only one on screen, so a sweep that
    /// touches 维护状态 reloads it too.
    func invalidate(_ type: DockerActionType) async {
        await invalidate(keys: type.invalidates)
    }

    /// The same sweep for the two places that name their keys directly rather than deriving them
    /// from a mutation: the upgrade check writes 维护状态, and a submitted Compose task writes 任务.
    func invalidate(keys: [DockerQuery]) async {
        guard !keys.isEmpty else { return }
        if keys.contains(activeQuery) || (view == .settings && keys.contains(.maintenance)) {
            await reloadActive()
        }
        guard keys.contains(.containerStats), statsActive else { return }
        await refreshStats()
    }
}
