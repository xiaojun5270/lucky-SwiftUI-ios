import SwiftUI

/// §17's eight verbs. Every one of them opens an editor or a confirmation the screen owns, so the
/// view carries no payloads — only the fact that the button was pressed.
struct DockerSettingsActions {
    var editConfig: () -> Void
    var createGroup: () -> Void
    var updateGroup: (_ name: String?, _ key: String?) -> Void
    var removeGroup: (_ key: String?) -> Void
    var clearUpgrades: () -> Void
    var addMirror: () -> Void
    var removeMirror: (_ mirror: String?) -> Void
    var prune: () -> Void
}

/// §17 — Docker 设置. Three read-only reports and eight verbs, in the scrollable page.
///
/// Nothing here is disabled while a mutation runs: the original's settings buttons all open a form
/// or a confirmation rather than firing, so a pending mutation cannot be made worse by pressing
/// one of them.
struct DockerSettingsView: View {
    var config: JSONValue?
    var mirrors: JSONValue?
    var maintenance: JSONValue?
    /// `maintenance.isFetching` — the only spinner in the view, printed as the 维护状态 meta.
    var maintenanceFetching: Bool
    /// `maintenance.error.message`, which gets a card of its own (§17.3) because `config` is the
    /// query the chrome's error card is wired to.
    var maintenanceFailure: String
    /// Shown only before anything has arrived. The original draws the two headers over nothing
    /// while the three queries are in flight (§25.15).
    var loading: Bool
    var refresh: @Sendable () async -> Void
    var actions: DockerSettingsActions

    var body: some View {
        DockerPaneScroll(refresh: refresh) {
            // `config.data ? … : null` — there is nothing to edit until the daemon's settings are
            // in hand, and an editor opened over an empty record would save an empty record.
            if config != nil {
                ServiceActionButton(title: "编辑 Docker 设置", symbol: LuckySymbol.settings, fill: .solid,
                                    height: 44, radius: LuckyTheme.Radius.row, glyph: 16) {
                    actions.editConfig()
                }
            }
            if !maintenanceFailure.isEmpty {
                LuckyErrorCard(message: maintenanceFailure) { Task { await refresh() } }
            }
            LuckySectionHeader(title: "维护状态", symbol: LuckySymbol.monitor,
                               iconRole: .system) {
                Text(maintenanceFetching ? "正在刷新" : "已同步")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textSecondary)
            }
            if let maintenance {
                groupPanel(maintenance)
                backupPanel(maintenance)
                upgradePanel(maintenance)
            } else if loading {
                LuckyLoadingView(text: "正在读取维护状态")
            }
            mirrorPanel
            // 清理未使用资源 stays in the scroll rather than moving to a glass bar: it is the last
            // thing in the page and it opens a five-switch form, not a one-tap action.
            ServiceActionButton(title: "清理未使用资源", symbol: "exclamationmark.shield",
                                tone: .danger, fill: .soft, height: 46,
                                radius: LuckyTheme.Radius.row, glyph: 17) {
                actions.prune()
            }
        }
    }
}

// MARK: - 维护状态面板

extension DockerSettingsView {
    private struct GroupItem: Identifiable {
        var key: String
        var name: String
        var collapsed: Bool?
        var id: String { key.isEmpty ? name : key }
    }

    private struct LabelItem: Identifiable {
        var name: String
        var count: Int?
        var id: String { name }
    }

    private struct BackupSummary {
        var inProgress: [String]
        var queue: [String]
        var error: String?
    }

    /// §17.5's first panel — unwraps the four maintenance endpoints into native counts, group rows
    /// and label chips instead of dumping nested `{ labels: { labels: {} } }` JSON trees.
    private func groupPanel(_ payload: JSONValue) -> some View {
        let collapsedMap = parseCollapsedStates(payload["collapsedStates"])
        let groups = parseGroups(payload["containerGroups"], collapsed: collapsedMap)
        let labels = parseLabels(payload["labels"])
        let orderCount = parseOrderCount(payload["orderMapping"])
        let errors = [
            ("容器标签", payload["labels"]),
            ("容器分组", payload["containerGroups"]),
            ("分组折叠状态", payload["collapsedStates"]),
            ("容器排序映射", payload["orderMapping"]),
        ].compactMap { title, raw -> String? in
            guard let msg = raw?["error"]?.stringValue?.jsTrimmed, !msg.isEmpty else { return nil }
            return "\(title)：\(msg)"
        }

        return panel(title: "分组与标签", symbol: "shippingbox", iconRole: .docker) {
            HStack(spacing: 0) {
                statTile("自定义分组", "\(groups.count)", tint: groups.isEmpty ? LuckyTheme.textSecondary : LuckyTheme.accent, divided: false)
                statTile("容器标签", "\(labels.count)", tint: labels.isEmpty ? LuckyTheme.textSecondary : LuckyTheme.textPrimary, divided: true)
                statTile("自定义排序", "\(orderCount)", tint: orderCount == 0 ? LuckyTheme.textSecondary : LuckyTheme.textPrimary, divided: true)
            }
            .frame(minHeight: 50)
            .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: LuckyTheme.Radius.row))

