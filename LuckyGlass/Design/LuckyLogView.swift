import SwiftUI

/// The severity vocabulary shared by log tinting and the global log filter.
enum LuckyLogSeverity: Hashable {
    case standard, warning, error

    static func detect(_ line: String) -> Self {
        // Level tags sit at the head of the line. Limiting the scan keeps large unstructured
        // payloads from being searched in full whenever a visible row is redrawn.
        let head = line.prefix(72).lowercased()
        if head.contains("error") || head.contains("fatal") || head.contains("panic")
            || head.contains("失败") || head.contains("错误") { return .error }
        if head.contains("warn") || head.contains("警告") { return .warning }
        return .standard
    }

    var tone: LuckyTone? {
        switch self {
        case .standard: nil
        case .warning: .warning
        case .error: .danger
        }
    }
}

/// The log viewer shared by the global log screen, the per-service log screens and the container
/// log screen. It takes the already-extracted lines from `LuckyLog` — nothing here parses a
/// payload.
///
/// `LazyVStack` inside a `ScrollView` rather than a `List`: a tail of 5,000 lines has to stay
/// smooth, and list rows would each build a background this view does not want.
struct LuckyLogView: View {
    var lines: [String]
    /// Highlighted, not filtered — the screens filter upstream so the counts they show stay honest.
    var query: String = ""
    /// Pins to the newest line as it arrives. The screens expose it as 自动滚动.
    var follows: Bool = true
    /// `nil` fills whatever space the parent offers — the global log tab is a non-scrolling page
    /// whose list must reach the tab bar.
    var height: CGFloat? = 380
    /// Draws from the tail without allocating a reversed copy of the full log buffer.
    var newestFirst: Bool = false

    private static let bottomAnchor = "lucky.log.bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    rows(query.jsTrimmed)
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .padding(LuckyTheme.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(height: height)
            .background(ConcentricRectangle().fill(LuckyTheme.surfaceSunken))
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: lines.count) {
                guard follows else { return }
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func rows(_ needle: String) -> some View {
        if newestFirst {
            ForEach(lines.indices.reversed(), id: \.self) { index in
                LuckyLogLine(line: lines[index], needle: needle).equatable()
            }
        } else {
            ForEach(lines.indices, id: \.self) { index in
                LuckyLogLine(line: lines[index], needle: needle).equatable()
            }
        }
    }

}

/// Unchanged rows skip level parsing and highlight construction when the polling controls update.
private struct LuckyLogLine: View, Equatable {
    var line: String
    var needle: String

    var body: some View {
        if needle.isEmpty {
            Text(verbatim: line)
                .font(LuckyTheme.Text.codeSmall)
                .foregroundStyle(Self.tone(line)?.tint ?? LuckyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(attributed(line, needle: needle))
                .font(LuckyTheme.Text.codeSmall)
                .foregroundStyle(Self.tone(line)?.tint ?? LuckyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Only failures and warnings are tinted. Colouring every line by level turns a busy log into
    /// confetti, and Lucky's own logs are mostly untagged Chinese sentences.
    private static func tone(_ line: String) -> LuckyTone? {
        LuckyLogSeverity.detect(line).tone
    }

    /// Marks every occurrence of the query. `AttributedString` is built per visible line only, and
    /// only when there is something to mark.
    private func attributed(_ line: String, needle: String) -> AttributedString {
        var text = AttributedString(line)
        var cursor = text.startIndex
        while cursor < text.endIndex,
              let found = text[cursor...].range(of: needle, options: .caseInsensitive) {
            text[found].backgroundColor = LuckyTheme.accent.opacity(0.28)
            text[found].foregroundColor = LuckyTheme.textPrimary
            cursor = found.upperBound
        }
        return text
    }
}
