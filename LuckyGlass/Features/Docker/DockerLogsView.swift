import SwiftUI

/// §18 — Docker 日志, which is two views wearing one tab.
///
/// Mode A appears whenever a container-log, compose-log or file-listing read has just landed in
/// `output`: the payload takes over the tab and the pager disappears, because what is on screen is
/// no longer the daemon's log. Leaving the tab, or coming back to it, clears `output` and Mode B
/// returns — that is `selectDockerView`'s `setOutput("")`, not anything this view does.
struct DockerLogsView: View {
    /// `output` — non-nil is Mode A.
    var output: JSONValue?
    /// `dockerLogLines` — Mode B's 200-line page.
    var lines: [String]
    var loading: Bool
    var refresh: @Sendable () async -> Void

    var body: some View {
        if let output {
            payload(output)
        } else {
            page
        }
    }

    /// §18.1. A scroll rather than a list, and no pager: one payload, however deep it is.
    private func payload(_ value: JSONValue) -> some View {
        DockerPaneScroll(refresh: refresh) {
            if case .string(let text) = value,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
                let split = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
                LuckyCard(padding: 0, spacing: 0) {
                    LuckyLogView(lines: split, follows: false, height: 520, fill: LuckyTheme.surface)
                }
            } else {
                LuckyCard(spacing: LuckyTheme.Space.m) {
                    StructuredDataView(value: value)
                }
            }
        }
    }

    /// §18.2. Renders daemon logs inside a rounded elevated card plate with severity tinting.
    private var page: some View {
        DockerListPane(count: lines.count, loading: loading,
                       empty: DockerView.logs.emptyMessage,
                       symbol: DockerView.logs.symbol,
                       loadingText: "正在读取 Docker 日志", spacing: 0, refresh: refresh) {
            EmptyView()
        } rows: {
            LuckyCard(padding: 0, spacing: 0) {
                ForEach(lines.indices, id: \.self) { index in
                    DockerLogRow(line: lines[index], first: index == 0)
                }
            }
        }
    }
}

/// One daemon log line with severity tinting and legible 12pt monospace typography.
private struct DockerLogRow: View {
    var line: String
    var first: Bool

    var body: some View {
        let tone = LuckyLogSeverity.detect(line).tone
        VStack(alignment: .leading, spacing: 0) {
            if !first { LuckyHairline() }
            Text(verbatim: line)
                .font(LuckyTheme.Text.code)
                .foregroundStyle(tone?.tint ?? LuckyTheme.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, LuckyTheme.Space.m)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tone.map { $0.tint.opacity(0.08) } ?? Color.clear)
        }
    }
}