            if !errors.isEmpty {
                LuckyErrorCard(message: errors.joined(separator: "\n"), title: "部分状态读取失败")
            }

            if groups.isEmpty {
                Text("暂未创建自定义容器分组")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(groups) { group in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(group.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LuckyTheme.textPrimary)
                                        .lineLimit(1)
                                    if let collapsed = group.collapsed {
                                        LuckyChip(text: collapsed ? "已折叠" : "已展开", tone: .idle)
                                    }
                                }
                                if !group.key.isEmpty, group.key != group.name {
                                    Text(group.key)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(LuckyTheme.textTertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                LuckyHaptic.light()
                                actions.updateGroup(group.name, group.key)
                            } label: {
                                LuckyIconTile(symbol: LuckySymbol.edit, size: 28, glyph: 12, tone: .idle)
                            }
                            .buttonStyle(LuckyPressStyle())
                            .accessibilityLabel("编辑分组 \(group.name)")
                            Button {
                                LuckyHaptic.light()
                                actions.removeGroup(group.key)
                            } label: {
                                LuckyIconTile(symbol: LuckySymbol.delete, size: 28, glyph: 12, tone: .danger)
                            }
                            .buttonStyle(LuckyPressStyle())
                            .accessibilityLabel("删除分组 \(group.name)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: LuckyTheme.Radius.row))
                    }
                }
            }

