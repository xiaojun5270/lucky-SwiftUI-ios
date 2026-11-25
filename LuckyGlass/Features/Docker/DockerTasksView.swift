import SwiftUI

/// §15 — 后台任务. The shortest list: what the task is, how it is doing, and two verbs.
struct DockerTasksView: View {
    var items: [LuckyListItem]
    var loading: Bool
    var busy: Bool
    var refresh: @Sendable () async -> Void
    var inspect: (String) -> Void
    var remove: (String) -> Void

    var body: some View {
        DockerListPane(count: items.count, loading: loading,
                       empty: DockerView.tasks.emptyMessage,
                       symbol: DockerView.tasks.symbol,
                       loadingText: "正在读取后台任务",
                       spacing: LuckyTheme.Space.stack / 2, refresh: refresh) {
            EmptyView()
        } rows: {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                DockerTaskCard(item: item, index: index, busy: busy,
                               inspect: inspect, remove: remove)
            }
        }
    }
}

private struct DockerTaskCard: View {
    var item: LuckyListItem
    var index: Int
    var busy: Bool
    var inspect: (String) -> Void
    var remove: (String) -> Void

    private var key: String { DockerRecord.keyOf(item, index) }

    /// `pick(item, ["Name","Type","Action"], keyOf(item,index))`.
    private var title: String {
        DockerRecord.pick(item, ["Name", "Type", "Action"], key)
    }

    /// `pick(item, ["Status","state","Progress"])` — the lowercase `state` in the middle of an
    /// otherwise capitalised list is the original's, and the task endpoints really do disagree.
    private var status: String {
        DockerRecord.pick(item, ["Status", "state", "Progress"])
    }

    var body: some View {
        LuckyCard(padding: 0) {
            VStack(alignment: .leading, spacing: LuckyTheme.Space.m / 2) {
                HStack(spacing: LuckyTheme.Space.s + 2) {
                    LuckyIconTile(symbol: DockerView.tasks.symbol, size: 36, glyph: 18,
                                  role: DockerView.tasks.iconRole)
                    VStack(alignment: .leading, spacing: LuckyTheme.Space.hair) {
                        Text(title)
                            .font(LuckyTheme.Text.cardTitle)
                            .foregroundStyle(LuckyTheme.textPrimary)
                            .lineLimit(2)
                        if !status.isEmpty {
                            Text(status)
                                .font(.system(size: 11))
                                .foregroundStyle(LuckyTheme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                LuckyHairline()
                HStack(spacing: LuckyTheme.Space.s) {
                    DockerIconButton(symbol: LuckySymbol.search, label: "详情",
                                     tint: LuckyTheme.textPrimary, disabled: busy, fluid: true) {
                        inspect(key)
                    }
                    // The one delete in the whole screen that does not confirm: a task record is a log
                    // line, and removing it destroys nothing the daemon still holds.
                    DockerIconButton(symbol: LuckySymbol.delete, label: "删除",
                                     tint: LuckyTheme.danger, disabled: busy, fluid: true) {
                        remove(key)
                    }
                }
            }
            .padding(.horizontal, LuckyTheme.Space.cardInset)
            .padding(.vertical, LuckyTheme.Space.cardInset / 2)
        }
    }
}
