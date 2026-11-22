"""Source-level verification for UI refinements: icons, tactile feedback, compose/volume menu hierarchies, and settings shortcuts."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(path: str) -> str:
    return (ROOT / "LuckyGlass" / path).read_text()


class UIRefinementsChecks(unittest.TestCase):
    def test_services_icons_are_unified_with_dashboard(self):
        services = source("Features/Services/ServicesScreen.swift")
        self.assertIn("symbol: LuckySymbol.kind(.webservice), role: .web", services)
        self.assertIn("symbol: LuckySymbol.kind(.docker), role: .docker", services)
        self.assertIn("symbol: LuckySymbol.kind(.ddns), role: .ddns", services)
        self.assertIn("symbol: LuckySymbol.kind(.ssl), role: .security", services)

    def test_frp_icon_does_not_collide_with_ddns_globe(self):
        iconography = source("Design/LuckyIconography.swift")
        self.assertIn('case .frp: "point.3.connected.trianglepath.dotted"', iconography)
        self.assertNotIn('case .frp: "globe.asia.australia"', iconography)

    def test_tactile_press_style_and_haptics_exist_and_wired(self):
        surface = source("Design/LuckySurface.swift")
        self.assertIn("struct LuckyPressStyle: ButtonStyle", surface)
        feedback = source("Design/LuckyFeedback.swift")
        self.assertIn("enum LuckyHaptic", feedback)

        # Check wiring in key components
        services = source("Features/Services/ServicesScreen.swift")
        self.assertIn(".buttonStyle(LuckyPressStyle())", services)
        self.assertIn("LuckyHaptic.selection()", services)

        docker_ctrl = source("Features/Docker/DockerControls.swift")
        self.assertIn(".buttonStyle(LuckyPressStyle(pressedScale: 0.97, pressedOpacity: 0.75))", docker_ctrl)
        self.assertIn("LuckyHaptic.light()", docker_ctrl)

        dashboard = source("Features/Dashboard/DashboardScreen.swift")
        self.assertIn(".buttonStyle(LuckyPressStyle(pressedScale: 0.96, pressedOpacity: 0.72))", dashboard)
        self.assertIn("LuckyHaptic.selection()", dashboard)

        toolbar = source("Design/LuckyPage.swift")
        self.assertIn(".buttonStyle(LuckyPressStyle(pressedScale: 0.92, pressedOpacity: 0.7))", toolbar)

    def test_compose_card_uses_compact_hierarchy_and_safe_menu(self):
        compose = source("Features/Docker/DockerComposeView.swift")
        self.assertIn("private static let primaryVerbs: [DockerComposeVerb] = [.start, .stop, .restart, .logs]", compose)
        self.assertIn('Section("配置与文件")', compose)
        self.assertIn('Section("备份管理")', compose)
        self.assertIn('Section("危险操作")', compose)
        self.assertIn("menuButton(.backupRemove, role: .destructive)", compose)
        self.assertIn("menuButton(.backupsClear, role: .destructive)", compose)
        self.assertNotIn("ForEach(DockerComposeVerb.allCases", compose)

    def test_volume_card_uses_compact_hierarchy_and_safe_menu(self):
        volumes = source("Features/Docker/DockerVolumesView.swift")
        self.assertIn("private static let primaryVerbs: [DockerVolumeVerb] = [.backup, .backupList, .export]", volumes)
        self.assertIn('Section("备份管理")', volumes)
        self.assertIn('Section("危险操作")', volumes)
        self.assertIn("menuButton(.backupRemove, role: .destructive)", volumes)
        self.assertIn("menuButton(.remove, role: .destructive)", volumes)
        self.assertNotIn("ForEach(DockerVolumeVerb.allCases", volumes)

    def test_settings_screen_has_server_copy_and_account_switcher(self):
        settings = source("Features/Settings/SettingsScreen.swift")
        self.assertIn("LuckyClipboard.copy(session.baseUrl)", settings)
        self.assertIn("DashboardAccountPicker()", settings)
        self.assertIn("showingAccounts = true", settings)


if __name__ == "__main__":
    unittest.main()
