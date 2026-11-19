"""Container-only 50% spacing contracts; Xcode rendering is verified on macOS CI."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
DOCKER = ROOT / "LuckyGlass/Features/Docker"


class DockerLayoutChecks(unittest.TestCase):
    def test_container_card_and_parent_vertical_spacing_is_halved(self):
        text = (DOCKER / "DockerContainersView.swift").read_text()
        self.assertIn("spacing: LuckyTheme.Space.stack / 2, refresh: refresh", text)
        card = text.split("private struct DockerContainerCard: View", 1)[1].split("#if DEBUG", 1)[0]
        self.assertIn("LuckyCard(padding: 0)", card)
        self.assertIn("VStack(alignment: .leading, spacing: LuckyTheme.Space.m / 2)", card)
        self.assertIn(".padding(.horizontal, LuckyTheme.Space.cardInset)", card)
        self.assertIn(".padding(.vertical, LuckyTheme.Space.cardInset / 2)", card)
        self.assertIn("spacing: (LuckyTheme.Space.xs + 2) / 2", card)
        self.assertIn("AnyLayout(VStackLayout(spacing: LuckyTheme.Space.s / 2))", card)
        # Horizontal geometry and tap targets are not density knobs.
        for original in ["HStack(spacing: 11)", "size: 48)", ".frame(minHeight: 54)",
                         "AnyLayout(HStackLayout(spacing: LuckyTheme.Space.s))",
                         ".font(.system(size: 15, weight: .heavy))",
                         ".font(.system(size: 10, weight: .semibold))"]:
            self.assertIn(original, card)
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
        self.assertIn("count: columnCount), spacing: LuckyTheme.Space.s / 2)", grid)
        self.assertIn("GridItem(.flexible(), spacing: LuckyTheme.Space.s)", grid)
        self.assertIn("VStack(spacing: LuckyTheme.Space.s / 2)", grid)
        self.assertIn(".padding(.vertical, LuckyTheme.Space.m / 2)", grid)
        self.assertIn(".padding(.horizontal, LuckyTheme.Space.s)", grid)
        self.assertNotIn("minHeight: 72", grid, "Fixed cell floor must not swallow the reduced padding")
        for original in [".font(LuckyTheme.Text.captionMedium)", ".font(LuckyTheme.Text.caption)",
                         ".font(LuckyTheme.Text.bodyMedium.weight(.semibold))",
                         ".accessibilityElement(children: .combine)"]:
            self.assertIn(original, grid)
        commands = controls.split("struct ContainerCommandButton: View", 1)[1].split("// MARK: - 面板滚动", 1)[0]
        self.assertIn(".frame(minHeight: LuckyTheme.Space.touchTarget)", commands)
        self.assertNotRegex(commands, r"touchTarget\s*/")


if __name__ == "__main__":
    unittest.main()
