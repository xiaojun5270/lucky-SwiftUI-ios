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

    def test_visual_design_depth_and_telemetry(self):
        backdrop = source("Design/LuckyBackdrop.swift")
        self.assertIn("RadialGradient", backdrop)
        self.assertIn("stops: [", backdrop)
        self.assertNotIn(".blur(radius:", backdrop)

        surface = source("Design/LuckySurface.swift")
        self.assertIn(".shadow(", surface)

        dashboard = source("Features/Dashboard/DashboardScreen.swift")
        self.assertIn(".background(LuckyTheme.surfaceRaised, in: .rect(cornerRadius: LuckyTheme.Radius.row))", dashboard)

        gauge = source("Design/LuckyGauge.swift")
        self.assertIn("peakTelemetryString", gauge)
        self.assertIn("Text(\"%\")", gauge)
        self.assertIn("var detail: String? = nil", gauge)

        web = source("Features/WebService/WebSubRuleCard.swift")
        self.assertIn("topologyNode(", web)
        self.assertIn("serviceTone", web)

        log = source("Design/LuckyLogView.swift")
        self.assertIn(".lineSpacing(2)", log)

    def test_frameless_solid_icons(self):
        iconography = source("Design/LuckyIconography.swift")
        self.assertIn("static func solid(_ symbol: String) -> String", iconography)
        self.assertIn('"cube.transparent": return "cube.fill"', iconography)
        self.assertIn('"globe.asia.australia": return "globe.asia.australia.fill"', iconography)
        self.assertIn('"lock.shield": return "lock.shield.fill"', iconography)

        # LuckyFunctionIcon must render directly without a RoundedRectangle tile/plate
        icon_func = iconography.split("struct LuckyFunctionIcon: View", 1)[1].split("extension TunnelKind", 1)[0]
        self.assertNotIn("RoundedRectangle", icon_func)
        self.assertIn("Image(systemName: solidSymbol)", icon_func)

    def test_performance_optimizations(self):
        surface = source("Design/LuckySurface.swift")
        self.assertIn(".compositingGroup()", surface)

        controls = source("Features/Docker/DockerControls.swift")
        self.assertIn("Task.detached(priority: .userInitiated)", controls)
        self.assertIn("struct ContainerStatsGrid: View, Equatable", controls)

        containers = source("Features/Docker/DockerContainersView.swift")
        self.assertIn("ContainerStatsGrid(stats: stat).equatable()", containers)

    def test_services_screen_hides_tools_entry(self):
        services = source("Features/Services/ServicesScreen.swift")
        self.assertNotIn("toolsEntry", services)
        self.assertNotIn("更多工具", services)

    def test_docker_stats_no_na_and_cached(self):
        record = source("Features/Docker/DockerRecord.swift")
        self.assertNotIn('"N/A"', record)
        self.assertIn('guard available else { return "--" }', record)

        controls = source("Features/Docker/DockerControls.swift")
        self.assertNotIn('"N/A"', controls)
        self.assertIn('guard let stats else { return "--" }', controls)

        model = source("Features/Docker/DockerScreenModel.swift")
        self.assertIn("class DockerStatsCache", model)

        screen = source("Features/Docker/DockerScreen.swift")
        self.assertIn("DockerStatsCache.shared", screen)

    def test_structured_form_replaces_raw_json(self):
        surface = source("Design/LuckySurface.swift")
        self.assertIn("StructuredDataView(value: json)", surface)

        form = source("Features/Endpoints/StructuredForm.swift")
        self.assertIn("parseJsonString", form)
        self.assertIn("unwrapped(", form)
        self.assertIn("isMultilineOrLong", form)
        self.assertIn('"ip": "IP 地址"', form)
        self.assertIn('"status": "状态"', form)
        self.assertIn('"RuleName": "规则名称"', form)

    def test_p0_visual_bug_fixes(self):
        containers = source("Features/Docker/DockerContainersView.swift")
        self.assertIn("if row.paused { return .warning }", containers)
        self.assertNotIn("LuckyTheme.idleSoft", containers)

        compose = source("Features/Docker/DockerComposeView.swift")
        self.assertIn("compact: compact", compose)

        controls = source("Features/Docker/DockerControls.swift")
        self.assertIn("var compact: Bool = false", controls)
        self.assertIn("LuckySymbol.solid(metric.symbol)", controls)
        self.assertIn("tray.and.arrow.down.fill", controls)
        self.assertIn("tray.and.arrow.up.fill", controls)

        chip = source("Design/LuckyChip.swift")
        self.assertIn("if shouldPulse {", chip)
        self.assertIn(".onChange(of: shouldPulse)", chip)

        glass = source("Design/LuckyGlassControls.swift")
        self.assertIn("var multiline: Bool = false", glass)
        self.assertIn("struct LuckyHorizontalTabBar<Value: Hashable>: View", glass)

        feedback = source("Design/LuckyFeedback.swift")
        self.assertIn("multiline: true", feedback)

    def test_p1_p2_polish_navigation_and_performance(self):
        docker_screen = source("Features/Docker/DockerScreen.swift")
        self.assertIn("LuckyHorizontalTabBar(", docker_screen)

        web_screen = source("Features/WebService/WebServiceScreen.swift")
        self.assertIn("LuckyHorizontalTabBar(", web_screen)

        action_sheet = source("Features/Docker/DockerActionSheet.swift")
        self.assertIn("var destructive: Bool = false", action_sheet)
        self.assertIn("item.destructive ? LuckyTheme.danger : LuckyTheme.textPrimary", action_sheet)

        logs = source("Features/Logs/LogsScreen.swift")
        self.assertIn("cachedVisibleLines", logs)
        self.assertIn("recomputeVisibleLines()", logs)

        login = source("Features/Login/LoginScreen.swift")
        self.assertIn("@FocusState private var focusedField: Field?", login)
        self.assertIn("LuckyPressStyle(", login)

        dashboard = source("Features/Dashboard/DashboardScreen.swift")
        self.assertIn("session.updateRemark(", dashboard)
        self.assertIn("session.removeProfile(", dashboard)
        self.assertIn("LuckyStatusDot(tone: connected ? .ok : .warning, pulsing: connected", dashboard)

    def test_docker_persistent_cache_and_background_warmup(self):
        stats_core = source("Core/DockerStats.swift")
        self.assertIn("struct DockerStatRow: Identifiable, Hashable, Sendable, Codable", stats_core)

        model = source("Features/Docker/DockerScreenModel.swift")
        for token in [
            "struct DockerPersistedSnapshot: Codable, Sendable",
            '"LuckyDockerCache"',
            "func hydrateFromDiskIfNeeded(credentials: LuckyCredentials)",
            "func runBackgroundWarmup(credentials: LuckyCredentials)",
            "private func schedulePersist()",
            "Task.detached(priority: .utility)",
        ]:
            self.assertIn(token, model)

        root = source("App/LuckyRoot.swift")
        self.assertIn("DockerStatsCache.shared.runBackgroundWarmup(credentials: session.credentials)", root)

        docker_screen = source("Features/Docker/DockerScreen.swift")
        self.assertNotIn("pollStats()", docker_screen)
        self.assertNotIn("pollLiveStats()", docker_screen)
        self.assertIn("cache.activate(credentials: LuckySession.shared.credentials)", docker_screen)

        queries = source("Features/Docker/DockerScreen+Queries.swift")
        self.assertIn("cache.hasWarmData(for: .containers)", queries)
        self.assertIn("cache.hydrateFromDiskIfNeeded(credentials: LuckySession.shared.credentials)", queries)

        controls = source("Features/Docker/DockerControls.swift")
        self.assertIn('"LuckyDockerIcons"', controls)
        self.assertIn("nonisolated static func buildRows(", controls)
        self.assertIn("func prewarm(_ icons: [String])", controls)
        self.assertIn("let work = Task { await refresh() }", controls)

    def test_web_rules_removes_child_controls_and_docker_refresh_is_smooth(self):
        rules = source("Features/WebService/WebRulesView.swift")
        self.assertNotIn("private var childControls", rules)
        self.assertNotIn("搜索域名、备注或后端地址", rules)
        self.assertIn('Section("子规则管理")', rules)
        self.assertIn('Button("添加子规则"', rules)
        self.assertIn('Button("调整子规则顺序"', rules)

        containers = source("Features/Docker/DockerContainersView.swift")
        self.assertIn("var prebuiltRows: [DockerContainerRow]? = nil", containers)
        self.assertIn("private struct DockerContainerCard: View, Equatable", containers)
        self.assertIn(".equatable()", containers)

        model = source("Features/Docker/DockerScreenModel.swift")
        self.assertIn("private(set) var prebuiltContainerRows: [DockerContainerRow] = []", model)
        self.assertIn("awaitLiveFallback: Bool = true", model)
        self.assertIn("scheduleBackgroundLiveSweep(", model)

        queries = source("Features/Docker/DockerScreen+Queries.swift")
        self.assertIn("func refresh(fromPull: Bool = false)", queries)
        self.assertIn("awaitLiveFallback: false", queries)
        self.assertIn("syncedDataRevision != cache.dataRevision", queries)

    def test_cross_page_polish_caches_appearance_and_compact_cards(self):
        # 1. Web sub-rule card compaction & WebRulesCache
        sub = source("Features/WebService/WebSubRuleCard.swift")
        self.assertIn("LuckyCard(radius: 14, padding: 0, spacing: 0)", sub)
        self.assertIn("compact: true", sub)
        self.assertNotIn('"已启用" : "已停用"', sub)

        web_model = source("Features/WebService/WebServiceModel.swift")
        self.assertIn("final class WebRulesCache", web_model)
        self.assertIn('"LuckyWebCache"', web_model)

        # 2. Logs compact single-row status header + severity counts + incremental append
        logs = source("Features/Logs/LogsScreen.swift")
        self.assertIn("warningCount", logs)
        self.assertIn("errorCount", logs)
        self.assertIn("canIncrementallyAppend", logs)

        # 3. DDNS/SSL compact card & inline toggle & stable row entries
        detail = source("Features/Services/ServiceDetailScreen.swift")
        self.assertIn("private struct ServiceRowEntry: Identifiable", detail)
        self.assertIn("LuckyHorizontalTabBar(", detail)
        self.assertIn("private func compactVerbs(", detail)

        # 4. Dashboard account switcher pill & live quick-link badges
        page = source("Design/LuckyPage.swift")
        self.assertIn("person.crop.circle.fill", page)
        self.assertIn("let work = Task { await refresh() }", page)
        dashboard = source("Features/Dashboard/DashboardScreen.swift")
        self.assertIn("var badge: String", dashboard)
        self.assertIn(".frame(maxHeight: .infinity)", dashboard)
        self.assertIn("WebRulesCache.shared", dashboard)

        # 5. Tunnel screen stable entries, filter capsules & tap-to-copy STUN address
        tunnel = source("Features/Tunnels/TunnelScreen.swift")
        self.assertIn("private enum TunnelStatusFilter", tunnel)
        self.assertIn("private struct TunnelRowEntry: Identifiable", tunnel)
        self.assertIn("tunnelFilterBar(", tunnel)

        # 6. Settings appearance toggle + cache manager & app preferredColorScheme
        theme = source("Design/LuckyTheme.swift")
        self.assertIn("enum LuckyAppearance", theme)
        app = source("App/LuckyGlassApp.swift")
        self.assertIn(".preferredColorScheme(appearance.colorScheme)", app)
        settings = source("Features/Settings/SettingsScreen.swift")
        self.assertIn("appearanceAndCache", settings)
        self.assertIn("DockerStatsCache.totalDiskCacheBytes()", settings)
        self.assertIn("clearAllDiskCaches()", settings)

        # 7. SSL info unwrapping + ACME localization + clean structured config editor
        records = source("Features/Services/ServiceRecords.swift")
        self.assertIn('"info"', records)
        self.assertIn('"文件证书"', records)
        ssl_editors = source("Features/Services/SslCertificateEditors.swift")
        self.assertIn('"acmeCADirURL"', ssl_editors)
        self.assertIn('"acmeDNSID"', ssl_editors)
        self.assertIn('"acmeDNSSecret"', ssl_editors)
        self.assertIn('"DNS 账号 ID"', ssl_editors)
        self.assertIn('"DNS 密钥"', ssl_editors)
        form = source("Features/Endpoints/StructuredForm.swift")
        self.assertIn('"acmeCADirURL": "ACME 目录地址"', form)
        self.assertIn("var allowStructuralEdits: Bool = true", form)
        service_form = source("Features/Services/ServiceFormEditor.swift")
        self.assertIn("allowStructuralEdits: false", service_form)


if __name__ == "__main__":
    unittest.main()
