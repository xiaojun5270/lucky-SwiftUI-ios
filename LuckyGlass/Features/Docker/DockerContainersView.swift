import SwiftUI

/// The six verbs §10's rows dispatch. Handed over rather than reached for, because `private` in
/// Swift is file-scoped and every one of these lives on `DockerScreen`.
struct DockerContainerActions {
    var menu: (DockerContainerMenu) -> Void
    var unpause: (String) -> Void
    var start: (String) -> Void
    var stop: (String, String) -> Void
    var restart: (String, String) -> Void
    var update: (String, String) -> Void
}

private enum DockerContainerFilter: String, CaseIterable, Identifiable {
    case all, running, stopped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .running: return "运行中"
        case .stopped: return "已停止"
        }
    }

    var tone: LuckyTone {
        switch self {
        case .all: return .brand
        case .running: return .ok
        case .stopped: return .idle
        }
    }
}

/// §10's 容器 list.
struct DockerContainersView: View {
    var items: [LuckyListItem]
    var icons: [JSONValue]
    /// Pre-built container rows computed off the main actor when no search filter is active,
    /// avoiding repeated deep `[JSONValue]` comparisons during scrolling and pull-to-refresh.
    var prebuiltRows: [DockerContainerRow]? = nil
    var stats: [String: DockerStatRow]
    var loading: Bool
    var busy: Bool
    var refresh: @Sendable () async -> Void
    var actions: DockerContainerActions

    @State private var filter: DockerContainerFilter = .all

    var body: some View {
        let allRows = prebuiltRows ?? DockerIconIndex.shared.rows(items: items, icons: icons)
        let runningCount = allRows.reduce(into: 0) { if $1.running { $0 += 1 } }
        let stoppedCount = allRows.count - runningCount
        let displayedRows: [DockerContainerRow] = {
            switch filter {
            case .all: return allRows
            case .running: return allRows.filter(\.running)
            case .stopped: return allRows.filter { !$0.running }
            }
        }()

        DockerListPane(count: displayedRows.count, loading: loading,
                       empty: allRows.isEmpty ? DockerView.containers.emptyMessage : "暂无符合条件的容器",
                       symbol: DockerView.containers.symbol,
                       loadingText: "正在读取容器",
                       spacing: 6, refresh: refresh) {
            if !allRows.isEmpty {
                filterBar(total: allRows.count, running: runningCount, stopped: stoppedCount)
            }
        } rows: {
            // Identified by the container itself rather than by its array offset. An offset shifts
            // for every row below an insertion, so starting or removing one container told SwiftUI
            // that every row after it was a different row and the whole list was rebuilt.
            ForEach(displayedRows, id: \.identity) { row in
                // Equatable cards skip subtree diffing during pull-to-refresh and partial stats ticks.
                DockerContainerCard(row: row, stat: row.stats(stats), busy: busy, actions: actions)
                    .equatable()
            }
        }
    }

    private func filterBar(total: Int, running: Int, stopped: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(DockerContainerFilter.allCases) { option in
                let selected = filter == option
                let count: Int = switch option {
                case .all: total
                case .running: running
                case .stopped: stopped
                }
                Button {
                    guard !selected else { return }
                    LuckyHaptic.selection()
                    withAnimation(LuckyTheme.Motion.snap) { filter = option }
                } label: {
                    HStack(spacing: 3) {
                        Text(option.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        Text("\(count)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .opacity(selected ? 0.9 : 0.7)
                    }
                    .foregroundStyle(selected ? option.tone.tint : LuckyTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 26)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selected ? option.tone.fill : LuckyTheme.surface)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                selected ? option.tone.tint.opacity(0.35) : LuckyTheme.hairline.opacity(0.4),
                                lineWidth: LuckyTheme.strokeWidth
                            )
                    )
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(LuckyPressStyle(pressedScale: 0.95, pressedOpacity: 0.75))
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }
}

// MARK: - 行

/// §10's per-row derivation, done once rather than five times inside the card.
///
/// Everything here is resolved in `init` and stored. These used to be computed properties, which on
/// a `View` struct means they re-run on every body evaluation — the status phrase was being rebuilt
/// from the raw record sixty times a second while scrolling.
struct DockerContainerRow: Equatable, Sendable {
    var key: String
    /// What `ForEach` diffs on. Normally the key; suffixed only if the daemon repeated one.
    var identity: String
    var state: DockerContainerState
    var name: String
    var displayName: String
    var status: String
    /// Filled in by the list, which owns the icon library. Empty means "draw the fallback glyph".
    var icon = ""

    init(_ item: LuckyListItem, _ index: Int) {
        let key = DockerRecord.keyOf(item, index)
        self.key = key
        identity = key
        let state = DockerStats.containerState(item)
        self.state = state
        // §25.2 — a paused container is still a running one for every purpose but its own verb.
        let running = state == .running || state == .paused
        // `key.slice(0, 12)` — a container with no name at all is known by the head of its id.
        let fallback = String(key.prefix(12))
        let name = DockerRecord.pick(item, ["Names", "Name", "name"], fallback)
        self.name = name
        // `name.replace(/^\/+/, "") || name` — a name of nothing but slashes keeps them.
        let bare = String(name.drop { $0 == "/" })
        displayName = bare.isEmpty ? name : bare
        status = DockerRecord.containerStatus(item, running: running, paused: state == .paused)
    }

    var paused: Bool { state == .paused }
    var running: Bool { state == .running || paused }

