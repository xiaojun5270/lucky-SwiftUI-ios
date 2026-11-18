import Foundation

/// Keep each record's original index when filtering so keyless records still target the
/// correct server entry. Display order never becomes an API identifier.
struct WebRuleEntry: Identifiable {
    var item: LuckyListItem
    var index: Int

    var id: String { WebRecord.key(item, index) }
    var enabled: Bool { WebRecord.isEnabled(item) }
    var name: String {
        let value = WebRecord.pick(item, ["RuleName", "Name"]).jsTrimmed
        return value.isEmpty ? "未命名规则" : value
    }

    var listener: String {
        let network = WebRecord.pick(item, ["Network"], "tcp").uppercased()
        let ip = WebRecord.pick(item, ["ListenIP"]).jsTrimmed
        let rawPort = WebRecord.pick(item, ["ListenPort"], "--")
        let port = rawPort.isEmpty ? "--" : rawPort
        guard !ip.isEmpty, ip != "*" else { return "\(network) · 端口 \(port)" }
        let host = ip.contains(":") && !ip.hasPrefix("[") ? "[\(ip)]" : ip
        return "\(network) · \(host):\(port)"
    }

    var subRules: [WebSubRuleEntry] {
        WebRecord.array(item, ["ProxyList"]).enumerated().map {
            WebSubRuleEntry(item: $0.element, index: $0.offset)
        }
    }
}

struct WebSubRuleEntry: Identifiable {
    var item: LuckyListItem
    var index: Int

    var id: String { WebRecord.key(item, index) }
    var enabled: Bool { WebRecord.isEnabled(item) }
    var domains: [String] { WebRecord.lines(item["Domains"]) }
    var locations: [String] { WebRecord.lines(item["Locations"]) }
    var remark: String { WebRecord.pick(item, ["Remark"]).jsTrimmed }
    var name: String { remark.isEmpty ? (domains.first ?? "子规则 \(index + 1)") : remark }
    var fileService: Bool { WebRecord.pick(item, ["WebServiceType"]).lowercased().contains("file") }

    var serviceType: String {
        let type = WebRecord.pick(item, ["WebServiceType"]).jsTrimmed
        switch type.lowercased() {
        case "", "reverseproxy": return "反向代理"
        case "fileserver": return "文件服务"
        case "redirect": return "重定向"
        case "url": return "URL 跳转"
        case "snirouting": return "SNI 路由"
        case "oauth": return "OAuth 认证"
        default: return type
        }
    }

    func matches(_ query: String) -> Bool {
        let needle = query.jsTrimmed
        guard !needle.isEmpty else { return true }
        let text = ([name, serviceType] + domains + locations).joined(separator: " ")
        return text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

enum WebSubRuleFilter: String, CaseIterable, Identifiable {
    case all, enabled, disabled

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "全部"
        case .enabled: "已启用"
        case .disabled: "已停用"
        }
    }

    func includes(_ entry: WebSubRuleEntry) -> Bool {
        switch self {
        case .all: true
        case .enabled: entry.enabled
        case .disabled: !entry.enabled
        }
    }
}
