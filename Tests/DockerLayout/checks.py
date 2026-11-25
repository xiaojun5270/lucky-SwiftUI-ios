"""Container-only compact layout & 50% metric/font compaction contracts; Xcode rendering is verified on macOS CI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
DOCKER = ROOT / "LuckyGlass/Features/Docker"


class DockerLayoutChecks(unittest.TestCase):
    def test_container_card_and_parent_vertical_spacing_is_compacted(self):
        text = (DOCKER / "DockerContainersView.swift").read_text()
        self.assertIn("spacing: 6, refresh: refresh", text)
        card = text.split("private struct DockerContainerCard: View", 1)[1].split("#if DEBUG", 1)[0]
        self.assertIn("LuckyCard(radius: 14, padding: 0)", card)
        self.assertIn("VStack(alignment: .leading, spacing: LuckyTheme.Space.xs)", card)
        self.assertIn(".padding(.horizontal, LuckyTheme.Space.cardInset / 2)", card)
        self.assertIn(".padding(.vertical, 6)", card)
        self.assertIn("AnyLayout(VStackLayout(spacing: 4))", card)
        self.assertIn("AnyLayout(HStackLayout(spacing: 5))", card)
        # Compact 50%-shrunk container card header, icon, status badge and typography.
        for compact_token in [
            "HStack(spacing: 7)",
            "size: 28)",
            ".frame(minHeight: 28)",
            ".font(.system(size: 12, weight: .bold))",
            ".font(.system(size: 8.5, weight: .semibold))",
            ".frame(minHeight: 16)",
        ]:
            self.assertIn(compact_token, card)
        self.assertIn("LuckyHairline()", card)
        self.assertNotIn(".scaleEffect(", card)

    def test_shared_defaults_and_other_screens_keep_their_spacing(self):
        controls = (DOCKER / "DockerControls.swift").read_text()
        pane = controls.split("struct DockerListPane<", 1)[1].split("struct DockerCountChip", 1)[0]
        self.assertIn("var spacing: CGFloat = LuckyTheme.Space.stack", pane)
        self.assertIn("LazyVStack(alignment: .leading, spacing: spacing)", pane)
        theme = (ROOT / "LuckyGlass/Design/LuckyTheme.swift").read_text()
        for name, value in {"xs": 4, "s": 8, "m": 12, "stack": 16,
                            "cardInset": 20, "touchTarget": 44}.items():
            self.assertRegex(theme, rf"static let {name}: CGFloat = {value}\b")
        surface = (ROOT / "LuckyGlass/Design/LuckySurface.swift").read_text()
        self.assertIn("var padding: CGFloat = LuckyTheme.Space.cardInset", surface)
        self.assertIn(".padding(padding)", surface)

    def test_stats_and_actions_keep_dynamic_type_and_accessibility(self):
        controls = (DOCKER / "DockerControls.swift").read_text()
        grid = controls.split("struct ContainerStatsGrid: View", 1)[1].split("// MARK: - 行内按钮", 1)[0]
        self.assertIn("if dynamicTypeSize.isAccessibilitySize { return 1 }", grid)
        self.assertIn("return dynamicTypeSize >= .xxLarge ? 2 : 3", grid)
        self.assertIn("GridItem(.flexible(), spacing: LuckyTheme.Space.xs)", grid)
        self.assertIn("count: columnCount), spacing: 3)", grid)
        self.assertIn("HStack(spacing: 3)", grid)
        self.assertIn(".padding(.horizontal, 6)", grid)
        self.assertIn(".padding(.vertical, 4)", grid)
        self.assertNotIn("minHeight: 72", grid, "Fixed cell floor must not swallow the reduced padding")
        for compact_metric in [
            ".font(.system(size: 8.5, weight: .semibold))",
            ".font(.system(size: 9, weight: .medium))",
            ".font(.system(size: 10, weight: .semibold, design: .rounded))",
            ".accessibilityElement(children: .combine)",
        ]:
            self.assertIn(compact_metric, grid)
        commands = controls.split("struct ContainerCommandButton: View", 1)[1].split("// MARK: - 面板滚动", 1)[0]
        self.assertIn(".frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 38 : 28)", commands)
        self.assertIn(".font(.system(size: 10.5, weight: .semibold))", commands)


if __name__ == "__main__":
    unittest.main()
