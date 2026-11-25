import SwiftUI

/// Presentation metadata for the four service kinds — the `config` map at the top of
/// `app/services/[kind].tsx`. Function colours are shared through `LuckyServiceKind.iconRole`.
extension LuckyServiceKind {
    var title: String {
        switch self {
        case .webservice: "反向代理"
        case .ddns: "动态域名"
        case .docker: "Docker 容器"
        case .ssl: "SSL 证书"
        }
    }

    var subtitle: String {
        switch self {
        case .webservice: "域名、监听与后端规则"
        case .ddns: "DDNS 任务状态与同步"
        case .docker: "容器运行状态与控制"
        case .ssl: "证书有效期与同步状态"
        }
    }

    var symbol: String {
        switch self {
        case .webservice: "globe.asia.australia"
        case .ddns: "arrow.triangle.2.circlepath"
        case .docker: "shippingbox"
        case .ssl: "checkmark.shield"
        }
    }
}

/// The field-name guesswork the 服务详情 screen runs on, ported from the helpers above
/// `ServiceDetailScreen` in `app/services/[kind].tsx`.
///
/// Every Lucky module spells the same concept differently — a DDNS task's identifier is `TaskKey`,
/// a certificate's is `Key`, a container's is `ID` — so each reader walks a candidate list instead
/// of trusting a schema. They live in their own file because the 高级操作 sheet and the three
/// editors need them as much as the list does.
enum ServiceRecord {
    /// `pick(item, keys, fallback = '--')`.
    ///
    /// Two differences from `JSONUnwrap.pick`, both deliberate: a string that is blank after
    /// trimming falls through to the next key, and an **empty** array wins and returns `""` rather
    /// than being skipped. An object inside an array serialises as JSON where the original prints
    /// `[object Object]` — the only place the two disagree, and only for payloads no Lucky build
    /// sends.
    static func pick(_ item: JSONValue, _ keys: [String], _ fallback: String = "--") -> String {
        for key in keys {
            guard let value = item[key] else { continue }
            switch value {
            case .string(let text):
                if !text.jsTrimmed.isEmpty { return text }
            case .number(let number):
                return JSONSerializer.numberString(number)
            case .array(let items):
                return items.map(\.asDisplayString).joined(separator: ", ")
            default:
                continue
            }
        }
        return fallback
    }

    /// `itemKey(item, index)` — the list position is the last resort, so a module that returns
    /// unkeyed rows still gets stable identity for one render.
    static func key(_ item: JSONValue, _ index: Int) -> String {
        pick(item, ["Key", "key", "TaskKey", "taskKey", "DDNSTaskKey", "ID", "Id", "id"],
             String(index))
    }

    /// `childRecord(item, key)` — a nested plain object, or `{}` for anything else.
    static func child(_ item: JSONValue, _ key: String) -> JSONValue {
        guard let value = item[key], value.isRecord else { return .object(JSONObject()) }
        return value
    }

    /// `isEnabled(item)` — `Enable ?? enable ?? Enabled`, where `??` skips `null` and missing keys
    /// but stops on `false` and `0`. A module that never reports the field reads as enabled.
    static func isEnabled(_ item: JSONValue) -> Bool {
        for key in ["Enable", "enable", "Enabled"] {
            guard let value = item[key], !value.isNull else { continue }
            return Format.asEnabled(value)
        }
        return true
    }

    /// `/^(?:true|1|yes|running|pending|issuing|processing|in[_ -]?progress)$/i` written out — the
    /// port has no regex engine, and the pattern is anchored, so it is a set membership test.
    private static let issuingWords: Set<String> = [
        "true", "1", "yes", "running", "pending", "issuing", "processing",
        "inprogress", "in_progress", "in progress", "in-progress",
    ]

    /// `isAcmeIssuing(item)` — the flag hides under a different spelling in each build, and under
    /// `data` / `ssl` / `ExtParams` in some of them.
    static func isAcmeIssuing(_ item: JSONValue) -> Bool {
        let sources = [item, child(item, "data"), child(item, "ssl"), child(item, "ExtParams")]
        for source in sources {
            var found: JSONValue?
            for key in ["ACMEing", "Acmeing", "acmeing", "ACMEInProgress", "acmeInProgress"] {
                guard let value = source[key], !value.isNull else { continue }
                found = value
                break
            }
            guard let value = found else { continue }
            if case .bool(true) = value { return true }
            if case .number(let number) = value, number == 1 { return true }
            if case .string(let text) = value,
               issuingWords.contains(text.jsTrimmed.lowercased()) { return true }
        }
        return false
    }

