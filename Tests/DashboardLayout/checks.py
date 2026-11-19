"""Dashboard-only source contracts; run Xcode/UI previews separately on macOS."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
DASHBOARD = ROOT / "LuckyGlass/Features/Dashboard/DashboardScreen.swift"


class DashboardLayoutChecks(unittest.TestCase):
    def test_card_icons_have_consistent_semantic_plates(self):
        text = DASHBOARD.read_text()
        self.assertIn("private struct DashboardSectionHeader<Trailing: View>: View", text)
        self.assertIn("LuckyIconTile(symbol: symbol, size: 32, glyph: 16, role: iconRole)", text)
        for title in ["快捷入口", "系统资源", "网络趋势", "服务器信息"]:
            self.assertIn(f'DashboardSectionHeader(title: "{title}"', text)
        self.assertIn('LuckyIconTile(symbol: LuckySymbol.monitor, size: 32, glyph: 16, role: .system)', text)
        self.assertIn('LuckyIconTile(symbol: "network", size: 32, glyph: 16, role: .web)', text)
        self.assertIn('LuckyIconTile(symbol: symbol, size: 40, glyph: 19, role: iconRole)', text)
        for title, symbol in [("反向代理", "network"), ("Docker", "cube.transparent"),
                              ("动态域名", "globe.asia.australia"), ("SSL 证书", "lock.shield")]:
            self.assertIn(f'DashboardQuickLink(title: "{title}", symbol: "{symbol}"', text)
        self.assertNotIn("LuckySectionHeader(", text)
        self.assertIn(".accessibilityAddTraits(.isHeader)", text)

    def test_compact_controls_keep_accessibility_and_account_switching(self):
        text = DASHBOARD.read_text()
        quick = text.split("private struct DashboardQuickLink: View", 1)[1].split("private struct DashboardShortcuts", 1)[0]
        self.assertIn("VStack(spacing: 6)", quick)
        self.assertIn(".frame(minWidth: LuckyTheme.Space.touchTarget, maxWidth: .infinity, minHeight: 64)", quick)
        self.assertIn(".fixedSize(horizontal: false, vertical: true)", quick)
        self.assertIn("height: 40)", text.split("private var metricDivider", 1)[1])
        self.assertIn(".frame(minHeight: 56)", text)
        self.assertIn("count: dynamicTypeSize >= .xxLarge ? 2 : 4", text)
        self.assertIn("? AnyLayout(VStackLayout(spacing: LuckyTheme.Space.xl))", text)
        self.assertIn("? AnyLayout(VStackLayout(spacing: LuckyTheme.Space.m))", text)
        self.assertNotIn(".dynamicTypeSize(...", text)
        self.assertIn("subtitleAction: { showingAccounts = true }", text)
        self.assertIn("DashboardAccountPicker()", text)
        self.assertIn("await session.switchTo(profileID: profile.id)", text)
        self.assertIn(".frame(minHeight: 44)", text)
        self.assertIn(".frame(width: 52, height: 52)", text)
        self.assertIn("LuckyToolbarButton(", text)

    def test_compact_rhythm_is_scoped_to_dashboard(self):
        text = DASHBOARD.read_text()
        self.assertRegex(text, r"private enum DashboardLayout\s*\{")
        for name, value in {"cardGap": 12, "cardInset": 12, "contentGap": 10}.items():
            self.assertRegex(text, rf"static let {name}: CGFloat = {value}\b")
        self.assertEqual(text.count("LuckyPage(spacing: DashboardLayout.cardGap"), 2,
                         "Production and preview must share the compact rhythm")
        self.assertEqual(text.count("LuckyCard(padding: DashboardLayout.cardInset, spacing: DashboardLayout.contentGap)"), 5)
        self.assertIn("HStack(alignment: .top, spacing: DashboardLayout.cardGap)", text)
        self.assertIn(".padding(.vertical, LuckyTheme.Space.s)", text)
        self.assertNotIn(".padding(LuckyTheme.Space.cardInset)", text)
        # Compact dashboard must not shrink every other screen's spacing.
        theme = (ROOT / "LuckyGlass/Design/LuckyTheme.swift").read_text()
        for name, value in {"cardInset": 20, "section": 24, "touchTarget": 44}.items():
            self.assertRegex(theme, rf"static let {name}: CGFloat = {value}\b")


if __name__ == "__main__":
    unittest.main()
