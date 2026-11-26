import SwiftUI

/// `app/(tabs)/_layout.tsx`.
///
/// The system tab bar stays at its full size while content scrolls, so navigation does not shift
/// under the user's thumb. Glass and blur still come from the native iOS 26 tab bar.
struct LuckyRoot: View {
    @Environment(\.scenePhase) private var phase
    @State private var navigator = LuckyNavigator()
    @State private var session = LuckySession.shared

    private var warmupTaskID: String {
        "\(session.sessionGeneration)|\(session.isAuthenticated)|\(phase == .active)"
    }

    var body: some View {
        TabView(selection: $navigator.selection) {
            ForEach(LuckyTab.allCases) { tab in
                Tab(tab.label, systemImage: symbol(tab), value: tab) {
                    stack(tab)
                }
            }
        }
        .tabBarMinimizeBehavior(.never)
        .environment(\.luckyNavigator, navigator)
        .tint(LuckyTheme.accent)
        .task(id: warmupTaskID) {
            guard session.isAuthenticated, phase == .active else { return }
            await WebRulesCache.shared.hydrateFromDiskIfNeeded(credentials: session.credentials)
            async let dockerWarmup: Void = DockerStatsCache.shared.runBackgroundWarmup(credentials: session.credentials)
            async let serviceSummary: Void = ServiceSummaryCache.shared.refreshIfNeeded(credentials: session.credentials)
            _ = await (dockerWarmup, serviceSummary)
        }
    }

    /// `<Icon sf={{ default, selected }} />`: the filled glyph while the tab is current.
    private func symbol(_ tab: LuckyTab) -> String {
        navigator.selection == tab ? tab.selectedSymbol : tab.symbol
    }

    private func stack(_ tab: LuckyTab) -> some View {
        NavigationStack(path: navigator.binding(for: tab)) {
            root(tab)
                .navigationDestination(for: LuckyRoute.self) { route in
                    destination(route)
                        .navigationTitle(route.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(.visible, for: .navigationBar)
                        // The original pushes onto the root stack, above the tab bar, so a
                        // detail screen never shows one.
                        .toolbar(.hidden, for: .tabBar)
                }
        }
    }

    @ViewBuilder
    private func root(_ tab: LuckyTab) -> some View {
        switch tab {
        case .dashboard: DashboardScreen()
        case .services: ServicesScreen()
        case .logs: LogsScreen()
        case .settings: SettingsScreen()
        }
    }

    @ViewBuilder
    private func destination(_ route: LuckyRoute) -> some View {
        switch route {
        case .service(let kind): ServiceDetailScreen(kind: kind)
        case .webservice: WebServiceScreen()
        case .docker(let view, let search): DockerScreen(initialView: view, initialSearch: search)
        case .tunnel(let kind): TunnelScreen(kind: kind)
        case .module(let key): ModuleScreen(moduleKey: key)
        case .endpoint(let id): EndpointScreen(endpointID: id)
        case .moduleIndex: ModuleIndexScreen()
        }
    }
}
