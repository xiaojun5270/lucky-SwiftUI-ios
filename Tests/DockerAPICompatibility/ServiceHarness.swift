import Foundation

typealias LuckyListItem = JSONValue
struct LuckyItemList: Sendable { var items: [JSONValue]; var raw: JSONValue }

/// Scripted transport boundary: no credentials, network, or real service mutations.
actor LuckyClient {
    static let shared = LuckyClient()
    var requests: [LuckyRequest] = []
    var replies: [Result<JSONValue, Error>] = []
    func reset(_ replies: [Result<JSONValue, Error>]) {
        self.replies = replies
        requests = []
    }
    func fetch(_ request: LuckyRequest) async throws -> JSONValue {
        requests.append(request)
        guard !replies.isEmpty else { throw LuckyError("Unexpected request: \(request.path)") }
        return try replies.removeFirst().get()
    }
    func fetch(_ path: String, method: String = "GET", body: LuckyBody? = nil) async throws -> JSONValue {
        try await fetch(LuckyRequest(path, method: method, body: body))
    }
    func checkDockerImageUpgrade(_ image: String,
        onProgress: (@Sendable (DockerImageUpgradeProgress) -> Void)? = nil) async throws -> JSONValue {
        try await fetch("/api/docker/images/upgrade-check-ws")
    }
}

