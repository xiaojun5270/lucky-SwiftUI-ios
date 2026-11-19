import SwiftUI

/// The page scaffold every screen is built on: ambient backdrop, one scroll view, page margins, and
/// the soft scroll edge effect that lets content fade under the glass navigation bar.
///
/// Screens supply only their cards. Nothing here is glass — the glass in a page comes from the
/// system chrome (nav bar, tab bar) and from whatever the screen puts in a `safeAreaBar`.
struct LuckyPage<Content: View>: View {
    var spacing: CGFloat = LuckyTheme.Space.stack
    var maxWidth: CGFloat = LuckyTheme.Layout.contentWidth
    /// Pull-to-refresh. Most screens have a refresh action; the login screen does not.
    var refresh: (@Sendable () async -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            LuckyBackdrop()
            scroll
        }
    }

    @ViewBuilder
    private var scroll: some View {
        if let refresh {
            base.refreshable { await refresh() }
        } else {
            base
        }
    }

    private var base: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing, content: content)
                .padding(.horizontal, LuckyTheme.Space.gutter)
                .padding(.top, LuckyTheme.Space.pageTop)
                .padding(.bottom, LuckyTheme.Space.pageBottom)
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        }
        // Soft at the top so cards dissolve under the title; hard at the bottom so a list does not
        // smear into the tab bar while scrolling.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }
}

/// A consistent page identity for the four primary tabs. The vertical alternative preserves
/// space for the title and controls at accessibility text sizes and narrow split-view widths.
struct LuckyScreenHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    var subtitleAction: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: LuckyTheme.Space.l) {
                heading
                Spacer(minLength: LuckyTheme.Space.m)
                trailing()
            }
            VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
                heading
                trailing()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, LuckyTheme.Space.xs)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
            Text(title)
                .font(LuckyTheme.Text.hero)
                .foregroundStyle(LuckyTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitleAction {
                Button(action: subtitleAction) {
                    HStack(spacing: LuckyTheme.Space.s) {
                        Text(subtitle)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.down")
                            .font(LuckyTheme.Text.captionMedium)
                            .accessibilityHidden(true)
                    }
                    .font(LuckyTheme.Text.body)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .frame(minHeight: LuckyTheme.Space.touchTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("切换账号，\(subtitle)")
                .accessibilityHint("查看已保存的账号或添加账号")
                .accessibilityIdentifier("dashboard.accountSwitcher")
            } else {
                Text(subtitle)
                    .font(LuckyTheme.Text.body)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension LuckyScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Quiet utility controls used in page headers and list toolbars.
struct LuckyToolbarButton: View {
    var symbol: String
    var label: String
    var tone: LuckyTone = .idle
    var loading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundStyle(tone.tint)
            .frame(width: LuckyTheme.Space.touchTarget, height: LuckyTheme.Space.touchTarget)
            .background(LuckyTheme.surface, in: .circle)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .accessibilityLabel(label)
    }
}

/// The hero block at the top of the dashboard: the server it is talking to, its version, and
/// whether the status socket is live. Deliberately not a card — it reads as part of the page, and
/// the nav bar's glass passes over it.
struct LuckyPageHero<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var detail: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: LuckyTheme.Space.m) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(LuckyTheme.Text.hero)
                    .foregroundStyle(LuckyTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(LuckyTheme.Text.body)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .lineLimit(2)
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(LuckyTheme.Text.codeSmall)
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.bottom, LuckyTheme.Space.xs)
    }
}

extension LuckyPageHero where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, detail: String? = nil) {
        self.init(title: title, subtitle: subtitle, detail: detail) { EmptyView() }
    }
}

extension View {
    /// `<Page title subtitle>` from `src/components/lucky-ui.tsx`, which draws an icon tile, a
    /// 26pt title and a caption at the top of the scroll view. Here the pair goes to the real
    /// navigation bar — iOS 26's `navigationSubtitle` is exactly this shape — so the title
    /// collapses on scroll and the glass bar refracts the cards passing under it.
    func luckyTitle(_ title: String, _ subtitle: String? = nil) -> some View {
        navigationTitle(title)
            .navigationSubtitle(subtitle ?? "")
    }

    /// The bottom action bar used by the editors and the debugger. `safeAreaBar` rather than
    /// `safeAreaInset` because only the former extends the scroll view's edge effect under the bar.
    func luckyActionBar<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        safeAreaBar(edge: .bottom) {
            LuckyGlassBar(content: content)
        }
    }
}

/// A grid of equal-width tiles that stays readable from an iPhone SE to a Max. Used for the
/// dashboard metrics and the Docker state summary, both of which are fixed-length — hence
/// `LazyVGrid` only for the column maths, not for lazy loading.
struct LuckyTileGrid<Content: View>: View {
    var minimum: CGFloat = 150
    var spacing: CGFloat = LuckyTheme.Space.s
    @ViewBuilder var content: () -> Content

    var body: some View {
        let column = GridItem(.adaptive(minimum: minimum), spacing: spacing, alignment: .topLeading)
        LazyVGrid(columns: [column], alignment: .leading, spacing: spacing, content: content)
    }
}
