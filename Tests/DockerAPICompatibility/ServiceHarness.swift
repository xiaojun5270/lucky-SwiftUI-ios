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
        print("Service compatibility: \(total - failures)/\(total) checks passed")
        exit(failures == 0 ? 0 : 1)
    }
}
