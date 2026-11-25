import SwiftUI

private struct DdnsFormError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

private enum DdnsForm {
    static let providers = [
        SslOption(label: "阿里云 DNS", value: "alidns"),
        SslOption(label: "阿里云 ESA", value: "aliesa"),
        SslOption(label: "百度智能云", value: "baiducloud"),
        SslOption(label: "Cloudflare", value: "cloudflare"),
        SslOption(label: "EdgeOne", value: "edgeone"),
        SslOption(label: "deSEC", value: "desec"),
        SslOption(label: "DNSLA", value: "dnsla"),
        SslOption(label: "DNSPod 中国", value: "dnspod"),
        SslOption(label: "DNSPod 国际", value: "dnspodcom"),
        SslOption(label: "Duck DNS", value: "duckdns"),
        SslOption(label: "Dynadot", value: "dynadot"),
        SslOption(label: "Dynv6", value: "dynv6"),
        SslOption(label: "FreeMyIP", value: "freemyip"),
        SslOption(label: "GoDaddy", value: "godaddy"),
        SslOption(label: "华为云", value: "huaweicloud"),
        SslOption(label: "京东云", value: "jdcloud"),
        SslOption(label: "name.com", value: "namecom"),
        SslOption(label: "NameSilo", value: "namesilo"),
        SslOption(label: "Spaceship", value: "spaceship"),
        SslOption(label: "Porkbun", value: "porkbun"),
        SslOption(label: "腾讯云", value: "tencentcloudV3"),
        SslOption(label: "Vercel", value: "vercel"),
        SslOption(label: "火山引擎", value: "volcengine"),
        SslOption(label: "西部数码", value: "west"),
        SslOption(label: "自定义回调", value: "callback"),
    ]

    private static let allRecordTypes = ["A", "AAAA", "CAA", "CNAME", "HTTPS", "MX", "NS",
                                         "SRV", "SVCB", "TXT"]
    private static let commonRecordTypes = ["A", "AAAA", "CAA", "CNAME", "MX", "NS", "SRV", "TXT"]
    private static let typesByProvider: [String: [String]] = [
        "alidns": allRecordTypes,
        "aliesa": ["ALIESAIPS", "CAA", "ALIESACNAME", "NS", "MX", "SRV", "TXT"],
        "baiducloud": ["A", "AAAA", "CNAME", "MX", "NS", "TXT"],
        "cloudflare": allRecordTypes,
        "desec": ["A", "AAAA", "CAA", "CNAME", "HTTPS", "NS", "MX", "SRV", "TXT"],
        "dnsla": commonRecordTypes,
        "dnspod": allRecordTypes + ["SPF"],
        "dnspodcom": commonRecordTypes,
        "duckdns": ["A", "AAAA"],
        "dynadot": ["A", "AAAA", "CAA", "CNAME", "MX", "SRV", "TXT"],
        "dynv6": ["A", "AAAA", "CAA", "CNAME", "MX", "SPF", "SRV", "TXT"],
        "edgeone": commonRecordTypes,
        "freemyip": ["A", "AAAA"],
        "godaddy": ["A", "AAAA"],
        "huaweicloud": commonRecordTypes,
        "jdcloud": commonRecordTypes,
        "namecom": ["A", "AAAA", "CNAME", "NS", "MX", "SRV", "TXT"],
        "namesilo": ["A", "AAAA", "CAA", "CNAME", "MX", "SRV", "TXT"],
        "spaceship": allRecordTypes,
        "porkbun": allRecordTypes,
        "tencentcloudV3": allRecordTypes + ["SPF"],
        "vercel": allRecordTypes,
        "volcengine": commonRecordTypes,
        "west": commonRecordTypes,
        "callback": ["A", "AAAA"],
    ]
    static let secretOnlyProviders: Set<String> = [
        "cloudflare", "namesilo", "desec", "dynadot", "dynv6", "freemyip", "duckdns", "vercel",
    ]

    static func recordTypeOptions(_ provider: String) -> [SslOption] {
        (typesByProvider[provider] ?? ["A", "AAAA"]).map { value in
            let label = value == "ALIESAIPS" ? "A / AAAA" : (value == "ALIESACNAME" ? "CNAME" : value)
            return SslOption(label: label, value: value)
        }
    }

    static var newRecord: JSONObject {
        JSONObject([
            ("Key", .string("")),
            ("Disable", .bool(false)),
            ("SyncRecordData", .object(JSONObject([
                ("remark", .string("")), ("fullDomainName", .string("")),
                ("type", .string("AAAA")), ("ipv4Address", .string("{ipv4Addr}")),
                ("ipv6Address", .string("{ipv6Addr}")), ("CNAMEContent", .string("")),
                ("TXTContent", .string("")), ("SPFContent", .string("")),
                ("CAAContent", .string("")), ("NSContent", .string("")),
                ("MXContent", .string("")), ("SRVContent", .string("")),
                ("SVCBContent", .string("")), ("HTTPSContent", .string("")),
                ("AliESAIPS", .string("{ipv6Addr}")), ("ttl", .int(0)),
                ("line", .string("")), ("proxyStatus", .bool(false)),
                ("specifyProxyStatus", .string("")), ("BizName", .string("web")),
                ("AliESABizName", .string("web")), ("AliESASourceType", .string("Domain")),
                ("AliESAHostPolicy", .string("follow_hostname")),
            ]))),
        ])
    }

    static func newRecord(type: String) -> JSONObject {
        var result = newRecord
        set(&result, "SyncRecordData.type", .string(type))
        return result
    }

