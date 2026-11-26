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
    var fill: Color = LuckyTheme.surfaceSunken

    private static let bottomAnchor = "lucky.log.bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    rows(query.jsTrimmed)
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .padding(.horizontal, LuckyTheme.Space.m)
                .padding(.vertical, LuckyTheme.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(height: height)
            .background(ConcentricRectangle().fill(fill))
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
        let tone = Self.tone(line)
        renderedText(tone: tone)
            .font(LuckyTheme.Text.code)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, tone != nil ? 10 : 2)
            .padding(.trailing, tone != nil ? 6 : 2)
            .padding(.vertical, tone != nil ? 3 : 1)
            .background {
                if let tone {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(tone.tint.opacity(0.09))
                }
            }
            .overlay(alignment: .leading) {
                if let tone {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(tone.tint)
                        .frame(width: 2.5)
                        .padding(.vertical, 3)
                        .padding(.leading, 2.5)
                }
            }
    }

    @ViewBuilder
    private func renderedText(tone: LuckyTone?) -> some View {
        let baseColor = tone?.tint ?? LuckyTheme.textPrimary
        if needle.isEmpty, let split = Self.splitLeadingTimestamp(line) {
            Text(attributedWithTimestamp(prefix: split.prefix, body: split.body, bodyColor: baseColor))
        } else if needle.isEmpty {
            Text(verbatim: line)
                .foregroundStyle(baseColor)
        } else {
            Text(attributed(line, needle: needle, baseColor: baseColor))
        }
    }

    /// Only failures and warnings are tinted. Colouring every line by level turns a busy log into
    /// confetti, and Lucky's own logs are mostly untagged Chinese sentences.
    private static func tone(_ line: String) -> LuckyTone? {
        LuckyLogSeverity.detect(line).tone
    }

    /// Zero-regex detector for leading Lucky timestamps like `[2026-11-26 12:34:56]` or `2026/11/26 12:34:56`.
    private static func splitLeadingTimestamp(_ line: String) -> (prefix: Substring, body: Substring)? {
        guard line.count >= 19 else { return nil }
        let start = line.startIndex
        if line[start] == "[" {
            guard let close = line.prefix(32).firstIndex(of: "]") else { return nil }
            let inner = line[line.index(after: start)..<close]
            guard inner.count >= 10, inner.first?.isNumber == true else { return nil }
            let next = line.index(after: close)
            guard next < line.endIndex else { return nil }
            return (line[start...close], line[next...])
        }
        let head = line.prefix(19)
        let bytes = Array(head.utf8)
        guard bytes.count == 19,
              bytes[0] >= 48 && bytes[0] <= 57,
              bytes[4] == 45 || bytes[4] == 47,
              bytes[7] == 45 || bytes[7] == 47,
              bytes[10] == 32 || bytes[10] == 84,
              bytes[13] == 58, bytes[16] == 58 else { return nil }
        let splitIdx = line.index(start, offsetBy: 19)
        return (line[start..<splitIdx], line[splitIdx...])
    }

    private func attributedWithTimestamp(prefix: Substring, body: Substring, bodyColor: Color) -> AttributedString {
        var head = AttributedString(prefix)
        head.foregroundColor = LuckyTheme.textTertiary
        var tail = AttributedString(body)
        tail.foregroundColor = bodyColor
        head.append(tail)
        return head
    }

    /// Marks every occurrence of the query. `AttributedString` is built per visible line only, and
    /// only when there is something to mark.
    private func attributed(_ line: String, needle: String, baseColor: Color) -> AttributedString {
        var text = AttributedString(line)
        text.foregroundColor = baseColor
        if let split = Self.splitLeadingTimestamp(line),
           let range = text.range(of: String(split.prefix)) {
            text[range].foregroundColor = LuckyTheme.textTertiary
        }
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
