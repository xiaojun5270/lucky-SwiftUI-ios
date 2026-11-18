#if DEBUG
import SwiftUI

/// Local records let Canvas exercise disclosure, filtering and switches without network calls.
private struct WebRulesPreviewHost: View {
    @State private var items: [LuckyListItem]
    @State private var expanded: String
    @State private var toast: LuckyToast?

    init(open: Bool = false) {
        _items = State(initialValue: Self.sampleRules)
        _expanded = State(initialValue: open ? "http" : "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LuckyBackdrop()
                WebRulesView(items: items, expanded: expanded, loading: false, busy: false,
                             refresh: {}, actions: actions)
            }
            .navigationTitle("Web 服务")
            .navigationBarTitleDisplayMode(.inline)
            .luckyToast($toast)
        }
    }

    private var actions: WebRuleActions {
        WebRuleActions(
            expand: { expanded = expanded == $0 ? "" : $0 },
            move: { index, offset in
                let target = index + offset
                guard items.indices.contains(target) else { return }
                items.swapAt(index, target)
            },
            setEnabled: { key, enabled in
                guard let index = ruleIndex(key) else { return }
                items[index]["Enable"] = .bool(enabled)
            },
            edit: { _, copy in show(copy ? "复制规则" : "编辑规则") },
            remove: { _, _ in show("删除规则确认") },
            order: { _ in show("调整子规则顺序") },
            tools: { _ in show("日志与工具") },
            editSub: { _, key in show(key == nil ? "添加子规则" : "编辑子规则") },
            setSubEnabled: { parent, key, enabled in
                guard let index = ruleIndex(parent) else { return }
                let entry = WebRuleEntry(item: items[index], index: index)
                guard let sub = entry.subRules.first(where: { $0.id == key }) else { return }
                var proxies = WebRecord.array(items[index], ["ProxyList"])
                proxies[sub.index]["Enable"] = .bool(enabled)
                items[index]["ProxyList"] = .array(proxies)
            },
            removeSub: { _, _, _ in show("删除子规则确认") },
            copyURL: { rule, sub in
                let url = (try? WebRecord.subRuleUrl(rule, sub)) ?? "未配置地址"
                show("复制 \(url)")
            }
        )
    }

    private func ruleIndex(_ key: String) -> Int? {
        items.indices.first { WebRecord.key(items[$0], $0) == key }
    }

    private func show(_ action: String) { toast = .ok("布局预览：\(action)") }

    private static func rule(_ key: String, name: String, port: Int, count: Int) -> JSONValue {
        let labels = ["个人主页", "相册", "文件服务", "监控面板", "家庭媒体"]
        let proxies: [JSONValue] = (0..<count).map { index in
            var record = JSONObject([
                ("Enable", .bool(index % 9 != 8)),
                ("Remark", .string(index < labels.count ? labels[index] : "应用 \(index + 1)")),
                ("WebServiceType", .string("reverseproxy")),
                ("Domains", .array([.string("app\(index + 1).example.test")])),
                ("Locations", .array([.string("http://192.168.1.\(index + 10):8080")])),
            ])
            // Exercise the original-index fallback as well as explicit server keys.
            if index != 0 { record["Key"] = .string("\(key)-\(index)") }
            return .object(record)
        }
        return .object(JSONObject([
            ("RuleKey", .string(key)), ("RuleName", .string(name)), ("Enable", .bool(true)),
            ("Network", .string("tcp")), ("ListenIP", .string("")), ("ListenPort", .int(port)),
            ("EnableTLS", .bool(key == "https")), ("ProxyList", .array(proxies)),
        ]))
    }

    private static let sampleRules = [
        rule("http", name: "HTTP", port: 16679, count: 27),
        rule("https", name: "HTTPS", port: 16678, count: 5),
    ]
}

private struct WebRulesPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            WebRulesPreviewHost().preferredColorScheme(.light)
                .previewDisplayName("规则 · 收起")
            WebRulesPreviewHost(open: true).preferredColorScheme(.light)
                .previewDisplayName("规则 · 27 条子规则")
            WebRulesPreviewHost(open: true).preferredColorScheme(.dark)
                .previewDisplayName("规则 · 深色")
            WebRulesPreviewHost().previewLayout(.fixed(width: 320, height: 720))
                .previewDisplayName("规则 · 窄屏")
            WebRulesPreviewHost(open: true).dynamicTypeSize(.accessibility2)
                .previewDisplayName("规则 · 大字体")
        }
    }
}
#endif
