import SwiftUI

/// §13 — Docker 网络. The plainest of the six lists: one glyph, two lines and a single verb.
struct DockerNetworksView: View {
    var items: [LuckyListItem]
    var loading: Bool
    var busy: Bool
    var refresh: @Sendable () async -> Void
    /// `(key, name)` — the mutation is keyed by `keyOf`, the confirmation quotes the name.
    var remove: (String, String) -> Void

    private struct NetworkRowEntry: Identifiable {
        var id: String
        var item: LuckyListItem
        var index: Int
    }

    private var rowEntries: [NetworkRowEntry] {
        var seen = Set<String>()
        seen.reserveCapacity(items.count)
        return items.enumerated().map { index, item in
            let base = DockerRecord.keyOf(item, index)
            var id = base
            var suffix = 1
            while !seen.insert(id).inserted {
                id = "\(base)#\(suffix)"
                suffix += 1
            }
            return NetworkRowEntry(id: id, item: item, index: index)
        }
    }

    var body: some View {
        DockerListPane(count: items.count, loading: loading,
                       empty: DockerView.networks.emptyMessage,
                       symbol: DockerView.networks.symbol,
                       loadingText: "正在读取 Docker 网络",
                       spacing: 6, refresh: refresh) {
            EmptyView()
        } rows: {
            ForEach(rowEntries) { entry in
                DockerNetworkCard(item: entry.item, index: entry.index, busy: busy, remove: remove)
            }
        }
    }
}

private struct DockerNetworkCard: View {
    var item: LuckyListItem
    var index: Int
    var busy: Bool
    var remove: (String, String) -> Void

    private var key: String { DockerRecord.keyOf(item, index) }

    private var name: String { DockerRecord.pick(item, ["Name", "name"], key) }

    /// `${pick(item,["Driver"])} · ${pick(item,["Scope"])}` — both fall back to `""`, so a network
    /// that reports neither renders a bare separator. Kept verbatim: the row is still identifiable
    /// by its name, and inventing a placeholder would be inventing data.
    private var subtitle: String {
        "\(DockerRecord.pick(item, ["Driver"])) · \(DockerRecord.pick(item, ["Scope"]))"
    }

    var body: some View {
        LuckyCard(radius: 14, padding: 0) {
            HStack(spacing: 8) {
                LuckyIconTile(symbol: DockerView.networks.symbol, size: 30, glyph: 15,
                              role: DockerView.networks.iconRole)
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
                // The one non-`fluid` button in the port: it hugs its label and lets the name have
                // the rest of the row.
                DockerIconButton(symbol: LuckySymbol.delete, label: "删除",
                                 tint: LuckyTheme.danger, disabled: busy) {
                    remove(key, name)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