    private static let detailKeys = ["rule", "task", "container", "ssl", "certificate", "cert",
                                     "info", "configure", "setting", "data", "result"]

    /// `detailValue(payload)` — peels the wrapper the module happened to use, up to six deep.
    ///
    /// The original also carries an identity-based `visited` set. Parsed JSON is a tree, so no
    /// value can contain itself and the check never fires; the depth cap is what bounds the walk.
    static func detailValue(_ payload: JSONValue?) -> JSONValue {
        guard let payload else { return .object(JSONObject()) }
        var value = payload
        for _ in 0..<6 {
            var nested: JSONValue?
            for key in detailKeys {
                guard let candidate = value[key], candidate.isRecord else { continue }
                nested = candidate
                break
            }
            guard let next = nested else { break }
            value = next
        }
        return value
    }

    /// `editableValue(payload)` — the same record with the response envelope dropped, because the
    /// form editor must not post `ret` and `msg` back to the server.
    static func editableValue(_ payload: JSONValue) -> JSONValue {
        var value = detailValue(payload).record
        value.removeValue(forKey: "ret")
        value.removeValue(forKey: "msg")
        return .object(value)
    }

    /// `sslSummary(item)` — `TYPE · domains · 到期 date`, with empty parts dropped so a
    /// file-uploaded certificate that reports nothing else still shows its type.
    static func sslSummary(_ item: JSONValue) -> String {
        let certs: JSONValue
        if let raw = item["CertsInfo"], let list = raw.arrayValue {
            certs = list.first(where: \.isRecord) ?? .object(JSONObject())
        } else {
            certs = child(item, "CertsInfo")
        }
        let ext = child(item, "ExtParams")
        var domains: [String] = []
        if let list = certs["Domains"]?.arrayValue {
            domains = list.map(\.asDisplayString)
        } else if let list = item["Domains"]?.arrayValue {
            domains = list.map(\.asDisplayString)
        } else if let list = ext["acmeDomains"]?.arrayValue {
            domains = list.map(\.asDisplayString)
        }
        let type = pick(item, ["AddFrom", "Type"], "file")
        let typeLabel: String = switch type.lowercased() {
        case "acme": "ACME"
        case "file": "文件证书"
        case "path": "路径证书"
        case "sync": "同步证书"
        default: type.uppercased()
        }
        let expiry = pick(certs, ["NotAfterTime", "NotAfter", "ExpireTime"],
                          pick(item, ["ExpireTime", "UpdateTime"], ""))
        let parts = [typeLabel, domains.joined(separator: ", "),
                     expiry.isEmpty ? "" : "到期 \(expiry)"]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// `recordItems(value)` — a DDNS task's DNS records, wherever this build put them.
    static func recordItems(_ value: JSONValue?) -> [JSONValue] {
        guard let value else { return [] }
        let candidates = [value["Records"], value["records"], value["RecordList"],
                          value["recordList"], child(value, "data")["Records"]]
        for candidate in candidates {
            guard let list = candidate?.arrayValue else { continue }
            return list.filter(\.isRecord)
        }
        return []
    }

    /// The same first-array-wins read for a payload whose key list is known at the call site —
    /// the odhcpd client list and the certificate sync options both arrive this way.
    static func recordList(_ payload: JSONValue?, _ keys: [String]) -> [JSONValue] {
        guard let payload else { return [] }
        for key in keys {
            guard let list = payload[key]?.arrayValue else { continue }
            return list.filter(\.isRecord)
        }
        return []
    }

    static func recordKey(_ item: JSONValue, _ index: Int) -> String {
        pick(item, ["RecordKey", "recordKey", "Key", "key", "ID", "Id", "id",
                    "Name", "name", "Domain", "domain"], String(index))
    }

    static func ddnsRecordDomain(_ item: JSONValue) -> String {
        let source = child(item, "SyncRecordData")
        let domainName = pick(item, ["DomainName", "domainName"], "")
        let subDomain = pick(item, ["SubDomain", "subDomain"], "")
        let composed: String
        if !domainName.isEmpty, domainName != "--" {
            composed = !subDomain.isEmpty && subDomain != "--" && subDomain != "@"
                ? "\(subDomain).\(domainName)" : domainName
        } else {
            composed = ""
        }
        return pick(item, ["Domain", "domain", "FQDN", "RecordName", "Name", "name"],
                    composed.isEmpty ? pick(source, ["fullDomainName"], "") : composed)
    }

    static func recordEnabled(_ item: JSONValue) -> Bool {
        if let enabled = item["Enable"]?.boolValue { return enabled }
        if let disabled = item["Disable"]?.boolValue { return !disabled }
        return true
    }

    static func recordResult(_ item: JSONValue) -> String {
        let latest = item["LastRecord"]?.arrayValue?
            .map { entry in
                entry.isRecord ? pick(entry, ["Record", "Value"], "") : entry.asDisplayString
            }
            .filter { !$0.isEmpty }
            .joined(separator: ", ") ?? ""
        let rawStatus = pick(item, ["UpdateStatus"], "")
        let status: String = switch rawStatus.jsTrimmed.lowercased() {
        case "success", "succeeded", "ok": "同步成功"
        case "failure", "failed", "error": "同步失败"
        case "unchanged", "skipped": "无变更"
        case "pending", "waiting": "等待同步"
        default: rawStatus
        }
        return [status, latest, pick(item, ["Message"], "")]
            .filter { !$0.isEmpty && $0 != "--" }
            .joined(separator: " · ")
    }

    /// `recordLabel(item, index)` — `domain · type · value`. A literal `--` is dropped along with
    /// the empty parts, so a record that reports nothing falls back to its position.
    static func recordLabel(_ item: JSONValue, _ index: Int) -> String {
        let source = child(item, "SyncRecordData")
        let resolvedDomain = ddnsRecordDomain(item)
        let domain = resolvedDomain.isEmpty ? "记录" : resolvedDomain
        let type = pick(item, ["Type", "type", "RecordType", "recordType"],
                        pick(source, ["type"], ""))
        let value = pick(item, ["Value", "value", "IPv4", "IPv6", "Address", "address"],
                         pick(source, ["ipv4Address", "ipv6Address", "CNAMEContent", "TXTContent"], ""))
        let label = [domain, type, value]
            .filter { !$0.isEmpty && $0 != "--" }
            .joined(separator: " · ")
        return label.isEmpty ? "记录 \(index + 1)" : label
    }

    private static let resultKeys = ["result", "output", "Output", "ip", "IP", "data",
                                     "logs", "LastLogs", "text", "Text", "msg", "message"]

    /// `resultText(value)` — flattens whatever an operation returned into something printable.
    ///
    /// Objects are searched for a payload key first, in the listed order, and only fall back to
    /// `key: value` lines; nested newlines are indented two spaces so the nesting stays readable.
    /// `.binary` reads as empty, matching `Object.entries(blob)` on a downloaded body.
    static func resultText(_ value: JSONValue?) -> String {
        guard let value else { return "" }
        switch value {
        case .null, .binary:
            return ""
        case .bool(let flag):
            return flag ? "true" : "false"
        case .number(let number):
            return JSONSerializer.numberString(number)
        case .string(let text):
            return text
        case .array(let items):
            return items.map { resultText($0) }.filter { !$0.isEmpty }.joined(separator: "\n")
        case .object(let object):
            for key in resultKeys {
                guard let nested = object[key], !nested.isNull else { continue }
                let text = resultText(nested)
                if !text.isEmpty { return text }
            }
            return object.pairs
                .map { pair -> String in
                    let text = resultText(pair.value)
                    guard !text.isEmpty else { return "" }
                    return "\(pair.key): \(text.replacingOccurrences(of: "\n", with: "\n  "))"
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }
    /// `text.split(/\r?\n|,/).map(trim).filter(Boolean)` — the 签发域名 and 域名/IP 列表 fields let
    /// the user separate entries by either newlines or commas.
    static func splitList(_ text: String) -> [String] {
        text.jsLines
            .flatMap { $0.components(separatedBy: ",") }
            .map(\.jsTrimmed)
            .filter { !$0.isEmpty }
    }

    /// `/run|正常|success|active|up/i.test(status)` — an unanchored alternation, so `up` also
    /// matches inside `backup` and `running` matches through `run`. Kept as written.
    static func isHealthyStatus(_ text: String) -> Bool {
        JSRegex.containsAny(text, ["run", "正常", "success", "active", "up"])
    }

    /// The row title. `Names` / `Domain` / `Domains` are only consulted here — the 排序 entry point
    /// uses a shorter list, and the port keeps that inconsistency rather than unifying it.
    static func displayName(_ item: JSONValue, kind: LuckyServiceKind, index: Int) -> String {
        let keys = kind == .ssl
            ? ["Remark", "remark", "Name", "name"]
            : ["Name", "name", "TaskName", "taskName", "DDNSTaskName", "Names", "Domain", "Domains"]
        return pick(item, keys, "项目 \(index + 1)")
    }

    /// `openOrdering`'s own naming of the first item, fallback `项目 1` regardless of position.
    static func orderingName(_ item: JSONValue, kind: LuckyServiceKind) -> String {
        let keys = kind == .ssl
            ? ["Remark", "remark", "Name", "name"]
            : ["Name", "name", "TaskName", "taskName", "DDNSTaskName"]
        return pick(item, keys, "项目 1")
    }

    /// `clientKey(item, index)` in both certificate editors.
    static func clientKey(_ item: JSONValue, _ index: Int) -> String {
        pick(item, ["Key", "ClientKey", "key", "ID", "id"], String(index))
    }

    /// The row subtitle: each kind reads a different field, and only SSL builds a composite.
    static func rowDetail(_ item: JSONValue, kind: LuckyServiceKind) -> String {
        switch kind {
        case .docker: pick(item, ["Image", "image", "ImageName"])
        case .ssl: sslSummary(item)
        case .ddns: ddnsSummary(item)
        case .webservice: pick(item, ["BackendURL", "ProxyURL", "Listen", "Domains"])
        }
    }

    static func ddnsProviderLabel(_ raw: String) -> String {
        switch raw.jsTrimmed.lowercased() {
        case "alidns": return "阿里云 DNS"
        case "aliesa": return "阿里云 ESA"
        case "baiducloud": return "百度智能云"
        case "cloudflare": return "Cloudflare"
        case "edgeone": return "EdgeOne"
        case "desec": return "deSEC"
        case "dnsla": return "DNSLA"
        case "dnspod": return "DNSPod 中国"
        case "dnspodcom": return "DNSPod 国际"
        case "duckdns": return "Duck DNS"
        case "dynadot": return "Dynadot"
        case "dynv6": return "Dynv6"
        case "freemyip": return "FreeMyIP"
        case "godaddy": return "GoDaddy"
        case "huaweicloud": return "华为云"
        case "jdcloud": return "京东云"
        case "namecom": return "name.com"
        case "namesilo": return "NameSilo"
        case "spaceship": return "Spaceship"
        case "porkbun": return "Porkbun"
        case "tencentcloudv3", "tencentcloud": return "腾讯云"
        case "vercel": return "Vercel"
        case "volcengine": return "火山引擎"
        case "west": return "西部数码"
        case "callback": return "自定义回调"
        default: return raw
        }
    }

    static func localizedStatus(_ raw: String) -> String {
        switch raw.jsTrimmed.lowercased() {
        case "running": return "运行中"
        case "stopped": return "已停止"
        case "exited": return "已退出"
        case "paused": return "已暂停"
        case "created": return "已创建"
        case "restarting": return "重启中"
        case "removing": return "移除中"
        case "dead": return "已失效"
        case "pending": return "等待中"
        case "completed", "done": return "已完成"
        case "success", "succeeded", "ok": return "正常"
        case "failed", "failure", "error": return "失败"
        case "active", "enabled": return "已启用"
        case "inactive", "disabled": return "已停用"
        case "online": return "在线"
        case "offline": return "离线"
        default: return raw
        }
    }

    static func ddnsSummary(_ item: JSONValue) -> String {
        let dns = child(item, "DNS")
        let rawProvider = pick(dns, ["Name"],
                               pick(item, ["DNSProvider", "Provider"], "未设置服务商"))
        let provider = ddnsProviderLabel(rawProvider)
        let records = recordItems(item)
        let ipv4 = pick(item, ["Ipv4Addr", "IPv4Addr", "V4Addr"], "")
        let ipv6 = pick(item, ["Ipv6Addr", "IPv6Addr", "V6Addr"], "")
        return [
            provider,
            "\(records.count) 条记录",
            ipv4.isEmpty || ipv4 == "--" ? "" : "IPv4 \(ipv4)",
            ipv6.isEmpty || ipv6 == "--" ? "" : "IPv6 \(ipv6)",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    /// The status word: 签发中 while ACME is running, then the module's own field, then the switch
    /// state as a last resort.
    static func rowStatus(_ item: JSONValue) -> String {
        if isAcmeIssuing(item) { return "签发中" }
        let raw = pick(item, ["Status", "status", "State", "state", "LastResult"],
                       isEnabled(item) ? "正常" : "已停用")
        return localizedStatus(raw)
    }
}
