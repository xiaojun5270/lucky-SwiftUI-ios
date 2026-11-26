import Foundation

/// Port of `src/services/ddns.ts`.
///
/// Every path here uses the `compact` query builder — the DDNS module ignores parameters
/// that arrive empty, so the original drops `null` and `''` before building the string.
enum DdnsService {
    private static var client: LuckyClient { .shared }

    private static let webhookKeys = [
        "WebhookURL", "WebhookMethod", "WebhookHeaders", "WebhookRequestBody",
        "WebhookProxy", "WebhookProxyAddr", "WebhookProxyUser", "WebhookProxyPassword",
        "WebhookDisableCallbackSuccessContentCheck", "WebhookSuccessContent",
        "RetryCount", "RetryInterval",
    ]

    /// Strong DDNS task keys that do not collide with nested DNS records (`Key`),
    /// record sync history entries (`Records`), or V3 router IP state entries (`Name`).
    private static let strongTaskKeys = [
        "TaskKey", "taskKey", "DDNSTaskKey",
        "TaskName", "taskName", "DDNSTaskName",
        "DNS", "DNSProvider", "dnsProvider",
        "V4QueryIPEnable", "V6QueryIPEnable",
    ]

    /// Legacy fallback keys for unusual payload shapes without standard wrappers or task keys.
    private static let taskKeys = [
        "TaskKey", "taskKey", "DDNSTaskKey", "Key", "key", "TaskName", "taskName",
        "DDNSTaskName", "Name", "name", "Records", "records", "DNSProvider", "dnsProvider",
    ]

    private static let listKeys = [
        "taskList", "ddnsTaskList", "tasks", "list", "data", "result",
    ]

    /// `getDdnsTasks()` — Lucky V2 and V3 return `{ ret: 0, data: [...] }`.
    ///
    /// Prefer explicit top-level/wrapped list keys first, then strong task-only keys, so nested
    /// `Records` (`Key`), `RecordHistory` (`Records`), or V3 `RouterIPStates` (`Name`) arrays
    /// can never outscore and hijack the real DDNS task list.
    static func tasks() async throws -> LuckyItemList {
        let raw = try await client.fetch("/api/ddnstasklist")
        return LuckyItemList(
            items: extractTasks(raw),
            raw: raw
        )
    }

    static func extractTasks(_ raw: JSONValue) -> [JSONValue] {
        if case .array(let items) = raw {
            return items.filter(\.isRecord)
        }
        if case .object(let root) = raw {
            var sawExplicitEmptyList = false
            for key in listKeys {
                guard let match = root.keys.first(where: {
                    $0.caseInsensitiveCompare(key) == .orderedSame
                }), let candidate = root[match] else { continue }
                switch candidate {
                case .array(let items):
                    let records = items.filter(\.isRecord)
                    if !records.isEmpty { return records }
                    sawExplicitEmptyList = true
                case .null:
                    sawExplicitEmptyList = true
                case .object(let nested):
                    for nestedKey in listKeys {
                        guard let nestedMatch = nested.keys.first(where: {
                            $0.caseInsensitiveCompare(nestedKey) == .orderedSame
                        }), let nestedCandidate = nested[nestedMatch] else { continue }
                        if case .array(let items) = nestedCandidate {
                            let records = items.filter(\.isRecord)
                            if !records.isEmpty { return records }
                            sawExplicitEmptyList = true
                        } else if nestedCandidate.isNull {
                            sawExplicitEmptyList = true
                        }
                    }
                default:
                    continue
                }
            }
            if sawExplicitEmptyList { return [] }
        }
        let strong = JSONUnwrap.bestScoredRecords(raw, keys: strongTaskKeys, includeRecordValues: true)
        if !strong.isEmpty { return strong }
        return JSONUnwrap.bestScoredRecords(raw, keys: taskKeys, includeRecordValues: true)
    }

    static func task(_ key: String) async throws -> JSONValue {
        try await client.fetch("/api/ddns/task/\(LuckyQuery.escape(key))")
    }

    static func taskValue(_ payload: JSONValue) throws -> JSONObject {
        try extractedRecord(payload, keys: ["task"])
    }

    @discardableResult
    static func create(_ value: JSONValue) async throws -> JSONValue {
        try await client.fetch("/api/ddns", method: "POST", body: .value(value))
    }