    static var newTask: JSONObject {
        let v4 = ["https://ddns.oray.com/checkip", "http://v4.66666.host:66/ip",
                  "https://myip.ipip.net", "https://4.ipw.cn", "https://ip.3322.net"]
        let v6 = ["http://v6.66666.host:66/ip", "http://myip6.ipip.net", "https://6.ipw.cn"]
        return JSONObject([
            ("TaskName", .string("")), ("TaskKey", .string("")), ("TaskType", .string("IPv6")),
            ("Enable", .bool(true)), ("Expanded", .bool(true)), ("IPSectionExpanded", .bool(true)),
            ("DiaglogShowMode", .string("simple")), ("DebugMode", .bool(false)),
            ("HttpClientTimeout", .int(15)), ("InsecureSkipVerify", .bool(false)),
            ("FirstCheckDelay", .int(16)), ("Intervals", .int(36)), ("TTL", .string("")),
            ("DNS", .object(JSONObject([
                ("Name", .string("alidns")), ("ID", .string("")), ("Secret", .string("")),
                ("ForceInterval", .int(3600)), ("ResolverDoaminCheck", .bool(true)),
                ("HttpClientProxyType", .string("")), ("HttpClientProxyAddr", .string("")),
                ("HttpClientProxyUser", .string("")), ("HttpClientProxyPassword", .string("")),
                ("CallAPINetwork", .string("")),
                ("Callback", .object(JSONObject([
                    ("URL", .string("")), ("Method", .string("get")), ("Headers", .array([])),
                    ("RequestBody", .string("")), ("Server", .string("other")),
                    ("DisableCallbackSuccessContentCheck", .bool(false)),
                    ("CallbackSuccessContent", .array([])),
                ]))),
            ]))),
            ("V4QueryIPEnable", .bool(false)), ("V4QueryIPType", .string("url")),
            ("V4QueryUrl", .array(v4.map(JSONValue.string))), ("V4NetInterface", .string("")),
            ("V4NetInterfaceIPReg", .string("")), ("V4GetIPScript", .string("")),
            ("V6QueryIPEnable", .bool(false)), ("V6QueryIPType", .string("url")),
            ("V6QueryUrl", .array(v6.map(JSONValue.string))), ("V6NetInterface", .string("")),
            ("V6NetInterfaceIPReg", .string("")), ("V6GetIPScript", .string("")),
            ("V6DUID", .string("")), ("Records", .array([])), ("GlobalWebhook", .bool(false)),
            ("WebhookEnable", .bool(false)), ("IngoreWebhookVariablesNotFound", .bool(false)),
            ("IngoreWebhookVariablesNotFoundList", .string("")), ("WebhookURL", .string("")),
            ("WebhookMethod", .string("get")), ("WebhookHeaders", .array([])),
            ("WebhookRequestBody", .string("")),
            ("WebhookDisableCallbackSuccessContentCheck", .bool(false)),
            ("WebhookSuccessContent", .array([])), ("WebhookProxy", .string("")),
            ("WebhookProxyAddr", .string("")), ("WebhookProxyUser", .string("")),
            ("WebhookProxyPassword", .string("")), ("RetryCount", .int(0)),
            ("RetryInterval", .int(500)),
        ])
    }

    static var newSettings: JSONObject {
        JSONObject([
            ("Enable", .bool(true)), ("CustomDomainSuffix", .string("")),
            ("WebhookEnable", .bool(false)), ("WebhookURL", .string("")),
            ("WebhookMethod", .string("get")), ("WebhookHeaders", .array([])),
            ("WebhookRequestBody", .string("")), ("WebhookProxy", .string("")),
            ("WebhookProxyAddr", .string("")), ("WebhookProxyUser", .string("")),
            ("WebhookProxyPassword", .string("")),
            ("WebhookDisableCallbackSuccessContentCheck", .bool(false)),
            ("WebhookSuccessContent", .array([])), ("RetryCount", .int(0)),
            ("RetryInterval", .int(500)),
        ])
    }

    static func normalizeTask(_ value: JSONObject) -> JSONObject {
        var result = merge(newTask, value)
        if text(result["DiaglogShowMode"]).isEmpty { result["DiaglogShowMode"] = .string("simple") }
        if let records = value["Records"], records.arrayValue != nil {
            result["Records"] = records
        } else {
            result["Records"] = .array([])
        }
        return result
    }

    static func normalizeSettings(_ value: JSONObject) -> JSONObject { merge(newSettings, value) }

    static func normalizeRecord(_ value: JSONObject) -> JSONObject {
        if let data = value["SyncRecordData"]?.objectValue {
            let type = text(data["type"])
            return merge(newRecord(type: type.isEmpty ? "AAAA" : type), value)
        }
        let domain = text(value["DomainName"] ?? value["Domain"])
        let subdomain = text(value["SubDomain"])
        let full = !subdomain.isEmpty && subdomain != "@" ? "\(subdomain).\(domain)" : domain
        var result = newRecord(type: text(value["Type"]).isEmpty ? "AAAA" : text(value["Type"]))
        result["Key"] = value["Key"] ?? .string("")
        result["Disable"] = .bool(value["Enable"]?.boolValue == false)
        set(&result, "SyncRecordData.fullDomainName", .string(full))
        set(&result, "SyncRecordData.remark", .string(text(value["Remark"])))
        set(&result, "SyncRecordData.line", .string(text(value["Line"])))
        return result
    }

    static func merge(_ defaults: JSONObject, _ value: JSONObject) -> JSONObject {
        var result = defaults
        for (key, next) in value.pairs {
            if let left = result[key]?.objectValue, let right = next.objectValue {
                result[key] = .object(merge(left, right))
            } else {
                result[key] = next
            }
        }
        return result
    }

    static func get(_ value: JSONObject, _ path: String) -> JSONValue? {
        var current = JSONValue.object(value)
        for component in path.split(separator: ".").map(String.init) {
            guard let next = current[component] else { return nil }
            current = next
        }
        return current
    }

    static func set(_ value: inout JSONObject, _ path: String, _ next: JSONValue) {
        value = setting(value, ArraySlice(path.split(separator: ".").map(String.init)), next)
    }

    private static func setting(_ value: JSONObject, _ path: ArraySlice<String>,
                                _ next: JSONValue) -> JSONObject {
        guard let head = path.first else { return value }
        var result = value
        if path.count == 1 {
            result[head] = next
        } else {
            let child = result[head]?.record ?? JSONObject()
            result[head] = .object(setting(child, path.dropFirst(), next))
        }
        return result
    }

    static func text(_ value: JSONValue?) -> String {
        guard let value else { return "" }
        switch value {
        case .string, .number: return value.asDisplayString
        default: return ""
        }
    }

    static func bool(_ value: JSONValue?) -> Bool { value?.boolValue == true }

    static func lines(_ value: JSONValue?) -> [String] {
        let source = value?.arrayValue?.map(\.asDisplayString) ?? value.map { text($0).jsLines } ?? []
        return source.map(\.jsTrimmed).filter { !$0.isEmpty }
    }

    static func contentKey(_ type: String) -> String {
        switch type {
        case "A": "ipv4Address"
        case "AAAA": "ipv6Address"
        case "ALIESAIPS": "AliESAIPS"
        default: "\(type.replacingOccurrences(of: "ALIESACNAME", with: "CNAME"))Content"
        }
    }