@main enum ServiceCompatibilityChecks {
    static func main() async throws {
        let client = LuckyClient.shared
        let ok = JSONValue.object([("ret", .int(0))])
        func missing(_ method: String, _ path: String) -> Result<JSONValue, Error> {
            .failure(LuckyError("Request URL [\(method)][\(path)] not found", statusCode: 404))
        }
        var failures = 0
        var total = 0
        func check(_ name: String, _ condition: Bool) {
            total += 1
            if !condition { failures += 1; print("FAIL: \(name)") }
        }
        await client.reset([missing("POST", "/api/docker/containers/set-group"), .success(ok)])
        do {
            _ = try await DockerService.setContainerGroup(containerName: "App", groupKey: "g")
            let calls = await client.requests
            check("V3 group route and method", calls.count == 2 && calls[1].path == "/api/docker/containers/group" && calls[1].method == "PUT")
            check("V3 group preserves payload", calls.count == 2 && calls[0].body?.data == calls[1].body?.data)
        } catch { check("V3 group route fallback", false) }
        await client.reset([.failure(LuckyError("No such container: App", statusCode: 404))])
        do { _ = try await DockerService.setContainerGroup(containerName: "App", groupKey: "g"); check("reject domain failure", false) }
        catch { check("no mutation retry on domain error", await client.requests.count == 1) }
        await client.reset([.success(ok)])
        _ = try await DockerService.setContainerGroup(containerName: "App", groupKey: "g")
        let v2 = await client.requests
        check("V2 group route retained", v2.count == 1 && v2[0].path == "/api/docker/containers/set-group" && v2[0].method == "POST")
        let sort = JSONParser.tryParse(#"{"ret":0,"sort":{"flat_order":["App"],"custom_group_order":["g"]},"mapping":{"App":"g"}}"#)!
        await client.reset([missing("GET", "/api/docker/containers/order-mapping"), .success(sort)])
        do {
            let result = try await DockerService.containerOrderMapping()
            let calls = await client.requests
            check("V3 sort-config read route", calls.count == 2 && calls[1].path == "/api/docker/containers/sort-config")
            check("V3 sort read normalizes old mapping", result["containerGroupMap"] == sort["mapping"] && result["orderList"] == sort["sort"]?["flat_order"])
        } catch { check("V3 sort-config read fallback", false) }
        await client.reset([.success(JSONParser.tryParse(#"{"ret":0,"task":{"status":"success","result":{"upgraded":1,"failed":0}}}"#)! )])
        do {
            _ = try await DockerService.waitForTask("task1", timeout: 0.1, interval: 0.5)
            check("V3 task success is terminal", true)
        } catch { check("V3 task success is terminal", false) }
        let request = JSONParser.tryParse(#"{"image_ref":"app:latest","upgrade_compose":true,"upgrade_standalone":true,"container_ids":["c1"],"plan_revision":"r1"}"#)!
        let plan = JSONValue.object([("schema_version", .int(1)), ("plan", .object([
            ("revision", .string("r1")), ("request", request),
            ("rows", .array([.object([("action", .string("upgrade"))])]))
        ]))])
        let taskResult = JSONParser.tryParse(#"{"ret":0,"task":{"status":"success","result":{"upgraded":1,"failed":0}}}"#)!
        await client.reset([missing("POST", "/api/docker/images/upgrade-containers"), .success(plan),
            .success(.object([("task_id", .string("t1"))])), .success(taskResult)])
        do {
            let result = try await DockerService.upgradeImageContainers("app:latest", containerIds: .array([.string("c1")]))
            let calls = await client.requests
            check("V3 upgrade preview then async execution", calls.map(\.path) == ["/api/docker/images/upgrade-containers", "/api/docker/images/upgrade-plan", "/api/docker/images/upgrade-containers-async", "/api/docker/tasks/t1"])
            let execution = calls.count > 2 ? calls[2].body.flatMap { JSONParser.tryParse($0.data) } : nil
            check("V3 upgrade sends revision and request key", execution?["plan_revision"] == .string("r1") && !(execution?["request_key"]?.stringValue ?? "").isEmpty)
            check("V3 upgrade returns completed result", result == taskResult["task"]?["result"])
        } catch { check("V3 async upgrade fallback", false) }
        var unsafe = plan.record
        var unsafePlan = plan["plan"]!.record
        var unsafeRequest = request.record
        unsafeRequest["container_ids"] = .array([.string("c1"), .string("c2")])
        unsafePlan["request"] = .object(unsafeRequest)
        unsafe["plan"] = .object(unsafePlan)
        await client.reset([missing("POST", "/api/docker/images/upgrade-containers"), .success(.object(unsafe))])
        do {
            _ = try await DockerService.upgradeImageContainers("app:latest", containerIds: .array([.string("c1")]))
            check("reject broadened V3 upgrade plan", false)
        } catch { check("reject broadened V3 upgrade before execution", await client.requests.count == 2) }
        await client.reset([.success(.object([("ticket", .string("short")), ("ticketParam", .string("Lucky-Temp-Access-Ticket"))]))])
        do {
            let url = try await DockerService.imageUpgradeSocketURL(baseURL: "https://example.invalid/", token: "admin", image: "app:latest")
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            check("V3 acquires and uses short-lived ticket", query?.first(where: { $0.name == "Lucky-Temp-Access-Ticket" })?.value == "short")
            let calls = await client.requests
            let body = calls.first?.body.flatMap { JSONParser.tryParse($0.data) }
            check("ticket bound to exact method path and query", calls.first?.path == "/api/temp-access-tickets" && body?["method"] == .string("GET") && body?["path"] == .string("/api/docker/images/upgrade-check-ws") && body?["query"]?["image_ref"] == .string("app:latest"))
        } catch { check("V3 socket ticket acquisition", false) }
        await client.reset([missing("POST", "/api/temp-access-tickets")])
        do {
            let url = try await DockerService.imageUpgradeSocketURL(baseURL: "https://example.invalid", token: "admin", image: "app")
            check("V2 socket retains admin query only after missing ticket route", URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "Lucky-Admin-Token" })?.value == "admin")
        } catch { check("V2 ticket fallback", false) }
        await client.reset([.failure(LuckyAuthError())])
        do {
            _ = try await DockerService.imageUpgradeSocketURL(baseURL: "https://example.invalid", token: "admin", image: "app")
            check("ticket auth must not downgrade", false)
        } catch { check("ticket auth propagated", error is LuckyAuthError) }
        await client.reset([.success(ok)])
        _ = try await DockerService.createCompose(DockerComposeCreateInput(workingDirectory: "/data/app", composeContent: "services: {}", configFileName: "compose.yml"))
        let composeCalls = await client.requests
        let composeBody = composeCalls.first?.body.flatMap { JSONParser.tryParse($0.data) }
        check("Compose submission has V3 request key", !(composeBody?["request_key"]?.stringValue ?? "").isEmpty)
        await client.reset([.success(ok)])
        _ = try await DockerService.composeAction(.up, .object([("project_path", .string("/data/app"))]))
        let upCalls = await client.requests
        let upBody = upCalls.first?.body.flatMap { JSONParser.tryParse($0.data) }
        check("Compose up has V3 request key", !(upBody?["request_key"]?.stringValue ?? "").isEmpty)
        for operation in DockerFileOperation.allCases {
            await client.reset([.success(ok)])
            _ = try await DockerService.containerFileOperation("c 1", operation, .object([("path", .string("/a b"))]))
            let calls = await client.requests
            let expected = "/api/docker/containers/c%201/files" + (operation == .delete ? "" : "/" + operation.rawValue)
            check("file \(operation.rawValue) method and body", calls.count == 1 && calls[0].method == operation.method && calls[0].path == expected + (operation.readOnly ? "?path=%2Fa%20b" : "") && (calls[0].body != nil) == !operation.readOnly)
        }
        await client.reset([.success(ok), .success(ok), .success(ok), .success(ok), .success(ok)])
        _ = try await DdnsService.setTaskEnabled("task 1", false)
        _ = try await DdnsService.syncTask("task 1")
        _ = try await SslService.setCertificateEnabled("cert 1", false)
        _ = try await TunnelsService.setEnabled(.frp, key: "f 1", enable: false)
        _ = try await TunnelsService.setEnabled(.cloudflared, key: "c 1", enable: true)
        let sharedCalls = await client.requests
        check("DDNS SSL tunnel common V2/V3 contracts", sharedCalls.map(\.path) == ["/api/ddns/enable?enable=false&key=task%201", "/api/ddns/manualSync/task%201", "/api/ssl/cert%201?enable=false", "/api/frp/list/f%201/false", "/api/cloudflared/list/c%201/true"] && sharedCalls.map(\.method) == ["GET", "GET", "PUT", "GET", "GET"])
        // Regression: nested Records (Key), RecordHistory (Records) and V3 RouterIPStates (Name) must never hijack /api/ddnstasklist.
        let ddnsWithRecordsAndHistory = JSONParser.tryParse(#"""
        {
          "ret": 0,
          "data": [
            {
              "TaskKey": "t1",
              "TaskName": "AliDNS",
              "Enable": true,
              "DNS": {"Name": "alidns"},
              "RouterIPStates": [
                {"Name": "r1"}, {"Name": "r2"}, {"Name": "r3"}, {"Name": "r4"}, {"Name": "r5"}
              ],
              "Records": [
                {
                  "Key": "rec1", "DomainName": "example.com", "SubDomain": "www", "Type": "AAAA",
                  "RecordHistory": [
                    {"Time": "1", "Records": []}, {"Time": "2", "Records": []},
                    {"Time": "3", "Records": []}, {"Time": "4", "Records": []},
                    {"Time": "5", "Records": []}, {"Time": "6", "Records": []},
                    {"Time": "7", "Records": []}, {"Time": "8", "Records": []}
                  ]
                },
                {"Key": "rec2", "DomainName": "example.com", "SubDomain": "nas", "Type": "AAAA"},
                {"Key": "rec3", "DomainName": "example.com", "SubDomain": "app", "Type": "AAAA"},
                {"Key": "rec4", "DomainName": "example.com", "SubDomain": "git", "Type": "AAAA"}
              ]
            },
            {
              "TaskKey": "t2",
              "TaskName": "Cloudflare",
              "Enable": true,
              "DNS": {"Name": "cloudflare"},
              "Records": []
            }
          ]
        }
        """#)!
        await client.reset([.success(ddnsWithRecordsAndHistory)])
        let ddnsList = try await DdnsService.tasks()
        check("DDNS task list not hijacked by nested Records/RecordHistory/RouterIPStates",
              ddnsList.items.count == 2
              && ddnsList.items[0]["TaskKey"] == .string("t1")
              && ddnsList.items[1]["TaskKey"] == .string("t2"))
        let ddnsMapPayload = JSONParser.tryParse(#"""
        {
          "ret": 0,
          "data": {
            "t1": {
              "TaskKey": "t1", "TaskName": "MapTask", "DNS": {"Name": "alidns"},
              "Records": [
                {"Key": "r1", "RecordHistory": [{"Time": "1", "Records": []}, {"Time": "2", "Records": []}, {"Time": "3", "Records": []}, {"Time": "4", "Records": []}]},
                {"Key": "r2"}, {"Key": "r3"}, {"Key": "r4"}
              ]
            }
          }
        }
        """#)!
        await client.reset([.success(ddnsMapPayload)])
        let ddnsMapList = try await DdnsService.tasks()
        check("DDNS map task list preserved without nested hijack",
              ddnsMapList.items.count == 1 && ddnsMapList.items[0]["TaskKey"] == .string("t1"))
        await client.reset([.success(JSONParser.tryParse(#"{"ret":0,"data":[]}"#)!)])
        let ddnsEmptyList = try await DdnsService.tasks()
        check("DDNS empty data array returns empty list", ddnsEmptyList.items.isEmpty)
        await client.reset([.failure(LuckyError("NotMeetCertificateRenewalAdvanceTime\n835h37m49.961571076s > 720h0m0s"))])
        do {
            _ = try await SslService.flushCertificate("cert1")
            check("SSL flush early renewal throws localized message", false)
        } catch {
            check("SSL flush early renewal formats Go duration to Chinese",
                  error.luckyMessage() == "当前证书还未到续期时间：剩余有效期 34天19小时37分钟，需要小于续期提前时间 30天 后才能手动续期")
        }
        await client.reset([.failure(LuckyError("NotMeetCertificateRenewalAdvanceTime 12h5m30s > 24h0m0s"))])
        do {
            _ = try await SslService.flushCertificate("cert1")
            check("SSL flush sub-day renewal throws localized message", false)
        } catch {
            check("SSL flush sub-day duration formats cleanly",
                  error.luckyMessage() == "当前证书还未到续期时间：剩余有效期 12小时5分钟，需要小于续期提前时间 1天 后才能手动续期")
        }
        await client.reset([.failure(LuckyError("UnsupportedRefreshType"))])
        do {
            _ = try await SslService.flushCertificate("cert1")
            check("SSL flush unsupported type throws localized message", false)
        } catch {
            check("SSL sentinel translated to Chinese", error.luckyMessage() == "当前证书类型不支持手动刷新")
        }
        await client.reset([.failure(LuckyError("PermissionDeniedCannotUseSyncFunction"))])
        do {
            _ = try await SslService.syncCertificate("cert1")
            check("SSL sync permission denied throws localized message", false)
        } catch {
            check("SSL sync permission denied retains Chinese copy", error.luckyMessage() == "当前账号没有证书分发同步权限")
        }
        await client.reset([.failure(LuckyAuthError())])
        do {
            _ = try await SslService.flushCertificate("cert1")
            check("SSL auth error must not be swallowed", false)
        } catch {
            check("SSL auth error preserved untouched", error is LuckyAuthError)
        }
        for error in [LuckyError("permission denied", statusCode: 403), LuckyError("registry failure", statusCode: 500), LuckyError("application rejected"), LuckyError("No such image", statusCode: 404)] {
            await client.reset([.failure(error)])
            do { _ = try await DockerService.upgradeImageContainers("app", containerIds: .array([.string("c1")])); check("upgrade failure propagated", false) }
            catch { check("upgrade must not retry auth/application/HTTP failure", await client.requests.count == 1) }
        }
        await client.reset([missing("POST", "/api/docker/images/upgrade-containers"), .success(plan), .success(.object([("task_id", .string("t1"))])), .success(JSONParser.tryParse(#"{"task":{"status":"failed","error":"recreate denied"}}"#)!)])
        do { _ = try await DockerService.upgradeImageContainers("app:latest", containerIds: .array([.string("c1")])); check("async failure propagated", false) }
        catch {
            let calls = await client.requests
            check("async task failure is not success or retried", error.luckyMessage() == "recreate denied" && calls.count == 4)
        }
        print("Service compatibility: \(total - failures)/\(total) checks passed")
        exit(failures == 0 ? 0 : 1)
    }
}