    @discardableResult
    static func update(_ key: String, _ value: JSONValue) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns" + LuckyQuery.compact([("key", .string(key))]),
            method: "PUT",
            body: .value(value)
        )
    }

    @discardableResult
    static func delete(_ key: String) async throws -> JSONValue {
        try await client.fetch("/api/ddns" + LuckyQuery.compact([("key", .string(key))]), method: "DELETE")
    }

    // MARK: - Task state

    /// The three toggles are plain GETs with the flag in the query string, which is how the
    /// Lucky console calls them.
    @discardableResult
    static func setTaskEnabled(_ key: String, _ enable: Bool) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/enable" + LuckyQuery.compact([("enable", .bool(enable)), ("key", .string(key))])
        )
    }

    @discardableResult
    static func setTaskExpanded(_ key: String, _ expanded: Bool) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/expanded" + LuckyQuery.compact([("expanded", .bool(expanded)), ("key", .string(key))])
        )
    }

    @discardableResult
    static func setIpSectionExpanded(_ key: String, _ expanded: Bool) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/ipsectionexpanded"
                + LuckyQuery.compact([("expanded", .bool(expanded)), ("key", .string(key))])
        )
    }

    /// `syncDdnsTask(key)` — note the camel-cased path segment, which the server is strict about.
    @discardableResult
    static func syncTask(_ key: String) async throws -> JSONValue {
        try await client.fetch("/api/ddns/manualSync/\(LuckyQuery.escape(key))")
    }

    // MARK: - Module settings

    static func configure() async throws -> JSONValue {
        try await client.fetch("/api/ddns/configure")
    }

    static func configureValue(_ payload: JSONValue) throws -> JSONObject {
        try extractedRecord(payload, keys: ["ddnsconfigure", "configure"])
    }

    @discardableResult
    static func updateConfigure(_ value: JSONValue) async throws -> JSONValue {
        try await client.fetch("/api/ddns/configure", method: "PUT", body: .value(value))
    }

    static func odhcpdClients() async throws -> JSONValue {
        try await client.fetch("/api/ddns/odhcpdclients")
    }

    /// `testDdnsIpCommand(iptype, command)` — runs a shell command on the server and returns
    /// the address it printed, used by the "get IP from command" editor.
    static func testIpCommand(iptype: String, command: String) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/getipfromcmdtest"
                + LuckyQuery.compact([("iptype", .string(iptype)), ("command", .string(command))])
        )
    }

    static func testIpRule(iptype: String, netinterface: String, ipreg: String) async throws -> JSONValue {
        try await client.fetch(
            "/api/ipregtest" + LuckyQuery.compact([
                ("iptype", .string(iptype)),
                ("netinterface", .string(netinterface)),
                ("ipreg", .string(ipreg)),
            ])
        )
    }

    @discardableResult
    static func testWebhook(_ key: String, _ value: JSONValue) async throws -> JSONValue {
        let payload = value.record.filter { field, _ in webhookKeys.contains(field) }
        return try await client.fetch(
            "/api/ddns/webhooktest" + LuckyQuery.compact([("key", .string(key))]),
            method: "POST",
            body: .value(.object(payload))
        )
    }

    // MARK: - Ordering and records

    /// The reorder endpoints take a bare JSON array of keys as the body, not an envelope.
    @discardableResult
    static func reorderTasks(_ keys: JSONValue) async throws -> JSONValue {
        try await client.fetch("/api/ddns/taskorderadjustment", method: "PUT", body: .value(keys))
    }

    @discardableResult
    static func reorderRecords(taskKey: String, keys: JSONValue) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/recordOrderadjustment/\(LuckyQuery.escape(taskKey))",
            method: "PUT",
            body: .value(keys)
        )
    }

    @discardableResult
    static func deleteRecord(taskKey: String, recordKey: String) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/\(LuckyQuery.escape(taskKey))/\(LuckyQuery.escape(recordKey))",
            method: "DELETE"
        )
    }

    @discardableResult
    static func setRecordOption(taskKey: String, recordKey: String, option: String) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/\(LuckyQuery.escape(taskKey))/\(LuckyQuery.escape(recordKey))"
                + "/option/\(LuckyQuery.escape(option))",
            method: "PUT"
        )
    }

    @discardableResult
    static func setRecordEnabled(taskKey: String, recordKey: String, enabled: Bool) async throws -> JSONValue {
        try await setRecordOption(taskKey: taskKey, recordKey: recordKey,
                                  option: enabled ? "true" : "false")
    }

    // MARK: - Logs

    static func logs(pageSize: Int = 100, page: Int = 1) async throws -> JSONValue {
        try await client.fetch(
            "/api/ddns/logs" + LuckyQuery.compact([("pageSize", .int(pageSize)), ("page", .int(page))])
        )
    }

    static func lastLogs() async throws -> JSONValue {
        try await client.fetch("/api/ddns/lastlogs")
    }

    private static func extractedRecord(_ payload: JSONValue, keys: [String]) throws -> JSONObject {
        var queue = [payload]
        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            guard let object = current.objectValue else { continue }
            for wanted in keys {
                guard let match = object.keys.first(where: {
                    $0.caseInsensitiveCompare(wanted) == .orderedSame
                }), let found = object[match]?.objectValue else { continue }
                return found
            }
            queue.append(contentsOf: object.values.filter(\.isRecord))
        }
        throw DdnsPayloadError()
    }
}

private struct DdnsPayloadError: LocalizedError {
    var errorDescription: String? { "服务端未返回完整 DDNS 配置" }
}