    static func validateRecord(_ value: JSONObject) throws -> JSONObject {
        var result = normalizeRecord(value)
        let data = get(result, "SyncRecordData")?.record ?? JSONObject()
        let domain = text(data["fullDomainName"]).jsTrimmed
        guard !domain.isEmpty else { throw DdnsFormError(message: "请填写完整域名") }
        let type = text(data["type"])
        let key = contentKey(type)
        guard !text(data[key]).jsTrimmed.isEmpty else {
            throw DdnsFormError(message: "请填写 \(type) 记录内容")
        }
        try integer(&result, "SyncRecordData.ttl", 0...86400, "记录 TTL")
        return result
    }

    static func validateTask(_ value: JSONObject) throws -> JSONObject {
        var result = normalizeTask(value)
        var dns = result["DNS"]?.record ?? JSONObject()
        let provider = text(dns["Name"])
        guard !provider.isEmpty else { throw DdnsFormError(message: "请选择 DNS 服务商") }
        if provider == "callback" {
            let callback = dns["Callback"]?.record ?? JSONObject()
            guard !text(callback["URL"]).jsTrimmed.isEmpty,
                  !text(callback["Method"]).jsTrimmed.isEmpty else {
                throw DdnsFormError(message: "请填写自定义回调地址和请求方法")
            }
            if !bool(callback["DisableCallbackSuccessContentCheck"]),
               lines(callback["CallbackSuccessContent"]).isEmpty {
                throw DdnsFormError(message: "请填写回调成功响应关键字")
            }
        } else if secretOnlyProviders.contains(provider) {
            guard !text(dns["Secret"]).jsTrimmed.isEmpty else {
                throw DdnsFormError(message: "请填写服务商密钥或 Token")
            }
        } else if text(dns["ID"]).jsTrimmed.isEmpty || text(dns["Secret"]).jsTrimmed.isEmpty {
            throw DdnsFormError(message: "请填写服务商账号 ID 和密钥")
        }
        if !text(dns["HttpClientProxyType"]).isEmpty,
           text(dns["HttpClientProxyAddr"]).jsTrimmed.isEmpty {
            throw DdnsFormError(message: "请填写 DNS 请求代理地址")
        }
        try integer(&result, "DNS.ForceInterval", 60...86400, "强制同步周期")
        try integer(&result, "FirstCheckDelay", 0...3600, "首次检测延迟")
        try integer(&result, "Intervals", 30...3600, "检测间隔")
        try integer(&result, "HttpClientTimeout", 1...300, "请求超时")
        for version in ["V4", "V6"] where bool(result["\(version)QueryIPEnable"]) {
            let label = version == "V4" ? "IPv4" : "IPv6"
            let mode = text(result["\(version)QueryIPType"])
            guard !mode.isEmpty else { throw DdnsFormError(message: "请选择 \(label) 获取方式") }
            if mode == "url", lines(result["\(version)QueryUrl"]).isEmpty {
                throw DdnsFormError(message: "请填写 \(label) 查询地址")
            }
            if mode == "netInterface", text(result["\(version)NetInterface"]).jsTrimmed.isEmpty {
                throw DdnsFormError(message: "请填写或选择网卡")
            }
            if mode == "command", text(result["\(version)GetIPScript"]).jsTrimmed.isEmpty {
                throw DdnsFormError(message: "请填写获取 IP 的命令")
            }
            if mode == "odhcpdfile", text(result["V6DUID"]).jsTrimmed.isEmpty {
                throw DdnsFormError(message: "请选择 odhcpd 客户端")
            }
            result["\(version)QueryUrl"] = .array(lines(result["\(version)QueryUrl"]).map(JSONValue.string))
        }
        let records = result["Records"]?.arrayValue ?? []
        result["Records"] = .array(try records.map { .object(try validateRecord($0.record)) })
        try validateWebhook(&result)
        dns = result["DNS"]?.record ?? dns
        var callback = dns["Callback"]?.record ?? JSONObject()
        callback["Headers"] = .array(lines(callback["Headers"]).map(JSONValue.string))
        callback["CallbackSuccessContent"] = .array(
            lines(callback["CallbackSuccessContent"]).map(JSONValue.string)
        )
        if text(callback["Method"]) == "get" { callback["RequestBody"] = .string("") }
        dns["Callback"] = .object(callback)
        result["DNS"] = .object(dns)
        return result
    }

    static func validateSettings(_ value: JSONObject) throws -> JSONObject {
        var result = normalizeSettings(value)
        result["CustomDomainSuffix"] = .string(lines(result["CustomDomainSuffix"]).joined(separator: "\n"))
        try validateWebhook(&result)
        return result
    }

    private static func validateWebhook(_ value: inout JSONObject) throws {
        guard bool(value["WebhookEnable"]) else { return }
        guard !text(value["WebhookURL"]).jsTrimmed.isEmpty else {
            throw DdnsFormError(message: "请填写 Webhook 地址")
        }
        guard !text(value["WebhookMethod"]).jsTrimmed.isEmpty else {
            throw DdnsFormError(message: "请选择 Webhook 请求方法")
        }
        let proxy = text(value["WebhookProxy"])
        if !proxy.isEmpty, proxy != "dns", text(value["WebhookProxyAddr"]).jsTrimmed.isEmpty {
            throw DdnsFormError(message: "请填写 Webhook 代理地址")
        }
        if !bool(value["WebhookDisableCallbackSuccessContentCheck"]),
           lines(value["WebhookSuccessContent"]).isEmpty {
            throw DdnsFormError(message: "请填写 Webhook 成功响应关键字，或开启跳过响应检查")
        }
        try integer(&value, "RetryCount", 0...10, "Webhook 重试次数")
        if (value["RetryCount"]?.asInt ?? 0) > 0 {
            try integer(&value, "RetryInterval", 500...10000, "Webhook 重试间隔")
        }
        value["WebhookHeaders"] = .array(lines(value["WebhookHeaders"]).map(JSONValue.string))
        value["WebhookSuccessContent"] = .array(lines(value["WebhookSuccessContent"]).map(JSONValue.string))
        if text(value["WebhookMethod"]) == "get" { value["WebhookRequestBody"] = .string("") }
    }

    private static func integer(_ value: inout JSONObject, _ path: String,
                                _ range: ClosedRange<Int>, _ label: String) throws {
        let raw = get(value, path)
        let parsed: Double?
        if let number = raw?.doubleValue {
            parsed = number
        } else {
            parsed = Double(text(raw).jsTrimmed)
        }
        guard let parsed, parsed.isFinite, parsed.rounded() == parsed,
              parsed >= Double(range.lowerBound), parsed <= Double(range.upperBound) else {
            throw DdnsFormError(message: "\(label)应为 \(range.lowerBound)～\(range.upperBound) 的整数")
        }
        set(&value, path, .int(Int(parsed)))
    }
}

