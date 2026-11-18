import SwiftUI

/// A chip described by data rather than by a view, so a row built in a `ForEach` over server
/// records can declare its chips inline.
struct LuckyChipSpec: Identifiable, Hashable {
    var text: String
    var tone: LuckyTone
    var symbol: String?

    var id: String { "\(text)-\(tone.rawValue)-\(symbol ?? "")" }

    init(_ text: String, tone: LuckyTone = .idle, symbol: String? = nil) {
        self.text = text
        self.tone = tone
        self.symbol = symbol
    }
}

/// The workhorse row: reverse-proxy rules, DDNS tasks, certificates, containers, endpoints. Wrap it
/// in a `NavigationLink` (with `.buttonStyle(.plain)`) or a `Button`; it draws itself as a card so
/// a list is a stack of plates rather than a `List`, which is what lets the port keep glass off the
/// scrolling layer.
struct LuckyListRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    /// Monospaced supporting line — a path, an address, a container id.
    var detail: String?
    var symbol: String?
    var tone: LuckyTone? = nil
    var iconRole: LuckyIconRole? = nil
    var chips: [LuckyChipSpec] = []
    var dot: LuckyTone?
    var showsChevron: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        LuckyCard(spacing: LuckyTheme.Space.s) {
            HStack(alignment: .center, spacing: LuckyTheme.Space.m) {
                if let symbol {
                    LuckyIconTile(symbol: symbol, size: 36, glyph: 16, tone: tone, role: iconRole)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: LuckyTheme.Space.xs) {
                        if let dot { LuckyStatusDot(tone: dot) }
                        Text(title)
                            .font(LuckyTheme.Text.cardTitle)
                            .foregroundStyle(LuckyTheme.textPrimary)
                            .lineLimit(1)
                    }
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(LuckyTheme.Text.caption)
                            .foregroundStyle(LuckyTheme.textSecondary)
                            .lineLimit(2)
                    }
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(LuckyTheme.Text.codeSmall)
                            .foregroundStyle(LuckyTheme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
                trailing()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .frame(width: 20, height: 24)
                }
            }
            if !chips.isEmpty {
                LuckyWrap(spacing: 6, lineSpacing: 6) {
                    ForEach(chips) { chip in
                        LuckyChip(text: chip.text, tone: chip.tone, symbol: chip.symbol)
                    }
                }
            }
        }
        .contentShape(.rect(cornerRadius: LuckyTheme.Radius.card))
    }
}

extension LuckyListRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, detail: String? = nil, symbol: String? = nil,
         tone: LuckyTone? = nil, iconRole: LuckyIconRole? = nil,
         chips: [LuckyChipSpec] = [], dot: LuckyTone? = nil,
         showsChevron: Bool = true) {
        self.init(title: title, subtitle: subtitle, detail: detail, symbol: symbol, tone: tone,
                  iconRole: iconRole, chips: chips, dot: dot,
                  showsChevron: showsChevron) { EmptyView() }
    }
}
