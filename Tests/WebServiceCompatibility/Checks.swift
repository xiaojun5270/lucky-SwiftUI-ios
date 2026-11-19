import Foundation

struct LuckyItemList: Sendable { var items: [JSONValue]; var raw: JSONValue }
actor LuckyClient {
    static let shared = LuckyClient()
    var requests: [LuckyRequest] = []
    var replies: [Result<JSONValue, Error>] = []
    func reset(_ replies: [Result<JSONValue, Error>]) { self.replies = replies; requests = [] }
    func fetch(_ request: LuckyRequest) async throws -> JSONValue {
        requests.append(request)
        guard !replies.isEmpty else { throw LuckyError("Unexpected request: \(request.path)") }
        return try replies.removeFirst().get()
    }
    func fetch(_ path: String, method: String = "GET", body: LuckyBody? = nil) async throws -> JSONValue {
        try await fetch(LuckyRequest(path, method: method, body: body))
    }
}

@main enum WebServiceCompatibilityChecks {
    static func main() async throws {
        let client = LuckyClient.shared
        let settings = JSONValue.object([("LogLevel", .int(4)), ("FutureV3", .object([("secret", .string("keep"))]))])
        let envelope = JSONValue.object([("ret", .int(0)), ("settings", settings)])
        func missing(_ method: String, _ path: String) -> Result<JSONValue, Error> {
            .failure(LuckyError("Request URL [\(method)][\(path)] not found", statusCode: 404))
        }
        var total = 0
        var failures = 0
        func check(_ name: String, _ passed: Bool) {
            total += 1
            if !passed { failures += 1; print("FAIL: \(name)") }
        }
        await client.reset([missing("GET", "/api/webservice/modulesettings/frontend"), .success(envelope)])
        do {
            let result = try await WebService.settings()
            let calls = await client.requests
            check("V3 settings fallback preserves unknown fields", result == settings)
            check("V3 GET documented route", calls.map(\.path) == ["/api/webservice/modulesettings/frontend", "/api/webservice/settings"] && calls.allSatisfy { $0.method == "GET" })
        } catch { check("V3 GET missing route falls back", false) }
        await client.reset([missing("PUT", "/api/webservice/modulesettings"), .success(envelope)])
        do {
            let result = try await WebService.updateSettings(settings)
            let calls = await client.requests
            check("V3 PUT documented route", calls.map(\.path) == ["/api/webservice/modulesettings", "/api/webservice/settings"] && calls.allSatisfy { $0.method == "PUT" })
            check("V3 PUT preserves complete body and response", calls.count == 2 && calls[0].body?.data == JSONSerializer.data(settings) && calls[0].body?.data == calls[1].body?.data && result == envelope)
        } catch { check("V3 PUT missing route falls back", false) }
        let storedRule = JSONValue.object([("RuleKey", .string("r")), ("FutureV3", settings), ("ProxyList", .array([settings]))])
        await client.reset([.success(.object([("ret", .int(0)), ("rule", storedRule), ("version", .string("opaque-v3-version"))]))])
        let editableRule = try await WebService.rule("r")
        check("V3 rule retains opaque concurrency version for whole-rule edits", editableRule["ExpectedVersion"] == .string("opaque-v3-version"))
        check("V3 rule retains unknown parent and child fields", editableRule["FutureV3"] == settings && editableRule["ProxyList"] == storedRule["ProxyList"])
        await client.reset([.success(envelope)])
        _ = try await WebService.updateRule(key: "r", value: editableRule)
        let editCalls = await client.requests
        check("whole rule PUT forwards ExpectedVersion and unknown fields", editCalls.count == 1 && editCalls[0].body?.data == JSONSerializer.data(editableRule))
        // Regression/guardrail coverage: these intentionally characterize retained behavior.
        await client.reset([.success(envelope)])
        check("V2 settings decode unchanged", try await WebService.settings() == settings)
        check("V2 settings GET has no fallback", await client.requests.count == 1)
        await client.reset([.success(envelope)])
        _ = try await WebService.updateSettings(settings)
        let v2Writes = await client.requests
        check("V2 settings PUT remains original route", v2Writes.count == 1 && v2Writes[0].path == "/api/webservice/modulesettings")
        let blocked: [Error] = [LuckyAuthError(), LuckyError("unauthorized", statusCode: 401), LuckyError("forbidden", statusCode: 403), LuckyError("settings not found", statusCode: 404), LuckyError("server error", statusCode: 500), URLError(.timedOut), CancellationError()]
        for (index, error) in blocked.enumerated() {
            await client.reset([.failure(error)])
            do { _ = try await WebService.settings(); check("GET propagates failure \(index)", false) }
            catch { check("GET does not retry failure \(index)", await client.requests.count == 1) }
            await client.reset([.failure(error)])
            do { _ = try await WebService.updateSettings(settings); check("PUT propagates failure \(index)", false) }
            catch { check("PUT does not retry failure \(index)", await client.requests.count == 1) }
        }
        await client.reset([missing("GET", "/api/webservice/modulesettings/frontend"), .failure(LuckyAuthError())])
        do { _ = try await WebService.settings(); check("fallback failure propagates", false) }
        catch {
            let count = await client.requests.count
            check("fallback failure is not retried", error is LuckyAuthError && count == 2)
        }
        await client.reset([.success(.object([("ret", .int(0)), ("rule", storedRule)]))])
        check("V2 rule has no fabricated version", try await WebService.rule("r") == storedRule)
        await client.reset([.success(.object([("ret", .int(0)), ("ruleList", .array([storedRule]))]))])
        let list = try await WebService.rules()
        check("rule lists preserve opaque fields without defaults", list.items == [storedRule])
        print("WebService compatibility: \(total - failures)/\(total) checks passed")
        exit(failures == 0 ? 0 : 1)
    }
}