private struct DdnsSection<Content: View>: View {
    var title: String
    var symbol: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        LuckyCard(spacing: LuckyTheme.Space.m) {
            HStack(spacing: LuckyTheme.Space.s) {
                LuckyIconTile(symbol: symbol, size: 30, glyph: 13, role: .ddns)
                Text(title)
                    .font(LuckyTheme.Text.cardTitle)
                    .foregroundStyle(LuckyTheme.textPrimary)
            }
            LuckyHairline()
            content()
        }
    }
}

private struct DdnsInput: View {
    var label: String
    @Binding var text: String
    var placeholder: String = ""
    var multiline = false
    var secure = false
    var numeric = false
    var required = false
    var disabled = false

    var body: some View {
        LuckyTextField(label: required ? "\(label) *" : label, text: $text,
                       placeholder: placeholder, mono: true, secure: secure,
                       multiline: multiline,
                       keyboard: numeric ? .numbersAndPunctuation : .default)
            .disabled(disabled)
            .opacity(disabled ? 0.55 : 1)
    }
}

private struct DdnsChoice: View {
    var label: String
    var options: [SslOption]
    var current: String
    var disabled = false
    var choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.xs) {
            LuckyFieldLabel(label: label)
            Menu {
                ForEach(options) { option in
                    Button {
                        choose(option.value)
                    } label: {
                        if option.value == current {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: LuckyTheme.Space.s) {
                    Text(options.first(where: { $0.value == current })?.label
                         ?? (current.isEmpty ? "请选择" : current))
                        .font(LuckyTheme.Text.body)
                        .foregroundStyle(LuckyTheme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LuckyFunctionIcon(symbol: "chevron.up.chevron.down", size: 24, glyph: 10,
                                      color: LuckyTheme.idle)
                }
                .padding(.horizontal, LuckyTheme.Space.m)
                .frame(height: LuckyTheme.Space.touchTarget)
                .background(AdvancedField.box)
                .overlay(AdvancedField.stroke)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
        .opacity(disabled ? 0.55 : 1)
    }
}

private struct DdnsRecordRequest: Identifiable {
    var id = UUID()
    var index: Int
    var value: JSONObject
}

struct DdnsTaskEditor: View {
    var request: ServiceEditorRequest
    var saving: Bool
    var close: () -> Void
    var save: (JSONObject) -> Void

    @State private var task: JSONObject
    @State private var recordEditor: DdnsRecordRequest?
    @State private var failure = ""
    @State private var result = ""
    @State private var actionBusy = false
    @State private var clients: [JSONValue] = []
    @State private var clientsFailure = ""

    static var newTaskValue: JSONObject { DdnsForm.newTask }

    static func duplicatedValue(_ source: JSONObject) -> JSONObject {
        var value = DdnsForm.normalizeTask(source)
        value["TaskKey"] = .string("")
        let name = DdnsForm.text(value["TaskName"])
        value["TaskName"] = .string("\(name.isEmpty ? "DDNS 任务" : name) - 副本")
        if let records = value["Records"]?.arrayValue {
            value["Records"] = .array(records.map { record in
                var copy = record.record
                copy["Key"] = .string("")
                return .object(copy)
            })
        }
        return value
    }

    init(request: ServiceEditorRequest, saving: Bool,
         close: @escaping () -> Void, save: @escaping (JSONObject) -> Void) {
        self.request = request
        self.saving = saving
        self.close = close
        self.save = save
        let normalized = DdnsForm.normalizeTask(request.value)
        _task = State(initialValue: normalized)
        if let requested = request.openRecord {
            let records = normalized["Records"]?.arrayValue ?? []
            let index = requested == "new" ? records.count : records.firstIndex(where: {
                DdnsForm.text($0["Key"]) == requested
            }) ?? records.count
            let value = index < records.count
                ? DdnsForm.normalizeRecord(records[index].record)
                : DdnsForm.newRecord(type: DdnsForm.text(normalized["TaskType"]) == "IPv4" ? "A" : "AAAA")
            _recordEditor = State(initialValue: DdnsRecordRequest(index: index, value: value))
        }
    }

    private var busy: Bool { saving || actionBusy }
    private var records: [JSONValue] { task["Records"]?.arrayValue ?? [] }
    private var provider: String { DdnsForm.text(DdnsForm.get(task, "DNS.Name")) }
    private var customMode: Bool { DdnsForm.text(task["DiaglogShowMode"]) == "diy" }
    private var clientsTaskID: String {
        "\(DdnsForm.bool(task["V6QueryIPEnable"]))|\(DdnsForm.text(task["V6QueryIPType"]))"
    }

    @ViewBuilder
    var body: some View {
        if let recordEditor {
            DdnsRecordEditor(title: recordEditor.index < records.count ? "编辑 DNS 记录" : "添加 DNS 记录",
                             initial: recordEditor.value, provider: provider, busy: saving) {
                self.recordEditor = nil
            } save: { value in
                commitRecord(value, at: recordEditor.index)
            }
        } else {
            taskSheet
        }
    }

    private var taskSheet: some View {
        ServiceSheet(title: request.title, close: close) {
            LuckyPillButton(title: saving ? "保存中" : (request.key.isEmpty ? "添加任务" : "保存任务"),
                            symbol: "checkmark", prominent: true, loading: saving) {
                submit()
            }
            .disabled(busy)
        } content: {
            if !failure.isEmpty { LuckyErrorCard(message: failure, title: "配置错误") }
            if !result.isEmpty { resultCard }
            taskSection
            providerSection
            ipSection
            recordsSection
            notificationSection
        }
        .task(id: clientsTaskID) { await loadClientsIfNeeded() }
    }

    private var resultCard: some View {
        LuckyCard(spacing: LuckyTheme.Space.s) {
            Text("测试结果")
                .font(LuckyTheme.Text.captionMedium)
                .foregroundStyle(LuckyTheme.success)
            LuckyCodeBlock(text: result, maxHeight: 220)
        }
    }

    private var taskSection: some View {
        DdnsSection(title: "任务设置", symbol: "slider.horizontal.3") {
            field("任务名称", "TaskName", placeholder: "可留空")
            toggle("启用任务", "Enable")
            choice("配置模式", "DiaglogShowMode", [
                SslOption(label: "简易模式", value: "simple"),
                SslOption(label: "定制模式", value: "diy"),
            ])
            choice("任务类型", "TaskType", [
                SslOption(label: "IPv4", value: "IPv4"),
                SslOption(label: "IPv6", value: "IPv6"),
            ])
            field("首次检测延迟（0～3600 秒）", "FirstCheckDelay", numeric: true)
            field("检测间隔（30～3600 秒）", "Intervals", numeric: true)
            if customMode {
                toggle("调试日志", "DebugMode")
                field("HTTP 请求超时（秒）", "HttpClientTimeout", numeric: true)
                toggle("跳过 HTTPS 证书校验", "InsecureSkipVerify")
            }
        }
    }

    @ViewBuilder
    private var providerSection: some View {
        let callback = DdnsForm.get(task, "DNS.Callback")?.record ?? JSONObject()
        DdnsSection(title: "DNS 服务商", symbol: "globe.asia.australia") {
            choice("服务商", "DNS.Name", DdnsForm.providers)
            if provider == "callback" {
                choice("回调服务", "DNS.Callback.Server", [
                    SslOption(label: "自定义", value: "other"), SslOption(label: "No-IP", value: "noip"),
                    SslOption(label: "Dynu", value: "dynu"), SslOption(label: "公云 3322", value: "pubyun"),
                ])
                field("回调地址", "DNS.Callback.URL", required: true)
                choice("回调方法", "DNS.Callback.Method", Self.httpMethods)
                field("回调请求头（每行一项）", "DNS.Callback.Headers", multiline: true)
                if DdnsForm.text(callback["Method"]) != "get" {
                    field("回调请求内容", "DNS.Callback.RequestBody", multiline: true)
                }
                toggle("跳过回调响应检查", "DNS.Callback.DisableCallbackSuccessContentCheck")
                if !DdnsForm.bool(callback["DisableCallbackSuccessContentCheck"]) {
                    field("回调成功关键字", "DNS.Callback.CallbackSuccessContent",
                          multiline: true, required: true)
                }
            } else {
                if !DdnsForm.secretOnlyProviders.contains(provider) {
                    field("账号 / Access Key ID", "DNS.ID", required: true)
                }
                field("密钥 / Token", "DNS.Secret", secure: true, required: true)
            }
            field("强制同步周期（60～86400 秒）", "DNS.ForceInterval", numeric: true)
            toggle("同步后校验 DNS 解析", "DNS.ResolverDoaminCheck")
            if customMode {
                choice("请求网络", "DNS.CallAPINetwork", [
                    SslOption(label: "自动", value: ""), SslOption(label: "IPv4", value: "tcp4"),
                    SslOption(label: "IPv6", value: "tcp6"),
                ])
                choice("DNS 请求代理", "DNS.HttpClientProxyType", Self.proxyOptions)
                if !DdnsForm.text(DdnsForm.get(task, "DNS.HttpClientProxyType")).isEmpty {
                    field("代理地址", "DNS.HttpClientProxyAddr", required: true)
                    field("代理账号", "DNS.HttpClientProxyUser")
                    field("代理密码", "DNS.HttpClientProxyPassword", secure: true)
                }
            }
        }
    }

    private var ipSection: some View {
        DdnsSection(title: "公网 IP", symbol: "network") {
            DdnsIpSource(version: "V4", task: $task, clients: clients, busy: busy, run: runTest)
            LuckyHairline()
            DdnsIpSource(version: "V6", task: $task, clients: clients, busy: busy, run: runTest)
            if !clientsFailure.isEmpty { LuckyErrorCard(message: clientsFailure) }
        }
    }

    private var recordsSection: some View {
        DdnsSection(title: "DNS 记录 · \(records.count) 项", symbol: "list.bullet.rectangle") {
            if records.isEmpty {
                Text("尚未添加 DNS 记录")
                    .font(LuckyTheme.Text.body)
                    .foregroundStyle(LuckyTheme.textSecondary)
            } else {
                ForEach(records.indices, id: \.self) { index in
                    if index > 0 { LuckyHairline() }
                    recordRow(records[index], index)
                }
            }
            ServiceActionButton(title: "添加 DNS 记录", symbol: LuckySymbol.add,
                                fill: .tinted, height: 42, disabled: busy) {
                addRecord()
            }
        }
    }

    private func recordRow(_ record: JSONValue, _ index: Int) -> some View {
        let data = record["SyncRecordData"]?.record ?? JSONObject()
        let name = DdnsForm.text(data["remark"])
        let type = DdnsForm.text(data["type"])
        let domain = DdnsForm.text(data["fullDomainName"])
        return VStack(alignment: .leading, spacing: LuckyTheme.Space.s) {
            HStack(spacing: LuckyTheme.Space.s) {
                LuckyIconTile(symbol: "globe", size: 28, glyph: 12, role: .ddns)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? "记录 \(index + 1)" : name)
                        .font(LuckyTheme.Text.label)
                        .foregroundStyle(LuckyTheme.textPrimary)
                    Text("\(type) · \(domain.isEmpty ? "未填写域名" : domain) · \(DdnsForm.bool(record["Disable"]) ? "已停用" : "已启用")")
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            HStack(spacing: LuckyTheme.Space.s) {
                ServiceActionButton(title: "编辑", symbol: LuckySymbol.edit, fill: .muted,
                                    height: 38, disabled: busy) { editRecord(index) }
                ServiceActionButton(title: "复制", symbol: LuckySymbol.copy, fill: .muted,
                                    height: 38, disabled: busy) { duplicateRecord(index) }
                ServiceActionButton(title: "删除", symbol: LuckySymbol.delete, tone: .danger,
                                    fill: .soft, height: 38, disabled: busy) { removeRecord(index) }
            }
        }
        .padding(.vertical, LuckyTheme.Space.xs)
    }

    private var notificationSection: some View {
        DdnsSection(title: "通知", symbol: "arrow.triangle.branch") {
            toggle("使用全局 Webhook", "GlobalWebhook")
            DdnsWebhookFields(value: $task, busy: busy) {
                runTest { try await DdnsService.testWebhook(DdnsForm.text(task["TaskKey"]).isEmpty
                                                            ? "666" : DdnsForm.text(task["TaskKey"]),
                                                            .object(task)) }
            }
            if DdnsForm.bool(task["WebhookEnable"]) || DdnsForm.bool(task["GlobalWebhook"]) {
                toggle("忽略未找到的 Webhook 变量", "IngoreWebhookVariablesNotFound")
                if DdnsForm.bool(task["IngoreWebhookVariablesNotFound"]) {
                    field("忽略变量列表", "IngoreWebhookVariablesNotFoundList", multiline: true)
                }
            }
        }
    }

    private func field(_ label: String, _ path: String, placeholder: String = "",
                       multiline: Bool = false, secure: Bool = false,
                       numeric: Bool = false, required: Bool = false) -> some View {
        DdnsInput(label: label, text: textBinding(path), placeholder: placeholder,
                  multiline: multiline, secure: secure, numeric: numeric,
                  required: required, disabled: busy)
    }

    private func toggle(_ label: String, _ path: String) -> some View {
        LuckyToggleRow(label: label, isOn: boolBinding(path))
            .disabled(busy)
            .opacity(busy ? 0.55 : 1)
    }

    private func choice(_ label: String, _ path: String, _ options: [SslOption]) -> some View {
        DdnsChoice(label: label, options: options, current: DdnsForm.text(DdnsForm.get(task, path)),
                   disabled: busy) { value in
            DdnsForm.set(&task, path, .string(value))
        }
    }

    private func textBinding(_ path: String) -> Binding<String> {
        Binding(get: {
            let value = DdnsForm.get(task, path)
            return value?.arrayValue?.map(\.asDisplayString).joined(separator: "\n") ?? DdnsForm.text(value)
        }, set: { DdnsForm.set(&task, path, .string($0)) })
    }

    private func boolBinding(_ path: String) -> Binding<Bool> {
        Binding(get: { DdnsForm.bool(DdnsForm.get(task, path)) },
                set: { DdnsForm.set(&task, path, .bool($0)) })
    }

    private func submit() {
        do {
            failure = ""
            save(try DdnsForm.validateTask(task))
        } catch {
            failure = error.localizedDescription
        }
    }

    private func addRecord() {
        let type = DdnsForm.text(task["TaskType"]) == "IPv4" ? "A" : "AAAA"
        recordEditor = DdnsRecordRequest(index: records.count, value: DdnsForm.newRecord(type: type))
        failure = ""
    }

    private func editRecord(_ index: Int) {
        guard index < records.count else { return }
        recordEditor = DdnsRecordRequest(index: index, value: DdnsForm.normalizeRecord(records[index].record))
        failure = ""
    }

    private func duplicateRecord(_ index: Int) {
        guard index < records.count else { return }
        var copy = DdnsForm.normalizeRecord(records[index].record)
        copy["Key"] = .string("")
        let old = DdnsForm.text(DdnsForm.get(copy, "SyncRecordData.remark"))
        DdnsForm.set(&copy, "SyncRecordData.remark",
                     .string("\(old.isEmpty ? "记录 \(index + 1)" : old) - 副本"))
        var next = records
        next.append(.object(copy))
        task["Records"] = .array(next)
    }

    private func removeRecord(_ index: Int) {
        guard index < records.count else { return }
        var next = records
        next.remove(at: index)
        task["Records"] = .array(next)
    }

    private func commitRecord(_ value: JSONObject, at index: Int) {
        var next = records
        if index < next.count { next[index] = .object(value) } else { next.append(.object(value)) }
        task["Records"] = .array(next)
        recordEditor = nil
        failure = ""
    }

    private func runTest(_ action: @escaping () async throws -> JSONValue) {
        guard !busy else { return }
        Task {
            actionBusy = true
            failure = ""
            result = ""
            defer { actionBusy = false }
            do {
                let output = try await action()
                result = ServiceRecord.resultText(output)
                if result.isEmpty { result = "测试成功" }
            } catch {
                guard !error.isCancellation else { return }
                failure = error.luckyMessage("测试失败")
            }
        }
    }

    private func loadClientsIfNeeded() async {
        guard DdnsForm.bool(task["V6QueryIPEnable"]),
              DdnsForm.text(task["V6QueryIPType"]) == "odhcpdfile" else { return }
        do {
            let payload = try await DdnsService.odhcpdClients()
            clients = ServiceRecord.recordList(payload, ["clients", "list", "data", "result"])
            clientsFailure = ""
        } catch {
            guard !error.isCancellation else { return }
            clientsFailure = error.luckyMessage("无法读取 odhcpd 客户端")
        }
    }

    private static let httpMethods = ["get", "post", "put", "patch"].map {
        SslOption(label: $0.uppercased(), value: $0)
    }
    private static let proxyOptions = [
        SslOption(label: "不使用", value: ""), SslOption(label: "HTTP", value: "http"),
        SslOption(label: "HTTPS", value: "https"), SslOption(label: "SOCKS5", value: "socks5"),
    ]
}

private struct DdnsIpSource: View {
    var version: String
    @Binding var task: JSONObject
    var clients: [JSONValue]
    var busy: Bool
    var run: (@escaping () async throws -> JSONValue) -> Void

    private var label: String { version == "V4" ? "IPv4" : "IPv6" }
    private var mode: String { DdnsForm.text(task["\(version)QueryIPType"]) }
    private var enabled: Binding<Bool> {
        Binding(get: { DdnsForm.bool(task["\(version)QueryIPEnable"]) },
                set: { task["\(version)QueryIPEnable"] = .bool($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.m) {
            LuckyToggleRow(label: "启用 {\(label.lowercased())Addr}", isOn: enabled)
                .disabled(busy)
            if enabled.wrappedValue {
                DdnsChoice(label: "\(label) 获取方式", options: options, current: mode,
                           disabled: busy) { task["\(version)QueryIPType"] = .string($0) }
                if mode == "url" {
                    input("查询网址（每行一项）", "\(version)QueryUrl", multiline: true, required: true)
                } else if mode == "netInterface" {
                    input("网卡名称", "\(version)NetInterface", required: true)
                    input("IP 地址匹配表达式", "\(version)NetInterfaceIPReg", multiline: true)
                    testButton("测试匹配") {
                        try await DdnsService.testIpRule(
                            iptype: label,
                            netinterface: DdnsForm.text(task["\(version)NetInterface"]),
                            ipreg: DdnsForm.text(task["\(version)NetInterfaceIPReg"])
                        )
                    }
                } else if mode == "command" {
                    input("获取 IP 的命令", "\(version)GetIPScript", multiline: true, required: true)
                    testButton("测试命令") {
                        try await DdnsService.testIpCommand(
                            iptype: label,
                            command: DdnsForm.text(task["\(version)GetIPScript"])
                        )
                    }
                } else if mode == "odhcpdfile" {
                    DdnsChoice(label: "odhcpd 客户端", options: clientOptions,
                               current: DdnsForm.text(task["V6DUID"]), disabled: busy) {
                        task["V6DUID"] = .string($0)
                    }
                }
            }
        }
    }

    private var options: [SslOption] {
        var result = [
            SslOption(label: "查询网址", value: "url"),
            SslOption(label: "网卡地址", value: "netInterface"),
            SslOption(label: "执行命令", value: "command"),
        ]
        if version == "V6" { result.append(SslOption(label: "odhcpd 客户端", value: "odhcpdfile")) }
        return result
    }

    private var clientOptions: [SslOption] {
        clients.enumerated().map { index, client in
            let duid = DdnsForm.text(client["DUID"])
            let name = DdnsForm.text(client["Name"])
            let address = DdnsForm.text(client["IPv6Addr"])
            return SslOption(label: "\(name.isEmpty ? "客户端" : name) · \(address)",
                             value: duid.isEmpty ? String(index) : duid)
        }
    }

    private func input(_ label: String, _ key: String, multiline: Bool = false,
                       required: Bool = false) -> some View {
        DdnsInput(label: label, text: Binding(
            get: {
                task[key]?.arrayValue?.map(\.asDisplayString).joined(separator: "\n")
                    ?? DdnsForm.text(task[key])
            }, set: { task[key] = .string($0) }
        ), multiline: multiline, required: required, disabled: busy)
    }

    private func testButton(_ title: String,
                            action: @escaping () async throws -> JSONValue) -> some View {
        ServiceActionButton(title: title, symbol: "testtube.2", fill: .tinted,
                            height: 42, disabled: busy) { run(action) }
    }
}

private struct DdnsRecordEditor: View {
    var title: String
    var provider: String
    var busy: Bool
    var close: () -> Void
    var save: (JSONObject) -> Void

    @State private var value: JSONObject
    @State private var failure = ""

    init(title: String, initial: JSONObject, provider: String, busy: Bool,
        close: @escaping () -> Void, save: @escaping (JSONObject) -> Void) {
        self.title = title
        self.provider = provider
        self.busy = busy
        self.close = close
        self.save = save
        _value = State(initialValue: DdnsForm.normalizeRecord(initial))
    }

    private var type: String { DdnsForm.text(DdnsForm.get(value, "SyncRecordData.type")) }
    private var contentKey: String { DdnsForm.contentKey(type) }

    var body: some View {
        ServiceSheet(title: title, close: close) {
            LuckyPillButton(title: "返回", symbol: "chevron.left") { close() }
                .disabled(busy)
            LuckyPillButton(title: "保存记录", symbol: "checkmark", prominent: true) {
                submit()
            }
            .disabled(busy)
        } content: {
            if !failure.isEmpty { LuckyErrorCard(message: failure, title: "记录配置错误") }
            DdnsSection(title: "DNS 记录", symbol: "globe") {
                field("备注", "SyncRecordData.remark")
                field("完整域名", "SyncRecordData.fullDomainName",
                      placeholder: "例如 home.example.com", multiline: true, required: true)
                LuckyToggleRow(label: "启用同步", isOn: Binding(
                    get: { !DdnsForm.bool(value["Disable"]) },
                    set: { value["Disable"] = .bool(!$0) }
                ))
                .disabled(busy)
                DdnsChoice(label: "记录类型", options: DdnsForm.recordTypeOptions(provider),
                           current: type, disabled: busy) {
                    DdnsForm.set(&value, "SyncRecordData.type", .string($0))
                }
                field("\(type) 记录内容", "SyncRecordData.\(contentKey)",
                      placeholder: type == "A" ? "{ipv4Addr}" : (type == "AAAA" ? "{ipv6Addr}" : ""),
                      multiline: ["A", "AAAA", "TXT", "SPF", "SVCB", "HTTPS", "SRV"].contains(type),
                      required: true)
                field("TTL（0 为自动）", "SyncRecordData.ttl", numeric: true)
                field("解析线路（留空为默认）", "SyncRecordData.line")
                providerFields
            }
        }
    }

    @ViewBuilder
    private var providerFields: some View {
        if provider == "cloudflare", ["A", "AAAA", "CNAME"].contains(type) {
            toggle("指定 Cloudflare 代理状态", "SyncRecordData.specifyProxyStatus")
            if DdnsForm.bool(DdnsForm.get(value, "SyncRecordData.specifyProxyStatus")) {
                toggle("启用 Cloudflare 代理", "SyncRecordData.proxyStatus")
            }
        }
        if provider == "aliesa", ["ALIESAIPS", "ALIESACNAME"].contains(type) {
            toggle("启用 ESA 代理", "SyncRecordData.proxyStatus")
            if DdnsForm.bool(DdnsForm.get(value, "SyncRecordData.proxyStatus")) {
                choice("业务类型", "SyncRecordData.AliESABizName", [
                    SslOption(label: "图片与视频", value: "image_video"),
                    SslOption(label: "API", value: "api"), SslOption(label: "Web", value: "web"),
                ])
                if type == "ALIESACNAME" {
                    choice("源站类型", "SyncRecordData.AliESASourceType", [
                        SslOption(label: "OSS", value: "OSS"), SslOption(label: "S3", value: "S3"),
                        SslOption(label: "负载均衡", value: "LB"), SslOption(label: "源站池", value: "OP"),
                        SslOption(label: "域名", value: "Domain"),
                    ])
                    choice("主机策略", "SyncRecordData.AliESAHostPolicy", [
                        SslOption(label: "跟随请求域名", value: "follow_hostname"),
                        SslOption(label: "跟随源站域名", value: "follow_origin_domain"),
                    ])
                }
            }
        }
    }

    private func field(_ label: String, _ path: String, placeholder: String = "",
                       multiline: Bool = false, numeric: Bool = false,
                       required: Bool = false) -> some View {
        DdnsInput(label: label, text: Binding(
            get: { DdnsForm.text(DdnsForm.get(value, path)) },
            set: { DdnsForm.set(&value, path, .string($0)) }
        ), placeholder: placeholder, multiline: multiline, numeric: numeric,
        required: required, disabled: busy)
    }

    private func toggle(_ label: String, _ path: String) -> some View {
        LuckyToggleRow(label: label, isOn: Binding(
            get: { DdnsForm.bool(DdnsForm.get(value, path)) },
            set: { DdnsForm.set(&value, path, .bool($0)) }
        ))
        .disabled(busy)
    }

    private func choice(_ label: String, _ path: String, _ options: [SslOption]) -> some View {
        DdnsChoice(label: label, options: options, current: DdnsForm.text(DdnsForm.get(value, path)),
                   disabled: busy) { DdnsForm.set(&value, path, .string($0)) }
    }

    private func submit() {
        do {
            failure = ""
            save(try DdnsForm.validateRecord(value))
        } catch {
            failure = error.localizedDescription
        }
    }
}

private struct DdnsWebhookFields: View {
    @Binding var value: JSONObject
    var busy: Bool
    var test: () -> Void

    private var enabled: Bool { DdnsForm.bool(value["WebhookEnable"]) }
    private var method: String { DdnsForm.text(value["WebhookMethod"]) }
    private var proxy: String { DdnsForm.text(value["WebhookProxy"]) }

    var body: some View {
        toggle("启用 Webhook", "WebhookEnable")
        if enabled {
            field("Webhook 地址", "WebhookURL", required: true)
            choice("请求方法", "WebhookMethod", ["get", "post", "put", "patch"].map {
                SslOption(label: $0.uppercased(), value: $0)
            })
            field("请求头（每行一项）", "WebhookHeaders", multiline: true)
            if method != "get" { field("请求内容", "WebhookRequestBody", multiline: true) }
            field("重试次数（0～10）", "RetryCount", numeric: true)
            if (value["RetryCount"]?.asInt ?? 0) > 0 {
                field("重试间隔（500～10000 毫秒）", "RetryInterval", numeric: true)
            }
            toggle("跳过响应内容检查", "WebhookDisableCallbackSuccessContentCheck")
            if !DdnsForm.bool(value["WebhookDisableCallbackSuccessContentCheck"]) {
                field("成功响应关键字（每行一项）", "WebhookSuccessContent",
                      multiline: true, required: true)
            }
            choice("Webhook 代理", "WebhookProxy", [
                SslOption(label: "不使用", value: ""),
                SslOption(label: "跟随 DNS 服务商", value: "dns"),
                SslOption(label: "HTTP", value: "http"), SslOption(label: "HTTPS", value: "https"),
                SslOption(label: "SOCKS5", value: "socks5"),
            ])
            if !proxy.isEmpty, proxy != "dns" {
                field("代理地址", "WebhookProxyAddr", required: true)
                field("代理账号", "WebhookProxyUser")
                field("代理密码", "WebhookProxyPassword", secure: true)
            }
            ServiceActionButton(title: "测试 Webhook", symbol: "testtube.2",
                                fill: .tinted, height: 42, disabled: busy, action: test)
        }
    }

    private func field(_ label: String, _ path: String, multiline: Bool = false,
                       secure: Bool = false, numeric: Bool = false,
                       required: Bool = false) -> some View {
        DdnsInput(label: label, text: Binding(
            get: {
                let stored = value[path]
                return stored?.arrayValue?.map(\.asDisplayString).joined(separator: "\n")
                    ?? DdnsForm.text(stored)
            }, set: { value[path] = .string($0) }
        ), multiline: multiline, secure: secure, numeric: numeric,
        required: required, disabled: busy)
    }

    private func toggle(_ label: String, _ path: String) -> some View {
        LuckyToggleRow(label: label, isOn: Binding(
            get: { DdnsForm.bool(value[path]) }, set: { value[path] = .bool($0) }
        ))
        .disabled(busy)
        .opacity(busy ? 0.55 : 1)
    }

    private func choice(_ label: String, _ path: String, _ options: [SslOption]) -> some View {
        DdnsChoice(label: label, options: options, current: DdnsForm.text(value[path]),
                   disabled: busy) { value[path] = .string($0) }
    }
}

struct DdnsSettingsEditor: View {
    var request: ServiceEditorRequest
    var saving: Bool
    var close: () -> Void
    var save: (JSONObject) -> Void

    @State private var value: JSONObject
    @State private var failure = ""
    @State private var result = ""
    @State private var testing = false

    init(request: ServiceEditorRequest, saving: Bool,
         close: @escaping () -> Void, save: @escaping (JSONObject) -> Void) {
        self.request = request
        self.saving = saving
        self.close = close
        self.save = save
        _value = State(initialValue: DdnsForm.normalizeSettings(request.value))
    }

    private var busy: Bool { saving || testing }

    var body: some View {
        ServiceSheet(title: request.title, close: close) {
            LuckyPillButton(title: saving ? "保存中" : "保存设置",
                            symbol: "checkmark", prominent: true, loading: saving) {
                submit()
            }
            .disabled(busy)
        } content: {
            if !failure.isEmpty { LuckyErrorCard(message: failure, title: "配置错误") }
            if !result.isEmpty {
                LuckyCard(spacing: LuckyTheme.Space.s) {
                    Text("测试结果").font(LuckyTheme.Text.captionMedium).foregroundStyle(LuckyTheme.success)
                    LuckyCodeBlock(text: result, maxHeight: 220)
                }
            }
            DdnsSection(title: "模块设置", symbol: "gearshape.2") {
                LuckyToggleRow(label: "启用 DDNS 模块", isOn: Binding(
                    get: { DdnsForm.bool(value["Enable"]) }, set: { value["Enable"] = .bool($0) }
                ))
                .disabled(busy)
                DdnsInput(label: "自定义多级域名后缀（每行一项）", text: Binding(
                    get: { value["CustomDomainSuffix"]?.arrayValue?.map(\.asDisplayString).joined(separator: "\n")
                        ?? DdnsForm.text(value["CustomDomainSuffix"]) },
                    set: { value["CustomDomainSuffix"] = .string($0) }
                ), multiline: true, disabled: busy)
            }
            DdnsSection(title: "全局 Webhook", symbol: "arrow.triangle.branch") {
                DdnsWebhookFields(value: $value, busy: busy, test: testWebhook)
            }
        }
    }

    private func submit() {
        do {
            failure = ""
            save(try DdnsForm.validateSettings(value))
        } catch {
            failure = error.localizedDescription
        }
    }

    private func testWebhook() {
        guard !busy else { return }
        Task {
            testing = true
            failure = ""
            result = ""
            defer { testing = false }
            do {
                let output = try await DdnsService.testWebhook("666", .object(value))
                result = ServiceRecord.resultText(output)
                if result.isEmpty { result = "测试成功" }
            } catch {
                guard !error.isCancellation else { return }
                failure = error.luckyMessage("测试失败")
            }
        }
    }
}
