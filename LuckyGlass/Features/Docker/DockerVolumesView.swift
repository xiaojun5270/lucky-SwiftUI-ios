import SwiftUI

/// §14's eight verbs. Every one of them is keyed by the volume's **name** and not by `keyOf` — the
/// daemon's volume endpoints take a name, and the row's index has no meaning to them.
enum DockerVolumeVerb: String, CaseIterable, Identifiable, Sendable {
    case backup, backupList, export, backupUpload
    case backupRestore, backupRemove, backupCancel, remove

    var id: String { rawValue }

    var label: String {
        switch self {
        case .backup: "备份"
        case .backupList: "备份列表"
        case .export: "导出"
        case .backupUpload: "上传备份"
        case .backupRestore: "恢复备份"
        case .backupRemove: "删除备份"
        case .backupCancel: "取消备份"
        case .remove: "删除"
        }
    }

    var symbol: String {
        switch self {
        case .backup: "tray.and.arrow.down"
        case .backupList: LuckySymbol.search
        case .export: LuckySymbol.download
        case .backupUpload: LuckySymbol.upload
        case .backupRestore: LuckySymbol.restart
        case .backupRemove, .remove: LuckySymbol.delete
        case .backupCancel: "stop.circle"
        }
    }

    var tint: Color {
        switch self {
        case .backup: LuckyTheme.accent
        case .backupList: LuckyTheme.textPrimary
        case .export, .backupUpload: LuckyTheme.info
        case .backupRestore: LuckyTheme.warning
        case .backupRemove, .backupCancel, .remove: LuckyTheme.danger
        }
    }

    /// Only the two destructive ones ask, and only these two: 删除备份 opens a form instead, which
    /// is its own confirmation.
    func confirmation(_ name: String) -> (title: String, message: String)? {
        switch self {
        case .backupCancel: ("取消备份", "取消数据卷 \(name) 的备份任务？")
        case .remove: ("确认删除", "删除数据卷 \(name)？")
        default: nil
        }
    }
}

/// §14 — 数据卷.
struct DockerVolumesView: View {
    var items: [LuckyListItem]
    var loading: Bool
    var busy: Bool
    var refresh: @Sendable () async -> Void
    var importVolume: () -> Void
    var perform: (DockerVolumeVerb, String) -> Void

    private struct VolumeRowEntry: Identifiable {
        var id: String
        var item: LuckyListItem
        var index: Int
    }

    private var rowEntries: [VolumeRowEntry] {
        var seen = Set<String>()
        seen.reserveCapacity(items.count)
        return items.enumerated().map { index, item in
            let base = DockerRecord.pick(item, ["Name", "name"], DockerRecord.keyOf(item, index))
            var id = base
            var suffix = 1
            while !seen.insert(id).inserted {
                id = "\(base)#\(suffix)"
                suffix += 1
            }
            return VolumeRowEntry(id: id, item: item, index: index)
        }
    }

    var body: some View {
        DockerListPane(count: items.count, loading: loading,
                       empty: DockerView.volumes.emptyMessage,
                       symbol: DockerView.volumes.symbol,
                       loadingText: "正在读取数据卷",
                       spacing: 6, refresh: refresh) {
            header
        } rows: {
            ForEach(rowEntries) { entry in
                DockerVolumeCard(item: entry.item, index: entry.index, busy: busy, perform: perform)
            }
        }
    }

    /// 创建数据卷 has moved into the glass bar; 导入数据卷 stays, because it opens a file picker and
    /// belongs beside the list it adds to.
    private var header: some View {
        ServiceActionButton(title: "导入数据卷", symbol: LuckySymbol.upload, fill: .tinted,
                            height: 34, radius: 9, glyph: 13) {
            importVolume()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - 数据卷卡片

private struct DockerVolumeCard: View {
    var item: LuckyListItem
    var index: Int
    var busy: Bool
    var perform: (DockerVolumeVerb, String) -> Void

    private static let primaryVerbs: [DockerVolumeVerb] = [.backup, .backupList, .export]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `pick(item, ["Name","name"], keyOf(item,index))` — and this string is the key every one of
    /// the eight verbs sends.
    private var name: String {
        DockerRecord.pick(item, ["Name", "name"], DockerRecord.keyOf(item, index))
    }

    /// `${pick(item,["Driver"],"local")} · ${pick(item,["Mountpoint"])}`
    private var subtitle: String {
        let driver = DockerRecord.localizedDriver(DockerRecord.pick(item, ["Driver"], "local"))
        let mount = DockerRecord.pick(item, ["Mountpoint"])
        return [driver, mount].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        LuckyCard(radius: 14, padding: 0) {
            VStack(alignment: .leading, spacing: 6) {
                heading
                LuckyHairline()
                commandLayout {
                    ForEach(Self.primaryVerbs) { verb in
                        DockerIconButton(symbol: verb.symbol, label: verb.label, tint: verb.tint,
                                         disabled: busy, fluid: true, compact: true) {
                            perform(verb, name)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var heading: some View {
        HStack(spacing: 8) {
            LuckyIconTile(symbol: DockerView.volumes.symbol, size: 30, glyph: 15,
                          role: DockerView.volumes.iconRole)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            moreMenu
        }
        .frame(minHeight: 34)
    }

    private var moreMenu: some View {
        Menu {
            Section("备份管理") {
                menuButton(.backupUpload)
                menuButton(.backupRestore)
                menuButton(.backupCancel)
            }
            Section("危险操作") {
                menuButton(.backupRemove, role: .destructive)
                menuButton(.remove, role: .destructive)
            }
        } label: {
            LuckyIconTile(symbol: "ellipsis", size: 28, glyph: 14, tone: .idle)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.5 : 1)
        .accessibilityLabel("\(name) 的更多操作")
    }

    private func menuButton(_ verb: DockerVolumeVerb, role: ButtonRole? = nil) -> some View {
        Button(role: role) {
            perform(verb, name)
        } label: {
            Label(verb.label, systemImage: verb.symbol)
        }
    }

    private var commandLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: LuckyTheme.Space.s / 2))
            : AnyLayout(HStackLayout(spacing: LuckyTheme.Space.s))
    }
}