    /// The list and the statistics endpoint rarely agree on which of the two they print, so both
    /// are tried. §25.1's map holds every row under each.
    func stats(_ table: [String: DockerStatRow]) -> DockerStatRow? {
        table[key] ?? table[displayName]
    }

    var menu: DockerContainerMenu {
        DockerContainerMenu(key: key, name: name, running: running, paused: paused)
    }
}

// MARK: - 卡片

private struct DockerContainerCard: View, Equatable {
    var row: DockerContainerRow
    var stat: DockerStatRow?
    var busy: Bool
    var actions: DockerContainerActions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static func == (lhs: DockerContainerCard, rhs: DockerContainerCard) -> Bool {
        lhs.row == rhs.row && lhs.stat == rhs.stat && lhs.busy == rhs.busy
    }

    var body: some View {
        // Compact container card: ~50% tighter fonts, metric tiles, padding and rhythm.
        LuckyCard(radius: 14, padding: 0) {
            VStack(alignment: .leading, spacing: LuckyTheme.Space.xs) {
                Button {
                    LuckyHaptic.light()
                    actions.menu(row.menu)
                } label: {
                    heading
                }
                .buttonStyle(LuckyPressStyle())
                .accessibilityLabel("打开容器 \(row.displayName) 操作菜单")
                ContainerStatsGrid(stats: stat).equatable()
                LuckyHairline()
                commands
            }
            .padding(.horizontal, LuckyTheme.Space.cardInset / 2)
            .padding(.vertical, 6)
        }
    }

    private var heading: some View {
        HStack(spacing: 7) {
            ContainerArtwork(icon: row.icon, running: row.running, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                badge
            }
            // Compact ellipsis affordance; the whole header row is the button.
            LuckyIconTile(symbol: "ellipsis", size: 24, glyph: 12, tone: .idle)
        }
        .frame(minHeight: 28)
    }

    private var badgeTone: LuckyTone {
        if row.paused { return .warning }
        if row.running { return .ok }
        return .idle
    }

    /// Compact status pill: 5 pt dot + uptime phrase, tinted by running / paused / stopped state.
    private var badge: some View {
        let tone = badgeTone
        return HStack(spacing: 4) {
            Circle()
                .fill(tone.tint)
                .frame(width: 5, height: 5)
            Text(row.status)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(tone == .idle ? LuckyTheme.textSecondary : tone.tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .frame(minHeight: 16)
        .background(tone == .idle ? LuckyTheme.surfaceRaised : tone.fill,
                    in: .rect(cornerRadius: 5))
    }

    /// Three buttons, the first of which depends on the state. 恢复 and 启动 ask nothing; 停止 and
    /// 重启 both confirm, and both interpolate the **raw** name, leading slash and all.
    private var commands: some View {
        commandLayout {
            if row.paused {
                ContainerCommandButton(symbol: LuckySymbol.start, label: "恢复",
                                       tint: LuckyTheme.success, disabled: busy) {
                    actions.unpause(row.key)
                }
            } else if !row.running {
                ContainerCommandButton(symbol: LuckySymbol.start, label: "启动",
                                       tint: LuckyTheme.success, disabled: busy) {
                    actions.start(row.key)
                }
            } else {
                ContainerCommandButton(symbol: LuckySymbol.stop, label: "停止",
                                       tint: LuckyTheme.danger, disabled: busy) {
                    actions.stop(row.key, row.name)
                }
            }
            ContainerCommandButton(symbol: LuckySymbol.restart, label: "重启",
                                   tint: LuckyTheme.accent, disabled: busy) {
                actions.restart(row.key, row.name)
            }
            ContainerCommandButton(symbol: "icloud.and.arrow.up", label: "更新",
                                   tint: LuckyTheme.info, disabled: busy) {
                actions.update(row.key, row.displayName)
            }
        }
    }

    private var commandLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 5))
    }
}

#if DEBUG
private struct DockerContainerCardPreviews: PreviewProvider {
    private static let row = DockerContainerRow(.object([
        ("Id", .string("preview-postgres")), ("Names", .array([.string("/ai-proxy-postgres")])),
        ("State", .string("running")), ("Status", .string("Up 10 days")),
    ]), 0)

    private static let stats = DockerStatRow(
        key: "preview-postgres", name: "ai-proxy-postgres", cpu: 0.6, hasCpu: true,
        memoryPercent: 0.2, hasMemoryPercent: true,
        networkRx: 1_020_000_000, hasNetworkRx: true, networkTx: 24_470_000_000, hasNetworkTx: true,
        blockRead: 294_560_000, hasBlockRead: true, blockWrite: 9_310_000_000, hasBlockWrite: true
    )

    private static var card: some View {
        LuckyPage {
            DockerContainerCard(row: row, stat: stats, busy: false, actions: DockerContainerActions(
                menu: { _ in }, unpause: { _ in }, start: { _ in },
                stop: { _, _ in }, restart: { _, _ in }, update: { _, _ in }
            ))
        }
    }

    static var previews: some View {
        Group {
            card.previewLayout(.fixed(width: 393, height: 420)).previewDisplayName("容器 · 三列两行")
            card.previewLayout(.fixed(width: 320, height: 420)).previewDisplayName("容器 · 窄屏")
            card.preferredColorScheme(.dark).previewDisplayName("容器 · 深色")
            card.dynamicTypeSize(.xxxLarge).previewDisplayName("容器 · 大字体")
        }
    }
}
#endif