            if !labels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("容器标签")
                        .font(LuckyTheme.Text.captionMedium)
                        .foregroundStyle(LuckyTheme.textSecondary)
                    LuckyTileGrid(minimum: 112, spacing: 6) {
                        ForEach(labels) { item in
                            HStack(spacing: 5) {
                                Text(item.name)
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(LuckyTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 2)
                                if let count = item.count {
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(LuckyTheme.accent)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(LuckyTheme.accentSoft, in: .capsule)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: 8))
                        }
                    }
                }
            }

            HStack(spacing: LuckyTheme.Space.s) {
                ServiceActionButton(title: "添加分组", symbol: LuckySymbol.add, fill: .tinted,
                                    height: 38, radius: LuckyTheme.Radius.row, glyph: 14) {
                    actions.createGroup()
                }
                ServiceActionButton(title: "编辑分组", symbol: LuckySymbol.edit, fill: .card,
                                    height: 38, radius: LuckyTheme.Radius.row, glyph: 14) {
                    actions.updateGroup(nil, nil)
                }
                ServiceActionButton(title: "删除分组", symbol: LuckySymbol.delete, tone: .danger,
                                    fill: .tinted, height: 38,
                                    radius: LuckyTheme.Radius.row, glyph: 14) {
                    actions.removeGroup(nil)
                }
            }
        }
    }

    /// §17.5's second panel — native Compose & volume backup queue rows without raw `in_progress`/`queue` keys.
    private func backupPanel(_ payload: JSONValue) -> some View {
        let compose = parseBackupStatus(payload["composeBackup"])
        let volume = parseBackupStatus(payload["volumeBackup"])
        return panel(title: "备份任务", symbol: LuckySymbol.disk, iconRole: .storage) {
            VStack(spacing: 8) {
                backupStatusRow(title: "Compose 备份", summary: compose)
                backupStatusRow(title: "数据卷备份", summary: volume)
            }
        }
    }

    private func backupStatusRow(title: String, summary: BackupSummary) -> some View {
        let activeCount = summary.inProgress.count
        let queuedCount = summary.queue.count
        let pillText: String = {
            if summary.error != nil { return "读取失败" }
            if activeCount > 0 { return "进行中 \(activeCount)" }
            if queuedCount > 0 { return "排队中 \(queuedCount)" }
            return "空闲"
        }()
        let pillTone: LuckyTone = {
            if summary.error != nil { return .danger }
            if activeCount > 0 { return .brand }
            if queuedCount > 0 { return .warning }
            return .idle
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LuckyTheme.textPrimary)
                Spacer(minLength: 4)
                LuckyChip(text: pillText, tone: pillTone)
            }
            if let error = summary.error {
                Text(error)
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.danger)
            } else {
                Text("进行中 \(activeCount) · 排队中 \(queuedCount)")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .monospacedDigit()
                if !summary.inProgress.isEmpty {
                    Text("正在备份：" + summary.inProgress.joined(separator: "、"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LuckyTheme.accent)
                        .lineLimit(2)
                }
                if !summary.queue.isEmpty {
                    Text("等待队列：" + summary.queue.joined(separator: "、"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: LuckyTheme.Radius.row))
    }

    /// §17.5's third panel — the upgrade report, and the one verb in 设置 that fires a mutation.
    private func upgradePanel(_ payload: JSONValue) -> some View {
        let raw = payload["imageUpgrades"] ?? .null
        let unwrapped = unwrapUpgradePayload(raw)
        return panel(title: "镜像升级", symbol: DockerView.images.symbol, iconRole: .media) {
            if let error = raw["error"]?.stringValue?.jsTrimmed, !error.isEmpty {
                LuckyErrorCard(message: error, title: "状态读取失败")
            } else if isEmptyPayload(unwrapped) {
                Text("暂无镜像升级检查记录")
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                StructuredDataView(value: unwrapped)
            }
            ServiceActionButton(title: "清除升级状态", symbol: LuckySymbol.delete, tone: .danger,
                                fill: .soft, height: 38,
                                radius: LuckyTheme.Radius.row, glyph: 14) {
                actions.clearUpgrades()
            }
        }
    }

    private var mirrorPanel: some View {
        let urls = mirrorURLs
        return panel(title: "镜像加速源", symbol: "globe.asia.australia", iconRole: .network) {
            if urls.isEmpty {
                if case .array(let items) = mirrorList, !items.isEmpty {
                    StructuredDataView(value: mirrorList)
                } else {
                    Text("暂未配置镜像加速源")
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(urls, id: \.self) { url in
                        HStack(spacing: 8) {
                            Text(url)
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(LuckyTheme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                LuckyHaptic.light()
                                actions.removeMirror(url)
                            } label: {
                                LuckyIconTile(symbol: LuckySymbol.delete, size: 26, glyph: 11, tone: .danger)
                            }
                            .buttonStyle(LuckyPressStyle())
                            .accessibilityLabel("删除加速源 \(url)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: 8))
                    }
                }
            }
            HStack(spacing: LuckyTheme.Space.s) {
                ServiceActionButton(title: "添加", symbol: LuckySymbol.add, fill: .tinted,
                                    height: 38, radius: LuckyTheme.Radius.row, glyph: 14) {
                    actions.addMirror()
                }
                ServiceActionButton(title: "删除", symbol: LuckySymbol.delete, tone: .danger,
                                    fill: .tinted, height: 38,
                                    radius: LuckyTheme.Radius.row, glyph: 14) {
                    actions.removeMirror(nil)
                }
            }
        }
    }

    /// `mirrors.data?.mirrors ?? mirrors.data?.list ?? []` — JS `??` falls through `null` only, so
    /// a module that answers with an empty `mirrors` array stops here rather than trying `list`.
    private var mirrorList: JSONValue {
        guard let mirrors else { return .array([]) }
        if let value = mirrors["mirrors"], !value.isNull { return value }
        if let value = mirrors["list"], !value.isNull { return value }
        return .array([])
    }

    private var mirrorURLs: [String] {
        guard let items = mirrorList.arrayValue else { return [] }
        return items.compactMap { item in
            if let text = item.stringValue?.jsTrimmed, !text.isEmpty { return text }
            if item.isRecord {
                let text = DockerRecord.pick(item, ["url", "mirror", "address"], "").jsTrimmed
                return text.isEmpty ? nil : text
            }
            return nil
        }
    }

    // MARK: - Maintenance Unwrapping Helpers

    private func statTile(_ label: String, _ value: String, tint: Color, divided: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(LuckyTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .overlay(alignment: .leading) {
            if divided {
                Rectangle()
                    .fill(LuckyTheme.hairline)
                    .frame(width: LuckyTheme.strokeWidth)
                    .padding(.vertical, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func parseCollapsedStates(_ raw: JSONValue?) -> [String: Bool] {
        guard let raw, !raw.isNull else { return [:] }
        let source = raw["states"]?.isRecord == true ? raw["states"]! : (raw["data"]?.isRecord == true ? raw["data"]! : raw)
        var map: [String: Bool] = [:]
        for (key, value) in source.record.pairs where key != "ret" && key != "msg" && key != "error" {
            if let flag = value.boolValue { map[key] = flag }
        }
        return map
    }

    private func parseGroups(_ raw: JSONValue?, collapsed: [String: Bool]) -> [GroupItem] {
        guard let raw, !raw.isNull else { return [] }
        let list: [JSONValue] = raw["list"]?.arrayValue
            ?? raw["groups"]?.arrayValue
            ?? raw["data"]?.arrayValue
            ?? raw.arrayValue
            ?? []
        return list.enumerated().map { index, item in
            if let text = item.stringValue?.jsTrimmed, !text.isEmpty {
                return GroupItem(key: text, name: text, collapsed: collapsed[text])
            }
            let key = DockerRecord.pick(item, ["Key", "key", "ID", "id"], "")
            let name = DockerRecord.pick(item, ["Name", "name", "Title", "title"],
                                         key.isEmpty ? "分组 \(index + 1)" : key)
            return GroupItem(key: key, name: name, collapsed: collapsed[key])
        }
    }

    private func parseLabels(_ raw: JSONValue?) -> [LabelItem] {
        guard let raw, !raw.isNull else { return [] }
        let inner = raw["labels"] ?? raw["data"] ?? raw["list"] ?? raw
        if let arr = inner.arrayValue {
            return arr.compactMap { entry in
                if let text = entry.stringValue?.jsTrimmed, !text.isEmpty {
                    return LabelItem(name: text, count: nil)
                }
                if entry.isRecord {
                    let name = DockerRecord.pick(entry, ["name", "label", "key", "Name"], "").jsTrimmed
                    guard !name.isEmpty else { return nil }
                    let count = entry["count"]?.doubleValue.map(Int.init)
                    return LabelItem(name: name, count: count)
                }
                return nil
            }
        }
        var items: [LabelItem] = []
        for (key, value) in inner.record.pairs where key != "ret" && key != "msg" && key != "error" {
            let count: Int? = {
                if let arr = value.arrayValue { return arr.count }
                if let n = value.doubleValue { return Int(n) }
                return nil
            }()
            items.append(LabelItem(name: key, count: count))
        }
        return items
    }

    private func parseOrderCount(_ raw: JSONValue?) -> Int {
        guard let raw, !raw.isNull else { return 0 }
        let mappingCount = (raw["mapping"]?.record.count ?? 0) + (raw["containerGroupMap"]?.record.count ?? 0)
        let orderCount = (raw["order"]?.arrayValue?.count ?? 0) + (raw["orderList"]?.arrayValue?.count ?? 0)
        return max(mappingCount, orderCount)
    }

    private func parseBackupStatus(_ raw: JSONValue?) -> BackupSummary {
        guard let raw, !raw.isNull else {
            return BackupSummary(inProgress: [], queue: [], error: nil)
        }
        if let err = raw["error"]?.stringValue?.jsTrimmed, !err.isEmpty {
            return BackupSummary(inProgress: [], queue: [], error: err)
        }
        let source = raw["data"]?.isRecord == true ? raw["data"]! : raw
        let active = extractBackupNames(source["in_progress"] ?? source["inProgress"])
        let queued = extractBackupNames(source["queue"])
        return BackupSummary(inProgress: active, queue: queued, error: nil)
    }

    private func extractBackupNames(_ value: JSONValue?) -> [String] {
        guard let list = value?.arrayValue else { return [] }
        return list.compactMap { item in
            if let text = item.stringValue?.jsTrimmed, !text.isEmpty { return text }
            if item.isRecord {
                let text = DockerRecord.pick(item, ["project_name", "volume_name", "name", "id"], "").jsTrimmed
                return text.isEmpty ? nil : text
            }
            return nil
        }
    }

    private func unwrapUpgradePayload(_ raw: JSONValue) -> JSONValue {
        if let inner = raw["upgrades"], !inner.isNull { return inner }
        if let inner = raw["statuses"], !inner.isNull { return inner }
        if let inner = raw["data"], !inner.isNull { return inner }
        var obj = raw.record
        obj.removeValue(forKey: "ret")
        obj.removeValue(forKey: "msg")
        return .object(obj)
    }

    private func isEmptyPayload(_ value: JSONValue) -> Bool {
        switch value {
        case .null: return true
        case .array(let items): return items.isEmpty
        case .object(let obj): return obj.isEmpty
        case .string(let text): return text.jsTrimmed.isEmpty
        default: return false
        }
    }

    /// `<Panel><SectionHeader …/>…</Panel>` — the header sits inside the plate, as it does in the
    /// original, because these three are cards nested in a page that already has its own headings.
    private func panel<Content: View>(
        title: String,
        symbol: String,
        iconRole: LuckyIconRole,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        LuckyCard(spacing: LuckyTheme.Space.m) {
            LuckySectionHeader(title: title, symbol: symbol, iconRole: iconRole)
            content()
        }
    }
}
